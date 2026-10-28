import Foundation

enum ScheduleTitleNormalizer {
    // Compact only recognized activity forms. Unclear grammar and critical meanings keep the source title.
    static func compactKeywords(action: String) -> [String]? {
        guard
            matches(#"없이|취소|거절|금지|제외|말고|아닌|않|(?<![가-힣])(?:안|못)(?=\s|$)|확인|여부"#, in: action).isEmpty
        else {
            return nil
        }
        let body: String
        do { body = try normalize(action: action, parts: []) } catch { return nil }
        let hasZoom = !matches(#"(?i)(?<![가-힣A-Za-z])(?:줌|zoom)(?:으로|로|에서)?(?=\s|$)"#, in: body)
            .isEmpty
        let activity: String
        if hasZoom, !matches(#"검토[.!?]?\s*$"#, in: body).isEmpty {
            activity = "미팅"
        } else if !matches(#"자료\s*조사(?:하기)?[.!?]?\s*$"#, in: body).isEmpty {
            activity = "자료조사"
        } else if !matches(#"자료\s*정리(?:하기)?[.!?]?\s*$"#, in: body).isEmpty {
            activity = "자료정리"
        } else if !matches(#"아침\s*식사[.!?]?\s*$"#, in: body).isEmpty {
            activity = "아침식사"
        } else if !matches(#"저녁\s*식사[.!?]?\s*$"#, in: body).isEmpty {
            activity = "저녁식사"
        } else if !matches(#"(?<![가-힣])점심(?:\s*(?:약속|식사))?[.!?]?\s*$"#, in: body).isEmpty {
            activity = "점심"
        } else if !matches(#"회식[.!?]?\s*$"#, in: body).isEmpty {
            activity = "회식"
        } else if !matches(#"미팅[.!?]?\s*$"#, in: body).isEmpty {
            activity = "미팅"
        } else if !matches(#"회의(?:가|를|는)?[.!?]?\s*$"#, in: body).isEmpty {
            activity = "회의"
        } else {
            return nil
        }

        let nsBody = body as NSString
        var people: [String] = []
        for range in matches(#"(?<!\S)[^\s]+?(?:이랑|랑|와|과)(?=\s|$)"#, in: body) {
            let word = nsBody.substring(with: range)
            if let suffix = ["이랑", "랑", "와", "과"].first(where: word.hasSuffix) {
                let stem = String(word.dropLast(suffix.count))
                guard !stem.isEmpty else { return nil }
                people.append(stem)
            }
        }
        var places: [String] = []
        for range in matches(#"(?<!\S)[^\s]+?에서(?=\s|$)"#, in: body) {
            let stem = String(nsBody.substring(with: range).dropLast(2))
            // A fragment like "앞" is not enough evidence for a multiword place such as "역 앞".
            guard !stem.isEmpty, !["앞", "뒤", "옆", "근처", "안", "밖"].contains(stem) else { return nil }
            places.append(stem)
        }
        let groups = body.split(whereSeparator: \.isWhitespace).map(String.init).filter { word in
            ["가족", "친구"].contains(word)
                || ["모임", "동아리", "동호회", "팀"].contains(where: word.hasSuffix)
        }
        var modes: [String] = []
        for mode in ["온라인", "오프라인"] {
            if !matches(mode + #"(?:으로|로|에서)?(?=\s|$)"#, in: body).isEmpty { modes.append(mode) }
        }
        var tools: [String] = []
        if hasZoom {
            tools =
                body.contains("줌")
                ? ["줌"]
                : matches(#"(?i)zoom"#, in: body).prefix(1).map { nsBody.substring(with: $0) }
        }
        let context = people + groups + places + modes + tools
        guard activity != "회의" || !context.isEmpty else { return nil }
        var keywords: [String] = []
        for word in context + [activity] where !keywords.contains(word) { keywords.append(word) }
        do { _ = try keywordTitle(keywords, source: action) } catch { return nil }
        return keywords
    }

    static func keywordTitle(_ keywords: [String], source: String) throws -> String {
        let tokens = keywords.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard !tokens.isEmpty, tokens.allSatisfy({ !$0.isEmpty && !$0.contains("\n") }) else {
            throw AnalysisFailure.unverifiedExtraction("제목 키워드가 비어 있거나 여러 줄이에요")
        }
        let compactSource = source.filter { !$0.isWhitespace }
        for token in tokens {
            let compact = token.filter { !$0.isWhitespace }
            let hasMeetingContext =
                !matches(#"회의(?:가|를|는|에)?(?=$|[\s\p{P}])"#, in: source).isEmpty
                || source.contains("미팅")
                || ((source.contains("줌") || source.lowercased().contains("zoom"))
                    && source.contains("검토"))
            let meetingAlias = token == "미팅" && hasMeetingContext
            guard compactSource.contains(compact) || meetingAlias else {
                throw AnalysisFailure.unverifiedExtraction("제목 키워드가 해당 일정 원문에 없어요: \(token)")
            }
            let clocks = matches(ScheduleTimeParser.clockPattern, in: token)
            guard
                !clocks.contains(where: {
                    $0.location == 0 && $0.length == (token as NSString).length
                }),
                !["오늘", "내일", "모레", "글피"].contains(token)
            else {
                throw AnalysisFailure.unverifiedExtraction("날짜와 시각은 제목 키워드에서 분리하세요")
            }
        }
        let title = tokens.joined(separator: " ")
        let compactTitle = title.filter { !$0.isWhitespace }
        let critical = matches(#"없이|취소|거절|금지|제외|(?<![가-힣])(?:안|못)(?=\s|$)|확인|여부"#, in: source)
            .map { (source as NSString).substring(with: $0) }
        guard critical.allSatisfy({ compactTitle.contains($0) }) else {
            throw AnalysisFailure.unverifiedExtraction("제목에서 부정, 취소 또는 확인 의미가 빠졌어요")
        }
        return title
    }

    private static let particles: Set<String> = [
        "이랑", "랑", "와", "과", "에", "에서", "으로", "로", "을", "를", "은", "는", "이", "가",
    ]

    static func normalize(action: String, parts: [String], location: String? = nil) throws -> String
    {
        let source = action as NSString
        let omitted = omissionRanges(action: action, location: location)
        let fragments = parts.isEmpty ? [action] : parts
        var cursor = 0
        var retained: [NSRange] = []
        for part in fragments {
            let fragment = part.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !fragment.isEmpty, fragment.rangeOfCharacter(from: .newlines) == nil,
                let range = matches(NSRegularExpression.escapedPattern(for: fragment), in: action)
                    .first(where: { $0.location >= cursor })
            else { throw AnalysisFailure.unverifiedExtraction("제목 조각의 원문 위치를 확인하지 못했어요") }
            let gap = NSRange(location: cursor, length: range.location - cursor)
            let remaining = text(in: gap, source: source, omitting: omitted)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let originalGap = source.substring(with: gap)
            guard
                remaining.isEmpty
                    || (cursor > 0 && particles.contains(remaining)
                        && originalGap.last?.isWhitespace == true)
            else { throw AnalysisFailure.unverifiedExtraction("제목에서 의미 정보가 빠졌어요") }
            retained += subtract(omitted, from: range)
            cursor = NSMaxRange(range)
        }
        let tail = text(
            in: NSRange(location: cursor, length: source.length - cursor),
            source: source, omitting: omitted
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        guard tail.isEmpty || (cursor > 0 && particles.contains(tail)) else {
            throw AnalysisFailure.unverifiedExtraction("제목 끝의 의미 정보가 빠졌어요")
        }

        var title = ""
        var previousEnd: Int?
        for range in retained {
            let raw = source.substring(with: range)
            let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { continue }
            let local = (raw as NSString).range(of: value)
            let start = range.location + local.location
            // Adjacent source pieces stay adjacent; a model split must not invent a space.
            if let previousEnd, start > previousEnd { title += " " }
            title += value
            previousEnd = start + (value as NSString).length
        }
        guard !title.isEmpty, !["있어", "있어요", "있습니다", "있다", "있음", "있고"].contains(title) else {
            throw AnalysisFailure.unverifiedExtraction("제목에 남은 행동이 없어요")
        }
        return title
    }

    static func locationRanges(_ location: String, in source: String, includeParticle: Bool = false)
        -> [NSRange]
    {
        guard
            !["온라인", "오프라인", "줌", "zoom", "google meet", "teams", "discord"].contains(
                location.lowercased())
        else { return [] }
        let name = NSRegularExpression.escapedPattern(for: location)
        let particle = #"(?:에서|으로|에는|로|에)"#
        let boundary = #"(?=$|[\s\p{P}])"#
        let suffix =
            includeParticle
            ? particle + "?" + boundary : "(?=" + particle + boundary + "|$|[\\s\\p{P}])"
        return matches(#"(?<![\p{L}\p{N}])"# + name + suffix, in: source)
    }

    private static func omissionRanges(action: String, location: String?) -> [NSRange] {
        var omitted: [NSRange] = []
        if let location {
            let ranges = locationRanges(location, in: action, includeParticle: true)
            if ranges.count == 1 { omitted += ranges }
        }
        let source = action as NSString
        var masked = action
        for range in omitted.reversed() {
            masked = (masked as NSString).replacingCharacters(
                in: range, with: String(repeating: " ", count: range.length))
        }
        let endings = #"(?:갈\s*거야|갈\s*거예요|갈게요|갈게|있습니다|있어요|있어|있고|있다|있음)[.!?]?\s*$"#
        if let ending = matches(endings, in: masked).last {
            let body = (masked as NSString).substring(to: ending.location)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let lastWord = body.split(whereSeparator: \.isWhitespace).last.map(String.init) ?? ""
            // Preserve the predicate when it can carry negation or a destination relation.
            let protected =
                ["안", "못", "않고", "않아", "없어"].contains(lastWord)
                || !matches(#"(?:에서|으로|로|에|안|못|[아어러려져해워와고])$"#, in: body).isEmpty
            if !body.isEmpty && !protected && NSMaxRange(ending) <= source.length {
                omitted.append(ending)
            }
        }
        return omitted.sorted { $0.location < $1.location }
    }

    private static func text(in range: NSRange, source: NSString, omitting: [NSRange]) -> String {
        subtract(omitting, from: range).map { source.substring(with: $0) }.joined()
    }

    private static func subtract(_ removals: [NSRange], from range: NSRange) -> [NSRange] {
        var cursor = range.location
        var result: [NSRange] = []
        for removal in removals {
            let overlap = NSIntersectionRange(range, removal)
            guard overlap.length > 0 else { continue }
            if overlap.location > cursor {
                result.append(NSRange(location: cursor, length: overlap.location - cursor))
            }
            cursor = max(cursor, NSMaxRange(overlap))
        }
        if cursor < NSMaxRange(range) {
            result.append(NSRange(location: cursor, length: NSMaxRange(range) - cursor))
        }
        return result
    }

    private static func matches(_ pattern: String, in text: String) -> [NSRange] {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return [] }
        return expression.matches(in: text, range: NSRange(text.startIndex..., in: text)).map(
            \.range)
    }
}
