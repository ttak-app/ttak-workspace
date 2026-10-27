import Foundation

struct ReminderList: Identifiable, Sendable, Equatable {
    let id: String
    let title: String
}

struct ScheduleDraft: Identifiable, Sendable, Equatable {
    let id: UUID
    var title: String
    var dateText: String
    var timeText: String
    var listID: String?
    var notes: String
    var dateNeedsConfirmation: Bool
    var isExcluded = false

    init(
        id: UUID = UUID(), title: String, dateText: String, timeText: String = "",
        listID: String? = nil, notes: String = "", dateNeedsConfirmation: Bool = false
    ) {
        self.id = id
        self.title = title
        self.dateText = dateText
        self.timeText = timeText
        self.listID = listID
        self.notes = notes
        self.dateNeedsConfirmation = dateNeedsConfirmation
    }

    func validationMessage(lists: [ReminderList], calendar: Calendar) -> String? {
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "제목을 입력하세요." }
        if dateNeedsConfirmation { return "날짜 원문을 확인하고 날짜를 직접 확정하세요." }
        guard
            ScheduleDateParser.components(date: dateText, time: timeText, calendar: calendar) != nil
        else {
            return "날짜는 yyyy-MM-dd, 시각은 HH:mm으로 확인하세요. 시각은 비워둘 수 있어요."
        }
        guard let listID, lists.contains(where: { $0.id == listID }) else {
            return "저장할 목록을 선택하세요."
        }
        return nil
    }
}

struct AnalysisContext: Sendable {
    let referenceDate: Date
    let calendar: Calendar
    let lists: [ReminderList]
    var userGuidance: String = ""
}

enum ScheduleDateParser {
    static func dateText(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = parts.year, let month = parts.month, let day = parts.day,
            (1...9999).contains(year), (1...12).contains(month), (1...31).contains(day)
        else { return "" }
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    static func components(date: String, time: String, calendar: Calendar) -> DateComponents? {
        let dateParts = date.split(separator: "-", omittingEmptySubsequences: false)
        guard dateParts.count == 3, dateParts.map(\.count) == [4, 2, 2],
            dateParts.allSatisfy({ $0.utf8.allSatisfy { (48...57).contains($0) } }),
            let year = Int(dateParts[0]), (1...9999).contains(year),
            let month = Int(dateParts[1]), (1...12).contains(month),
            let day = Int(dateParts[2]), (1...31).contains(day)
        else { return nil }
        var parts = DateComponents(timeZone: calendar.timeZone, year: year, month: month, day: day)
        if !time.isEmpty {
            let clock = time.split(separator: ":", omittingEmptySubsequences: false)
            guard clock.count == 2, clock.map(\.count) == [2, 2],
                clock.allSatisfy({ $0.utf8.allSatisfy { (48...57).contains($0) } }),
                let hour = Int(clock[0]), (0...23).contains(hour),
                let minute = Int(clock[1]), (0...59).contains(minute)
            else { return nil }
            parts.hour = hour
            parts.minute = minute
        }
        // Foundation normalizes impossible dates. Round trip instead of accepting that normalization.
        guard let resolved = calendar.date(from: parts) else { return nil }
        let check = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: resolved)
        guard check.year == year, check.month == month, check.day == day else { return nil }
        if !time.isEmpty, check.hour != parts.hour || check.minute != parts.minute { return nil }
        parts.calendar = calendar
        return parts
    }
}

enum ScheduleTimeParser {
    static let clockPattern =
        #"(?<![0-9])(오전|오후|아침|저녁|밤)?\s*([0-9]{1,2})(?::([0-9]{2})|시(?:\s*([0-9]{1,2})분)?(?:\s*(반))?)(?![0-9])"#

    static func clock(from expression: String?, source: String) -> (hour: Int, minute: Int)? {
        guard let expression else { return nil }
        let value = expression.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, source.contains(value) else { return nil }
        guard let regex = try? NSRegularExpression(pattern: clockPattern) else { return nil }
        let matches = regex.matches(in: value, range: NSRange(value.startIndex..., in: value))
        guard matches.count == 1, let match = matches.first,
            let clockRange = Range(match.range, in: value),
            let evidence = source.range(
                of: String(value[clockRange]).trimmingCharacters(in: .whitespaces))
        else { return nil }
        let suffix = source[evidence.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !suffix.hasPrefix("까지"), !suffix.hasPrefix("종료"), !suffix.hasPrefix("마감") else {
            return nil
        }
        let prefix =
            String(source[..<evidence.lowerBound].suffix(40))
            .components(separatedBy: .newlines).last?.replacingOccurrences(of: " ", with: "") ?? ""
        guard !["발송시각", "전송시각", "메시지시각", "작성시각"].contains(where: prefix.contains) else {
            return nil
        }
        func capture(_ index: Int) -> String? {
            guard let range = Range(match.range(at: index), in: value) else { return nil }
            return String(value[range])
        }
        guard var hour = capture(2).flatMap(Int.init) else { return nil }
        let minute =
            capture(3).flatMap(Int.init) ?? capture(4).flatMap(Int.init)
            ?? (capture(5) == nil ? 0 : 30)
        guard (0...59).contains(minute) else { return nil }
        let period = capture(1) ?? ["오전", "오후", "아침", "저녁", "밤"].first(where: prefix.hasSuffix)
        if let period {
            guard ["오전", "오후"].contains(period), (1...12).contains(hour) else { return nil }
            hour %= 12
            if period == "오후" { hour += 12 }
        } else if capture(3) == nil && hour < 13 {
            return nil
        }
        guard (0...23).contains(hour) else { return nil }
        return (hour, minute)
    }
}
