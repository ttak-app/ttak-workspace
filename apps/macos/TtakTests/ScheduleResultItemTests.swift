import Foundation
import Testing

@testable import Ttak

struct ScheduleResultItemTests {
    private let lists = [
        ReminderList(id: "personal", title: "일상"),
        ReminderList(id: "work", title: "일상"),
        ReminderList(id: "dev", title: "Dev"),
    ]

    @Test("같은 이름의 목록은 안정 ID로 구분하고 다른 이름은 그대로 표시한다")
    func duplicateListNames() {
        #expect(ScheduleResultItem.listLabel(lists[0], in: lists) == "일상 (personal)")
        #expect(ScheduleResultItem.listLabel(lists[1], in: lists) == "일상 (work)")
        #expect(ScheduleResultItem.listLabel(lists[2], in: lists) == "Dev")
    }

    @Test("편집과 제외 후 초안 ID와 모호한 시간 원문이 유지된다")
    func stableDraftIdentity() {
        var draft = ScheduleDraft(title: "회식", dateText: "2026-10-31", notes: "시간 원문: 저녁")
        let id = draft.id
        draft.title = "팀 회식"
        draft.dateText = "2026-11-01"
        draft.listID = "work"
        #expect(draft.validationMessage(lists: lists, calendar: .current) == nil)
        draft.isExcluded = true
        #expect(draft.id == id)
        #expect(draft.timeText.isEmpty)
        #expect(draft.notes == "시간 원문: 저녁")
    }

    @Test("충돌 확정 후에도 잘못된 날짜와 미선택 목록은 등록 가능으로 바뀌지 않는다")
    func confirmationDoesNotSkipValidation() {
        var draft = ScheduleDraft(title: "회의", dateText: "2026-02-30", dateNeedsConfirmation: true)
        draft.dateNeedsConfirmation = false
        #expect(draft.validationMessage(lists: lists, calendar: .current) != nil)
        draft.dateText = "2026-03-01"
        #expect(draft.validationMessage(lists: lists, calendar: .current) == "저장할 목록을 선택하세요.")
        draft.listID = "missing"
        #expect(draft.validationMessage(lists: lists, calendar: .current) == "저장할 목록을 선택하세요.")
    }
}
