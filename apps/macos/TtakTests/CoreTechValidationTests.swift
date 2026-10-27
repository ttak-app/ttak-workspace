import Foundation
import Testing

@testable import Ttak

private func testCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
    return calendar
}

private func testContext() -> AnalysisContext {
    let calendar = testCalendar()
    return AnalysisContext(
        referenceDate: calendar.date(
            from: DateComponents(year: 2026, month: 10, day: 27, hour: 23, minute: 55))!,
        calendar: calendar, lists: [ReminderList(id: "test-list", title: "합성 검증")]
    )
}

private func extracted(
    kind: ExtractedDateKind = .omitted, offset: Int? = nil, year: Int? = nil,
    month: Int? = nil, day: Int? = nil, hour: Int? = nil, minute: Int? = nil,
    listID: String? = nil
) -> ExtractedSchedule {
    ExtractedSchedule(
        title: "합성 회의", dateKind: kind, dayOffset: offset, year: year, month: month,
        day: day, startTimeText: hour.map { "\($0):\(minute ?? 0)" }, listID: listID,
        notes: "종료 18:00, 원문 확인"
    )
}

struct ScheduleValidationTests {
    @Test func omittedDateUsesAnalysisDay() {
        let draft = ScheduleAnalyzer.makeDraft(extracted(), context: testContext())
        #expect(draft.dateText == "2026-10-27")
        #expect(draft.timeText.isEmpty)
    }

    @Test func relativeDatesUseFixedLocalCalendar() {
        let tomorrow = ScheduleAnalyzer.makeDraft(
            extracted(kind: .relative, offset: 1), context: testContext())
        let dayAfter = ScheduleAnalyzer.makeDraft(
            extracted(kind: .relative, offset: 2), context: testContext())
        #expect(tomorrow.dateText == "2026-10-28")
        #expect(dayAfter.dateText == "2026-10-29")
    }

    @Test func relativeDateCrossesYearUsingAnalysisTimezone() {
        let calendar = testCalendar()
        let context = AnalysisContext(
            referenceDate: calendar.date(
                from: DateComponents(year: 2026, month: 12, day: 31, hour: 23))!,
            calendar: calendar, lists: []
        )
        let draft = ScheduleAnalyzer.makeDraft(
            extracted(kind: .relative, offset: 1), context: context)
        #expect(draft.dateText == "2027-01-01")
    }

    @Test func nonexistentDSTClockIsRejected() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        #expect(
            ScheduleDateParser.components(date: "2026-03-08", time: "02:30", calendar: calendar)
                == nil)
    }

    @Test func invalidDateIsNotNormalizedIntoAnotherDay() {
        #expect(
            ScheduleDateParser.components(date: "+026-04-10", time: "", calendar: testCalendar())
                == nil)
        #expect(
            ScheduleDateParser.components(
                date: "2026-04-10", time: "09:+1", calendar: testCalendar()) == nil)
        #expect(
            ScheduleDateParser.components(
                date: "2026-02-30", time: "09:00", calendar: testCalendar()) == nil)
        #expect(
            ScheduleDateParser.components(date: "0000-04-10", time: "", calendar: testCalendar())
                == nil)
        #expect(
            ScheduleDateParser.components(
                date: "2026-04-10", time: "24:00", calendar: testCalendar()) == nil)
        #expect(
            ScheduleDateParser.components(
                date: "2026-04-10", time: "09:00", calendar: testCalendar()) != nil)
    }

    @Test func invalidOrConflictingModelDateNeedsConfirmation() {
        let invalid = ScheduleAnalyzer.makeDraft(
            extracted(kind: .explicit, year: 2026, month: 2, day: 30), context: testContext())
        let conflict = ScheduleAnalyzer.makeDraft(
            extracted(kind: .uncertain, year: 2020, month: 4, day: 10), context: testContext())
        #expect(invalid.dateNeedsConfirmation)
        #expect(conflict.dateNeedsConfirmation)
        #expect(
            conflict.validationMessage(lists: testContext().lists, calendar: testCalendar()) != nil)
    }

    @Test func unknownListNeverFallsBackToExistingList() {
        let draft = ScheduleAnalyzer.makeDraft(
            extracted(listID: "invented"), context: testContext())
        #expect(draft.listID == nil)
        #expect(
            draft.validationMessage(lists: testContext().lists, calendar: testCalendar()) != nil)
    }

    @Test func oversizedYearCannotTruncateIntoValidDate() {
        let draft = ScheduleAnalyzer.makeDraft(
            extracted(kind: .explicit, year: 4_294_969_322, month: 4, day: 10),
            context: testContext())
        #expect(draft.dateNeedsConfirmation)
        #expect(draft.dateText != "2026-04-10")
    }

    @Test func absentOrInvalidTimeKeepsNotesWithoutInventingClock() {
        let absent = ScheduleAnalyzer.makeDraft(extracted(), context: testContext())
        let invalid = ScheduleAnalyzer.makeDraft(
            extracted(hour: 28, minute: 70), context: testContext())
        #expect(absent.timeText.isEmpty)
        #expect(absent.notes.contains("18:00"))
        #expect(invalid.timeText.isEmpty)
        #expect(invalid.notes.contains("28:70"))
    }

    @Test func clockNeedsVerbatimInputEvidence() {
        #expect(ScheduleTimeParser.clock(from: "오전 9시", source: "내일 회의") == nil)
        let clock = ScheduleTimeParser.clock(from: "오전 9시", source: "내일 오전 9시 회의")
        #expect(clock?.hour == 9)
        #expect(clock?.minute == 0)
        #expect(ScheduleTimeParser.clock(from: "내일 오전 9시", source: "내일 오전 9시 회의")?.hour == 9)
    }

    @Test func vagueAndEndOnlyTimeNeverBecomeStartClock() {
        #expect(ScheduleTimeParser.clock(from: "저녁", source: "저녁 회식") == nil)
        #expect(ScheduleTimeParser.clock(from: "1시", source: "1시 모임") == nil)
        #expect(ScheduleTimeParser.clock(from: "18:00", source: "지금~18:00까지 모임") == nil)
        #expect(ScheduleTimeParser.clock(from: "13:08", source: "메시지 발송 시각 13:08") == nil)
    }

    @Test func explicitClockConversionKeepsMinutes() {
        let afternoon = ScheduleTimeParser.clock(from: "오후 6시 15분", source: "오후 6시 15분 모임")
        let midnight = ScheduleTimeParser.clock(from: "오전 12시", source: "오전 12시 시작")
        #expect(afternoon?.hour == 18)
        #expect(afternoon?.minute == 15)
        #expect(midnight?.hour == 0)
        #expect(ScheduleTimeParser.clock(from: "12:00", source: "오전 12:00 회의")?.hour == 0)
    }

    @Test func nightClockIsNotSilentlyConvertedToNoon() {
        #expect(ScheduleTimeParser.clock(from: "밤 12시", source: "밤 12시 모임") == nil)
        #expect(ScheduleTimeParser.clock(from: "밤 1시", source: "밤 1시 모임") == nil)
        #expect(ScheduleTimeParser.clock(from: "12:00", source: "밤 12:00 모임") == nil)
    }

    @Test func blankTitleCannotSave() {
        let draft = ScheduleDraft(title: "  ", dateText: "2026-10-27", listID: "test-list")
        #expect(
            draft.validationMessage(lists: testContext().lists, calendar: testCalendar()) != nil)
    }
}

private struct StubAnalyzer: ScheduleAnalyzing {
    var failure = false
    var delay = false
    func availabilityDescription() -> String { "합성 모델" }
    func analyze(text: String, context: AnalysisContext) async throws -> [ScheduleDraft] {
        if delay { try await Task.sleep(for: .milliseconds(50)) }
        if failure { throw AnalysisFailure.unavailable("합성 실패") }
        return [
            ScheduleDraft(
                title: text, dateText: "2026-10-27", listID: "test-list",
                notes: context.userGuidance)
        ]
    }
}

private struct StubRecognizer: ImageTextRecognizing {
    var fails = false
    func recognize(data: Data) async throws -> String {
        if fails { throw ImageRecognitionFailure.noText }
        return "합성 이미지 일정"
    }
}

@MainActor
private final class StubReminderStore: ReminderStoring {
    var lists = [ReminderList(id: "test-list", title: "합성 검증")]
    var accessDescription: String { "합성 권한" }
    var saved: [ScheduleDraft] = []
    var saveCalls = 0
    var failureAt: Int?
    var denied = false
    func requestAccess() async throws -> [ReminderList] { try writableLists() }
    func writableLists() throws -> [ReminderList] {
        if denied { throw ReminderStoreFailure.accessDenied }
        return lists
    }
    func save(_ draft: ScheduleDraft, calendar: Calendar) throws -> String {
        saveCalls += 1
        if saveCalls == failureAt { throw ReminderStoreFailure.listUnavailable }
        saved.append(draft)
        return UUID().uuidString
    }
}

@MainActor
struct ScheduleInputModelTests {
    @Test func analyzeAndCancelNeverWriteReminders() async {
        let store = StubReminderStore()
        let model = ScheduleInputModel(
            analyzer: StubAnalyzer(), recognizer: StubRecognizer(), reminderStore: store)
        model.input = "합성 회의"
        model.startAnalysis(now: testContext().referenceDate, calendar: testCalendar())
        await model.waitForAnalysis()
        #expect(model.drafts.count == 1)
        #expect(store.saveCalls == 0)
        model.cancelPreview()
        #expect(model.input == "합성 회의")
        #expect(model.drafts.isEmpty)
        #expect(store.saveCalls == 0)
    }

    @Test func editedFinalValueSavesOnlyOnceAndClearsInput() async {
        let store = StubReminderStore()
        let model = ScheduleInputModel(
            analyzer: StubAnalyzer(), recognizer: StubRecognizer(), reminderStore: store)
        await model.loadLists()
        model.input = "합성 원문"
        model.startAnalysis(now: testContext().referenceDate, calendar: testCalendar())
        await model.waitForAnalysis()
        model.drafts[0].title = "수정한 제목"
        model.saveConfirmedDrafts()
        model.saveConfirmedDrafts()
        #expect(store.saved.count == 1)
        #expect(store.saved.first?.title == "수정한 제목")
        #expect(model.input.isEmpty)
        #expect(model.drafts.isEmpty)
        #expect(model.message == "1개 등록 완료")
    }

    @Test func changedListPreventsAnyWrite() async {
        let store = StubReminderStore()
        let model = ScheduleInputModel(reminderStore: store)
        await model.loadLists()
        model.drafts = [ScheduleDraft(title: "합성", dateText: "2026-10-27", listID: "test-list")]
        store.lists = []
        model.saveConfirmedDrafts()
        #expect(store.saveCalls == 0)
        #expect(!model.hasAttemptedSave)
        #expect(!model.canSave)
    }

    @Test func partialUnknownSaveStopsAndBlocksRetry() async {
        let store = StubReminderStore()
        store.failureAt = 2
        let model = ScheduleInputModel(reminderStore: store)
        await model.loadLists()
        model.input = "합성 3개"
        model.drafts = (1...3).map {
            ScheduleDraft(title: "항목 \($0)", dateText: "2026-10-27", listID: "test-list")
        }
        model.saveConfirmedDrafts()
        model.saveConfirmedDrafts()
        #expect(store.saveCalls == 2)
        #expect(store.saved.count == 1)
        #expect(model.saveOutcomes.map(\.status) == [.saved, .unknown, .notAttempted])
        #expect(model.hasAttemptedSave)
        #expect(!model.canSave)
        #expect(!model.canAnalyze)
        #expect(model.input == "합성 3개")
        #expect(!model.message.contains("등록 완료"))
    }

    @Test func excludedInvalidItemIsNeverSaved() async {
        let store = StubReminderStore()
        let model = ScheduleInputModel(reminderStore: store)
        await model.loadLists()
        var excluded = ScheduleDraft(title: "", dateText: "0000-00-00")
        excluded.isExcluded = true
        model.drafts = [
            excluded,
            ScheduleDraft(title: "포함 항목", dateText: "2026-10-27", listID: "test-list"),
        ]
        model.saveConfirmedDrafts()
        #expect(store.saved.map(\.title) == ["포함 항목"])
    }

    @Test func fullFailureNeverShowsSuccess() async {
        let store = StubReminderStore()
        store.failureAt = 1
        let model = ScheduleInputModel(reminderStore: store)
        await model.loadLists()
        model.drafts = [ScheduleDraft(title: "합성", dateText: "2026-10-27", listID: "test-list")]
        model.saveConfirmedDrafts()
        #expect(store.saved.isEmpty)
        #expect(model.saveOutcomes.first?.status == .unknown)
        #expect(model.hasAttemptedSave)
    }

    @Test func deniedPermissionKeepsInputAndNoWrite() async {
        let store = StubReminderStore()
        store.denied = true
        let model = ScheduleInputModel(reminderStore: store)
        model.input = "보존할 합성 입력"
        await model.loadLists()
        #expect(model.lists.isEmpty)
        #expect(model.input == "보존할 합성 입력")
        #expect(store.saveCalls == 0)
        #expect(model.message.contains("권한"))
    }

    @Test func imageOnlyUsesCommonAnalyzer() async {
        let model = ScheduleInputModel(
            analyzer: StubAnalyzer(), recognizer: StubRecognizer(),
            reminderStore: StubReminderStore())
        model.attachImage(Data([1]), name: "합성 이미지")
        model.startAnalysis(now: testContext().referenceDate, calendar: testCalendar())
        await model.waitForAnalysis()
        #expect(model.drafts.first?.title.contains("합성 이미지 일정") == true)
    }

    @Test func imageGuidanceIsSeparateFromOCRSource() async {
        let model = ScheduleInputModel(
            analyzer: StubAnalyzer(), recognizer: StubRecognizer(),
            reminderStore: StubReminderStore())
        model.attachImage(Data([1]), name: "합성 이미지")
        model.input = "이 중 회의만 등록해줘"
        model.startAnalysis()
        await model.waitForAnalysis()
        #expect(model.drafts.first?.title == "합성 이미지 일정")
        #expect(model.drafts.first?.notes == "이 중 회의만 등록해줘")
    }

    @Test func ocrFailurePreservesImageAndDoesNotReturnSchedule() async {
        let model = ScheduleInputModel(
            analyzer: StubAnalyzer(), recognizer: StubRecognizer(fails: true),
            reminderStore: StubReminderStore())
        model.attachImage(Data([1]), name: "합성 이미지")
        model.startAnalysis()
        await model.waitForAnalysis()
        #expect(model.imageData != nil)
        #expect(model.drafts.isEmpty)
        #expect(model.message.contains("이미지 인식 실패"))
    }

    @Test func modelFailureIsDistinctFromOcrFailure() async {
        let model = ScheduleInputModel(
            analyzer: StubAnalyzer(failure: true), recognizer: StubRecognizer(),
            reminderStore: StubReminderStore())
        model.input = "합성 입력"
        model.startAnalysis()
        await model.waitForAnalysis()
        #expect(model.drafts.isEmpty)
        #expect(model.message.contains("모델 사용 불가"))
        #expect(model.input == "합성 입력")
    }

    @Test func cancelledOldAnalysisCannotOverwriteNewInput() async {
        let model = ScheduleInputModel(
            analyzer: StubAnalyzer(delay: true), recognizer: StubRecognizer(),
            reminderStore: StubReminderStore())
        model.input = "이전 입력"
        model.startAnalysis()
        model.cancelAnalysis()
        model.input = "새 입력"
        model.startAnalysis()
        await model.waitForAnalysis()
        #expect(model.drafts.first?.title == "새 입력")
        #expect(!model.isAnalyzing)
    }
}
