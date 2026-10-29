import EventKit
import Foundation

@MainActor
protocol ReminderStoring {
    var accessDescription: String { get }
    func requestAccess() async throws -> [ReminderList]
    func writableLists() throws -> [ReminderList]
    func save(_ draft: ScheduleDraft, calendar: Calendar) throws -> String
}

enum ReminderStoreFailure: LocalizedError {
    case accessDenied
    case invalidDraft
    case listUnavailable

    var errorDescription: String? {
        switch self {
        case .accessDenied: "미리 알림 접근 권한이 없어요. 시스템 설정에서 권한을 확인하세요."
        case .invalidDraft: "저장할 제목과 날짜를 확인하세요."
        case .listUnavailable: "선택한 목록에 쓸 수 없어요. 목록을 다시 조회하고 선택하세요."
        }
    }
}

@MainActor
final class ReminderStore: ReminderStoring {
    private let eventStore = EKEventStore()

    var accessDescription: String {
        switch EKEventStore.authorizationStatus(for: .reminder) {
        case .fullAccess: "미리 알림 접근 허용됨"
        case .notDetermined: "미리 알림 접근 전"
        case .denied, .restricted: "미리 알림 접근 거부 또는 제한됨"
        default: "미리 알림 접근 상태 확인 필요"
        }
    }

    func requestAccess() async throws -> [ReminderList] {
        guard try await eventStore.requestFullAccessToReminders() else {
            throw ReminderStoreFailure.accessDenied
        }
        return try writableLists()
    }

    func writableLists() throws -> [ReminderList] {
        guard EKEventStore.authorizationStatus(for: .reminder) == .fullAccess else {
            throw ReminderStoreFailure.accessDenied
        }
        return eventStore.calendars(for: .reminder)
            .filter(\.allowsContentModifications)
            .map { ReminderList(id: $0.calendarIdentifier, title: $0.title) }
    }

    func save(_ draft: ScheduleDraft, calendar: Calendar) throws -> String {
        let lists = try writableLists()
        guard draft.validationMessage(lists: lists, calendar: calendar) == nil,
            let date = ScheduleDateParser.components(
                date: draft.dateText, time: draft.timeText, calendar: calendar)
        else { throw ReminderStoreFailure.invalidDraft }
        guard let listID = draft.listID, let list = eventStore.calendar(withIdentifier: listID),
            list.allowedEntityTypes.contains(.reminder), list.allowsContentModifications
        else { throw ReminderStoreFailure.listUnavailable }
        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        reminder.calendar = list
        reminder.dueDateComponents = date
        reminder.notes = draft.notes
        // Each call commits one item so the caller can distinguish confirmed saves from unknown failures.
        do {
            try eventStore.save(reminder, commit: true)
            return reminder.calendarItemIdentifier
        } catch {
            // Discard local unsaved objects before another explicit registration attempt.
            // This does not establish whether an external write reached the store.
            eventStore.reset()
            throw error
        }
    }
}
