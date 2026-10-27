import Foundation

enum ScheduleTitleNormalizer {
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
