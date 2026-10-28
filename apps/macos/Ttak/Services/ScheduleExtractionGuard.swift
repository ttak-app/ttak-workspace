import Foundation

struct ScheduleGuardCheck: Sendable, Codable {
    var candidateIndex: Int
    var field: String
    var status: String
    var reason: String
}

struct ScheduleGuardResult: Sendable {
    var drafts: [ScheduleDraft]
    var issues: [String]
    var checks: [ScheduleGuardCheck] = []
}

enum ScheduleExtractionGuard {
    static func isOnlyDescriptiveInput(_ source: String) -> Bool {
        let lines = source.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        return !lines.isEmpty
            && lines.allSatisfy { line in
                isDescriptiveLine(line)
            }
    }
    private struct DateEvidence {
        var text: String
        var range: NSRange
    }

    static func groundActions(_ activities: [String], source: String) throws -> [GroundedSchedule] {
        try groundActions(
            activities.map { GroundedAction(actionText: $0, titleParts: []) }, source: source)
    }

    static func groundActions(_ activities: [GroundedAction], source: String) throws
        -> [GroundedSchedule]
    {
        let groups = Dictionary(grouping: activities, by: \.actionText)
        var located: [(text: String, range: NSRange, parts: [String], location: String?)] = []
        for (activity, requested) in groups {
            var base = activity
            var positions = actionMatches(base, in: source)
            if positions.isEmpty {
                // Keep a located source base if the model added a task nominalization.
                for suffix in ["하기", "가기"] where activity.hasSuffix(suffix) {
                    base = String(activity.dropLast(suffix.count)).trimmingCharacters(
                        in: .whitespaces)
                    positions = actionMatches(base, in: source)
                    if !positions.isEmpty { break }
                }
            }
            guard !base.isEmpty, positions.count == requested.count else {
                throw AnalysisFailure.unverifiedExtraction(
                    "행동 원문의 위치가 없거나 여러 위치를 구별하지 못했어요: \(activity)")
            }
            located += zip(positions, requested).map {
                (
                    (source as NSString).substring(with: $0.0), $0.0, $0.1.titleParts,
                    $0.1.locationText
                )
            }
        }
        located.sort { $0.range.location < $1.range.location }
        for index in located.indices where index > 0 {
            guard NSMaxRange(located[index - 1].range) <= located[index].range.location else {
                throw AnalysisFailure.unverifiedExtraction("행동 근거가 서로 겹쳐요")
            }
        }
        let separators = matches(#"하고(?=\s|$)|그리고\s+|\n+"#, in: source)
        let temporalRanges =
            dateEvidence(in: source).map(\.range)
            + matches(
                ScheduleTimeParser.clockPattern, in: source)
            + matches(timeOfDayPattern, in: source)
        var starts: [Int] = []
        for index in located.indices {
            let minimum = index == 0 ? 0 : NSMaxRange(located[index - 1].range)
            let separator = separators.last {
                $0.location >= minimum && NSMaxRange($0) <= located[index].range.location
            }
            let temporal = temporalRanges.filter {
                $0.location >= minimum && NSMaxRange($0) <= located[index].range.location
            }.min(by: { $0.location < $1.location })
            starts.append(
                separator.map(NSMaxRange) ?? temporal?.location
                    ?? (index == 0 ? 0 : located[index].range.location))
        }
        return located.indices.map { index in
            let end = index + 1 < located.count ? starts[index + 1] : (source as NSString).length
            let range = NSRange(location: starts[index], length: end - starts[index])
            let quote = (source as NSString).substring(with: range).trimmingCharacters(
                in: .whitespacesAndNewlines)
            let action = located[index].text
            let clocks = matches(
                ScheduleTimeParser.clockPattern,
                in: quote
            ).map { (quote as NSString).substring(with: $0).trimmingCharacters(in: .whitespaces) }
                .filter {
                    !action.contains($0) && ScheduleTimeParser.clock(from: $0, source: quote) != nil
                }
            return GroundedSchedule(
                sourceText: quote, actionText: action, titleParts: located[index].parts,
                locationText: located[index].location, dateText: nil,
                startTimeText: clocks.count == 1 ? clocks.first : nil, notes: "", listID: nil)
        }
    }

    static func groundSources(_ quotes: [String], source: String) -> [GroundedSchedule] {
        let nsSource = source as NSString
        let located = quotes.map { quote -> (quote: String, range: NSRange?) in
            let trimmed = quote.trimmingCharacters(in: .whitespacesAndNewlines)
            let ranges = matches(NSRegularExpression.escapedPattern(for: trimmed), in: source)
            return (trimmed, !trimmed.isEmpty && ranges.count == 1 ? ranges.first : nil)
        }.filter { item in
            // Only complete metadata lines grounded in the original input are non-activity scopes.
            // A mixed scope or an invented/partial quote must still reach the evidence guard.
            guard let range = item.range else { return true }
            let originalLines = nsSource.substring(with: nsSource.lineRange(for: range))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let lines = item.quote.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            return originalLines != item.quote || lines.isEmpty || !lines.allSatisfy(isMetadata)
        }
        let metadata = matches(#"(?m)^[^\n]+$"#, in: source).compactMap {
            range -> (text: String, range: NSRange)? in
            let text = (source as NSString).substring(with: range).trimmingCharacters(
                in: .whitespacesAndNewlines)
            return isMetadata(text) ? (text, range) : nil
        }
        return located.map { item in
            let quote = item.quote
            var body = quote
            // Only leading, recognized temporal evidence is removed. The remaining people and activity stay verbatim.
            while !body.isEmpty {
                body = body.trimmingCharacters(in: .whitespacesAndNewlines)
                if body.hasPrefix("그리고 ") {
                    body = String(body.dropFirst(4))
                    continue
                }
                let temporal =
                    (dateEvidence(in: body).map(\.range)
                    + matches(ScheduleTimeParser.clockPattern, in: body)
                    + matches(timeOfDayPattern, in: body)).filter { $0.location == 0 }.max {
                        $0.length < $1.length
                    }
                guard let temporal, let range = Range(temporal, in: body) else { break }
                body = String(body[range.upperBound...])
                if let particle = matches(#"^(?:에는|에)(?=\s|$)"#, in: body).first,
                    let particleRange = Range(particle, in: body)
                {
                    body = String(body[particleRange.upperBound...])
                }
            }
            if let firstMetadata = metadata.first(where: { quote.contains($0.text) }),
                let start = body.range(of: firstMetadata.text)
            {
                body = String(body[..<start.lowerBound]).trimmingCharacters(
                    in: .whitespacesAndNewlines)
            }
            if body.hasSuffix("하고"), let range = item.range,
                let next = located.compactMap(\.range).filter({ $0.location >= NSMaxRange(range) })
                    .min(by: { $0.location < $1.location })
            {
                let gap = (source as NSString).substring(
                    with: NSRange(
                        location: NSMaxRange(range), length: next.location - NSMaxRange(range)))
                if gap.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    body = String(body.dropLast(2)).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            let clocks = matches(ScheduleTimeParser.clockPattern, in: quote).map {
                (quote as NSString).substring(with: $0).trimmingCharacters(in: .whitespaces)
            }.filter { ScheduleTimeParser.clock(from: $0, source: quote) != nil }
            let notes = metadata.filter { line in
                guard let range = item.range else { return false }
                let preceding = located.compactMap(\.range).filter {
                    NSMaxRange($0) <= line.range.location
                }
                .max { $0.location < $1.location }
                return contains(range, line.range) || preceding == range
            }.map(\.text).joined(separator: "\n")
            return GroundedSchedule(
                sourceText: quote, actionText: body, titleParts: [], locationText: nil,
                dateText: nil, startTimeText: clocks.count == 1 ? clocks.first : nil, notes: notes,
                listID: nil)
        }
    }

    static func validate(
        _ candidates: [GroundedSchedule], source: String, context: AnalysisContext
    ) -> ScheduleGuardResult {
        var issues: [String] = []
        var checks: [ScheduleGuardCheck] = []
        func record(_ index: Int, _ field: String, _ status: String, _ reason: String = "") {
            checks.removeAll { $0.candidateIndex == index && $0.field == field }
            checks.append(
                ScheduleGuardCheck(
                    candidateIndex: index, field: field, status: status, reason: reason))
        }
        var drafts: [ScheduleDraft] = []
        var actions: [NSRange] = []
        var scopes:
            [(index: Int, quote: NSRange, action: NSRange, notes: [String], label: String)] = []
        var identities: Set<String> = []
        let dates = dateEvidence(in: source)
        let nsSource = source as NSString
        for (index, item) in candidates.enumerated() {
            let label = "후보 \(index + 1)"
            let quote = item.sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
            let requestedAction = item.actionText.trimmingCharacters(in: .whitespacesAndNewlines)
            let quoteRanges = matches(NSRegularExpression.escapedPattern(for: quote), in: source)
            guard !quote.isEmpty, quoteRanges.count == 1, let quoteRange = quoteRanges.first else {
                record(index, "sourceText", "rejected", "원문 내 유일한 연속 구간이 아님")
                issues.append("\(label): sourceText를 원문의 한 행동 구간으로 정확히 복사하고 중복 위치를 구별하세요")
                continue
            }
            record(index, "sourceText", "accepted")
            let actionRanges = actionMatches(requestedAction, in: quote)
            guard !requestedAction.isEmpty, actionRanges.count == 1,
                let relativeAction = actionRanges.first
            else {
                record(index, "actionText", "rejected", "일정 구간 내 유일한 행동 원문이 아님")
                issues.append("\(label): actionText는 sourceText 안에 있는 행동 제목이어야 합니다")
                continue
            }
            record(index, "actionText", "accepted")
            let action = (quote as NSString).substring(with: relativeAction)
            let location = cleanOptional(item.locationText)
            if let location, ScheduleTitleNormalizer.locationRanges(location, in: quote).count != 1
            {
                record(index, "locationText", "rejected", "유일한 실제 장소 원문 근거 없음")
                issues.append("\(label): 장소를 해당 일정 원문의 구별 가능한 실제 이름으로 복사하세요")
                continue
            }
            record(index, "locationText", location == nil ? "absent" : "accepted")
            let title: String
            do {
                if let keywords = item.titleKeywords {
                    title = try ScheduleTitleNormalizer.keywordTitle(keywords, source: quote)
                } else {
                    title = try ScheduleTitleNormalizer.normalize(
                        action: action, parts: item.titleParts, location: location)
                }
            } catch {
                record(index, "titleParts", "rejected", error.localizedDescription)
                issues.append(
                    "\(label): 제목 조각이 원문 순서와 의미 단어를 보존하지 않았습니다: \(error.localizedDescription)")
                continue
            }
            record(index, "titleParts", "accepted")
            let actionRange = NSRange(
                location: quoteRange.location + relativeAction.location,
                length: relativeAction.length)
            actions.append(actionRange)
            if !matches(#"하고(?=\s|$)|그리고\s+|\n+"#, in: action).isEmpty {
                record(index, "actionText", "rejected", "독립 행동의 연결 또는 줄바꿈 포함")
                issues.append("\(label): actionText에 여러 행동이나 줄이 합쳐졌습니다. 행동 제목을 구분하세요")
            }
            let line = nsSource.substring(with: nsSource.lineRange(for: actionRange))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if isDescriptiveLine(line) {
                record(index, "actionText", "rejected", "일정 행동이 아닌 메타정보")
                issues.append("\(label): 장소와 준비물 또는 메시지 시각을 일정 행동으로 만들지 마세요")
            }
            let localDates = dates.filter { contains(quoteRange, $0.range) }
            var evidence = localDates.count == 1 ? localDates.first : nil
            if localDates.isEmpty {
                // Share a preceding date only inside the same line/sentence.
                evidence = dates.last(where: { date in
                    guard NSMaxRange(date.range) <= quoteRange.location else { return false }
                    let gap = nsSource.substring(
                        with: NSRange(
                            location: NSMaxRange(date.range),
                            length: quoteRange.location - NSMaxRange(date.range)))
                    return !gap.contains("\n") && !gap.contains(".") && !gap.contains("。")
                })
            }
            var dateExpression = evidence?.text
            if let requestedDate = cleanOptional(item.dateText) {
                let clocks = matches(ScheduleTimeParser.clockPattern, in: requestedDate)
                if dateEvidence(in: requestedDate).isEmpty, clocks.count == 1,
                    let clock = clocks.first, clock.location == 0,
                    NSMaxRange(clock) == (requestedDate as NSString).length
                {
                    record(index, "dateText", "rejected", "숫자 시각을 날짜로 사용")
                    issues.append("\(label): 숫자 시각을 dateText에 넣지 말고 날짜가 없으면 nil로 두세요")
                    continue
                }
                if let evidence, source.contains(requestedDate),
                    dateEvidence(in: requestedDate).map(\.text) == [evidence.text]
                {
                    dateExpression = evidence.text
                } else if evidence == nil && quote.contains(requestedDate)
                    && (dateEvidence(in: requestedDate).isEmpty || localDates.count > 1)
                {
                    // A grounded but unsupported date is preserved for manual confirmation.
                    dateExpression = requestedDate
                } else {
                    record(index, "dateText", "rejected", "해당 일정 날짜의 근거와 불일치")
                    issues.append("\(label): dateText를 해당 행동에 적용되는 실제 날짜 표현과 일치시키세요")
                    continue
                }
            }
            record(index, "dateText", dateExpression == nil ? "absent" : "accepted")
            if let evidence,
                dateEvidence(in: action).contains(where: {
                    $0.range.location == 0 && $0.text == evidence.text
                })
            {
                record(index, "actionText", "rejected", "행동 앞 날짜를 제목에 포함")
                issues.append("\(label): actionText에서 날짜 표현을 분리하고 행동을 유지하세요")
            }
            if let leadingClock = matches(ScheduleTimeParser.clockPattern, in: action).first,
                leadingClock.location == 0,
                ScheduleTimeParser.clock(
                    from: (action as NSString).substring(with: leadingClock), source: quote) != nil
            {
                record(index, "actionText", "rejected", "행동 앞 숫자 시작 시각을 제목에 포함")
                issues.append("\(label): actionText에서 앞의 숫자 시작 시각을 분리하고 행동을 유지하세요")
            }
            let sourceClocks = matches(ScheduleTimeParser.clockPattern, in: quote).map {
                (quote as NSString).substring(with: $0).trimmingCharacters(in: .whitespaces)
            }.filter { ScheduleTimeParser.clock(from: $0, source: quote) != nil }
            if sourceClocks.count > 1 {
                record(index, "startTimeText", "rejected", "일정 구간에 유효한 시작 시각 후보가 여러 개")
                issues.append("\(label): 시작 시각 후보가 여러 개여서 해당 일정의 시각을 확정하지 못했어요")
            }
            var rawTime = cleanOptional(item.startTimeText)
            var timeIsGrounded = true
            if let time = rawTime {
                if dates.contains(where: { $0.text == time }) {
                    rawTime = nil
                } else if !quote.contains(time) {
                    timeIsGrounded = false
                    issues.append("\(label): 다른 행동의 시각을 가져오지 말고 sourceText 안의 시작 시각만 사용하세요")
                }
            }
            record(
                index, "startTimeText",
                timeIsGrounded && sourceClocks.count <= 1
                    ? (rawTime == nil ? "absent" : "accepted") : "rejected",
                !timeIsGrounded
                    ? "해당 일정 구간에 시각 근거 없음" : (sourceClocks.count > 1 ? "일정 구간에 시작 시각 후보가 여러 개" : "")
            )
            let notes = item.notes.trimmingCharacters(in: .whitespacesAndNewlines)
            let noteLines = notes.components(separatedBy: .newlines).filter { !$0.isEmpty }
            scopes.append((index, quoteRange, actionRange, noteLines, label))
            record(
                index, "notes",
                noteLines.contains(where: { !source.contains($0) }) ? "rejected" : "accepted")
            if noteLines.contains(where: { !source.contains($0) }) {
                issues.append("\(label): notes를 입력에 실제로 있는 부가 정보로 복사하세요")
            }
            var preservedNotes = notes
            if let location, !noteLines.contains("장소: \(location)") {
                preservedNotes += "\n장소: \(location)"
            }
            var fields = normalizedFields(
                action: title, date: dateExpression, context: context,
                time: rawTime, listID: item.listID, notes: preservedNotes)
            if localDates.count > 1 {
                fields.dateKind = .uncertain
                fields.notes += "\n날짜 표현이 여러 개여서 확인이 필요해요."
            }
            // Keep a small, verified per-action quote, including vague/end-only time information.
            if !fields.notes.contains(quote) { fields.notes += "\n원문: \(quote)" }
            let identity = "\(actionRange.location):\(actionRange.length)"
            if !identities.insert(identity).inserted {
                record(index, "actionText", "rejected", "같은 행동의 중복 추출")
                issues.append("\(label): 같은 원문 행동을 중복 추출했습니다. 별개 행동의 근거를 구별하세요")
            }
            drafts.append(ScheduleAnalyzer.makeDraft(fields, context: context, source: quote))
        }
        for scope in scopes {
            let containedActions = Set(actions.filter { contains(scope.quote, $0) }.map(\.location))
            if containedActions.count > 1 {
                record(scope.index, "sourceText", "rejected", "다른 후보 행동과 겹친 일정 구간")
                issues.append("\(scope.label): sourceText에 여러 행동이 겹칩니다. 해당 행동 구간만 복사하세요")
            }
            if let nextAction = actions.filter({ $0.location >= NSMaxRange(scope.action) })
                .min(by: { $0.location < $1.location })
            {
                for period in matches(timeOfDayPattern, in: source)
                where contains(scope.quote, period) && period.location >= NSMaxRange(scope.action)
                    && NSMaxRange(period) <= nextAction.location
                {
                    let gap = nsSource.substring(
                        with: NSRange(
                            location: NSMaxRange(period),
                            length: nextAction.location - NSMaxRange(period)))
                    if gap.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        record(scope.index, "sourceText", "rejected", "다음 행동의 시간대가 현재 구간에 포함")
                        issues.append("\(scope.label): 다음 행동 바로 앞의 시간대를 이전 행동 구간에 붙이지 마세요")
                    }
                }
            }
            for note in scope.notes {
                let locations = matches(NSRegularExpression.escapedPattern(for: note), in: source)
                let belongs = locations.contains { range in
                    if contains(scope.quote, range) { return true }
                    let precedingAction = actions.filter { NSMaxRange($0) <= range.location }
                        .max(by: { $0.location < $1.location })
                    return isMetadata(note) && precedingAction?.location == scope.action.location
                }
                if !belongs {
                    record(scope.index, "notes", "rejected", "다른 행동의 부가정보이거나 귀속 불명")
                    issues.append("\(scope.label): notes가 다른 행동에 속하거나 관련 위치를 확인하지 못했습니다")
                }
            }
        }
        let explicitMetadata = matches(#"(?m)^[^\n]+$"#, in: source).compactMap {
            range -> (text: String, range: NSRange)? in
            let text = nsSource.substring(with: range).trimmingCharacters(
                in: .whitespacesAndNewlines)
            let labels = ["장소:", "장소 :", "준비물:", "준비물 :", "메모:", "참고:"]
            return labels.contains(where: text.hasPrefix) ? (text, range) : nil
        }
        for metadata in explicitMetadata {
            let preserved = scopes.contains {
                contains($0.quote, metadata.range) || $0.notes.contains(metadata.text)
            }
            if !preserved {
                issues.append("부가 정보의 귀속을 확인하지 못했어요: \(metadata.text). 관련 일정 원문이나 메모에 보존해야 합니다")
            }
        }
        if !candidates.isEmpty {
            var coveredRanges = candidates.flatMap { item -> [NSRange] in
                let quote = item.sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !quote.isEmpty else { return [] }
                let ranges = matches(NSRegularExpression.escapedPattern(for: quote), in: source)
                return ranges.count == 1 ? ranges : []
            }
            coveredRanges += matches(#"(?m)^[^\n]+$"#, in: source).filter {
                isMetadata(
                    nsSource.substring(with: $0).trimmingCharacters(in: .whitespacesAndNewlines))
            }
            coveredRanges += matches(#"하고(?=\s|$)|그리고\s+"#, in: source)
            let uncovered = (0..<nsSource.length).filter { position in
                !coveredRanges.contains { NSLocationInRange(position, $0) }
            }
            // Check gaps as contiguous source ranges. Do not reconstruct a missing person's name or qualifier.
            var gaps: [NSRange] = []
            for position in uncovered {
                if let last = gaps.last, NSMaxRange(last) == position {
                    gaps[gaps.count - 1].length += 1
                } else {
                    gaps.append(NSRange(location: position, length: 1))
                }
            }
            for gap in gaps {
                let text = nsSource.substring(with: gap).trimmingCharacters(
                    in: .whitespacesAndNewlines.union(.punctuationCharacters))
                if !text.isEmpty {
                    issues.append("원문에서 빠진 정보: \(text). 인물, 수식어와 시간 정보를 포함한 일정 원문 전체를 복사하세요")
                }
            }
        }
        if !candidates.isEmpty {
            // This is a suspicion check, not a rule that every connector creates an event.
            let separators = matches(#"하고(?=\s|$)|그리고\s+|\n+"#, in: source)
            var start = 0
            for separator in separators + [NSRange(location: nsSource.length, length: 0)] {
                let segment = NSRange(location: start, length: separator.location - start)
                start = NSMaxRange(separator)
                let text = nsSource.substring(with: segment).trimmingCharacters(
                    in: .whitespacesAndNewlines)
                guard !text.isEmpty, !isMetadata(text) else { continue }
                let covered = actions.contains { NSIntersectionRange($0, segment).length > 0 }
                if !covered && hasRemainingContent(text) {
                    issues.append("누락 의심 구간: \(text). 독립 행동이면 별도 후보로 포함하고 부가 정보이면 관련 원문에 연결하세요")
                }
            }
        }
        for index in candidates.indices {
            for field in [
                "sourceText", "actionText", "locationText", "titleParts", "dateText",
                "startTimeText", "notes",
            ]
            where !checks.contains(where: { $0.candidateIndex == index && $0.field == field }) {
                record(index, field, "not-evaluated", "앞선 필수 필드 검증에서 중단")
            }
        }
        return ScheduleGuardResult(
            drafts: drafts, issues: Array(Set(issues)).sorted(), checks: checks)
    }

    private static let timeOfDayPattern = #"(?<![가-힣])(?:오전|오후|아침|저녁|밤)(?:에는|에)?(?=\s|$)"#

    private static func normalizedFields(
        action: String, date: String?, context: AnalysisContext,
        time: String?, listID: String?, notes: String
    ) -> ExtractedSchedule {
        var fields = ExtractedSchedule(
            title: action, dateKind: .omitted, dayOffset: nil, year: nil, month: nil, day: nil,
            startTimeText: time, listID: listID, notes: notes)
        guard let date else { return fields }
        let offsets = ["오늘": 0, "내일": 1, "모레": 2, "글피": 3]
        if let offset = offsets[date] {
            fields.dateKind = .relative
            fields.dayOffset = offset
        } else {
            guard
                !matches(
                    #"^(?:[0-9]{4,}년\s*)?[0-9]{1,2}월\s*[0-9]{1,2}일$|^[0-9]{4,}-[0-9]{2}-[0-9]{2}$"#,
                    in: date
                ).isEmpty
            else {
                fields.dateKind = .uncertain
                fields.notes += "\n날짜 확인 필요: \(date)"
                return fields
            }
            let numericTexts = matches(#"[0-9]+"#, in: date).map {
                (date as NSString).substring(with: $0)
            }
            let numbers = numericTexts.compactMap(Int.init)
            guard numbers.count == numericTexts.count else {
                fields.dateKind = .uncertain
                fields.notes += "\n날짜 확인 필요: \(date)"
                return fields
            }
            if numbers.count == 3 {
                fields.dateKind = .explicit
                fields.year = numbers[0]
                fields.month = numbers[1]
                fields.day = numbers[2]
            } else if numbers.count == 2 {
                fields.dateKind = .explicit
                fields.year = context.calendar.component(.year, from: context.referenceDate)
                fields.month = numbers[0]
                fields.day = numbers[1]
            } else {
                fields.dateKind = .uncertain
                fields.notes += "\n날짜 확인 필요: \(date)"
            }
        }
        return fields
    }

    private static func dateEvidence(in source: String) -> [DateEvidence] {
        let pattern =
            #"(?:[0-9]{4,}년\s*)?[0-9]{1,2}월\s*[0-9]{1,2}일|[0-9]{4,}-[0-9]{2}-[0-9]{2}|(이번|다음|지난)\s*(주|달)(?:\s*[월화수목금토일]요일)?|[0-9]+\s*(일|주|달)\s*(뒤|후|전)|[월화수목금토일]요일|(?<![가-힣])(오늘|내일|모레|글피)(?=[\s,.!?;:]|$|오전|오후|아침|저녁|밤|[0-9]|(?:은|는|에는|에|부터|까지|도)(?:[\s,.!?;:]|$|오전|오후|아침|저녁|밤|[0-9]))"#
        return matches(pattern, in: source).compactMap { range in
            let preceding =
                (source as NSString).substring(to: range.location)
                .components(separatedBy: .newlines).last ?? ""
            guard
                matches(
                    "^" + timestampLabel + #"\s*:?\s*$"#,
                    in: preceding.trimmingCharacters(in: .whitespaces)
                ).isEmpty
            else {
                return nil
            }
            return DateEvidence(text: (source as NSString).substring(with: range), range: range)
        }
    }

    private static func cleanOptional(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return ["", "nil", "null", "none"].contains(trimmed.lowercased()) ? nil : trimmed
    }

    private static func actionMatches(_ action: String, in source: String) -> [NSRange] {
        let characters = action.filter { !$0.isWhitespace }.map {
            NSRegularExpression.escapedPattern(for: String($0))
        }
        guard !characters.isEmpty else { return [] }
        let pattern = characters.joined(separator: #"[ \t]*"#)
        return matches(pattern, in: source).filter {
            let line = (source as NSString).substring(with: (source as NSString).lineRange(for: $0))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return !isDescriptiveLine(line)
        }
    }

    private static func matches(_ pattern: String, in text: String) -> [NSRange] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).map(\.range)
    }

    private static func contains(_ outer: NSRange, _ inner: NSRange) -> Bool {
        inner.location >= outer.location && NSMaxRange(inner) <= NSMaxRange(outer)
    }

    private static let timestampLabel =
        #"(?:메시지\s*(?:발송|작성)\s*(?:시각|시간|날짜|일시)|발송\s*(?:시각|날짜)|작성\s*(?:시각|일)|촬영\s*(?:일|날짜))"#

    private static func isDescriptiveLine(_ text: String) -> Bool {
        ["장소:", "장소 :", "준비물:", "준비물 :"].contains(where: text.hasPrefix)
            || !matches("^" + timestampLabel + #"(?:\s*:|\s+(?=[0-9]))"#, in: text).isEmpty
    }

    private static func isMetadata(_ text: String) -> Bool {
        isDescriptiveLine(text)
            || ["메모:", "참고:", "합성 대화", "합성 행사"].contains(where: text.hasPrefix)
    }

    private static func hasRemainingContent(_ text: String) -> Bool {
        let withoutDates = dateEvidence(in: text).reduce(text) {
            $0.replacingOccurrences(of: $1.text, with: "")
        }
        let regex = try? NSRegularExpression(pattern: #"(오전|오후)?\s*[0-9]{1,2}(시|:[0-9]{2})"#)
        let remainder =
            regex?.stringByReplacingMatches(
                in: withoutDates, range: NSRange(withoutDates.startIndex..., in: withoutDates),
                withTemplate: "") ?? withoutDates
        return !remainder.trimmingCharacters(
            in: .whitespacesAndNewlines.union(.punctuationCharacters)
        ).isEmpty
    }
}
