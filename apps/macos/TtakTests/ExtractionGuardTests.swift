import Foundation
import Testing

@testable import Ttak

private func guardContext() -> AnalysisContext {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
    return AnalysisContext(
        referenceDate: calendar.date(from: DateComponents(year: 2026, month: 10, day: 27))!,
        calendar: calendar, lists: [])
}

private func candidate(
    _ source: String, action: String, date: String? = nil, time: String? = nil, notes: String = ""
) -> GroundedSchedule {
    GroundedSchedule(
        sourceText: source, actionText: action, dateText: date,
        startTimeText: time, notes: notes, listID: nil)
}

struct ExtractionGuardTests {
    @Test(arguments: [
        ("내일은 회의", "회의", "2026-10-28"), ("모레에 점심", "점심", "2026-10-29"),
        ("내일, 회의", "회의", "2026-10-28"),
    ])
    func relativeDateParticlesKeepTheirDate(source: String, action: String, date: String) throws {
        let candidates = try ScheduleExtractionGuard.groundActions([action], source: source)
        let result = ScheduleExtractionGuard.validate(
            candidates, source: source, context: guardContext())
        #expect(result.issues.isEmpty)
        #expect(result.drafts.first?.dateText == date)
    }

    @Test func repairedClockPreservesHalfHour() throws {
        let source = "내일 오전 9시 반 회의하고 저녁 회식"
        let candidates = try ScheduleExtractionGuard.groundActions(["회의", "회식"], source: source)
        let result = ScheduleExtractionGuard.validate(
            candidates, source: source, context: guardContext())
        #expect(result.issues.isEmpty)
        #expect(result.drafts.map(\.timeText) == ["09:30", ""])
    }

    @Test(arguments: ["메시지 발송", "메시지 발송하기", "메시지 발송 내일"])
    func sendingMessageIsAnActivity(source: String) throws {
        #expect(!ScheduleExtractionGuard.isOnlyDescriptiveInput(source))
        let candidates = try ScheduleExtractionGuard.groundActions(["메시지 발송"], source: source)
        let result = ScheduleExtractionGuard.validate(
            candidates, source: source, context: guardContext())
        #expect(result.issues.isEmpty)
        #expect(result.drafts.first?.title == "메시지 발송")
        if source.contains("내일") { #expect(result.drafts.first?.dateText == "2026-10-28") }
    }

    @Test func messageTimestampRemainsMetadata() {
        #expect(ScheduleExtractionGuard.isOnlyDescriptiveInput("메시지 발송 시각 13:08"))
        let source = "메시지 발송 날짜: 내일\n모레 회의"
        let result = ScheduleExtractionGuard.validate(
            [candidate("모레 회의", action: "회의")], source: source, context: guardContext())
        #expect(result.issues.isEmpty)
        #expect(result.drafts.first?.dateText == "2026-10-29")
    }

    @Test func whitespaceNormalizationCannotJoinActivitiesAcrossLines() {
        #expect(throws: (any Error).self) {
            try ScheduleExtractionGuard.groundActions(["회의점심"], source: "회의\n점심")
        }
    }

    @Test func writingActivityDoesNotHideTheNextDate() {
        let source = "문서 작성하고 내일 회의"
        let result = ScheduleExtractionGuard.validate(
            [
                candidate("문서 작성", action: "문서 작성"),
                candidate("내일 회의", action: "회의", date: "내일"),
            ], source: source, context: guardContext())
        #expect(result.issues.isEmpty)
        #expect(result.drafts.map(\.dateText) == ["2026-10-27", "2026-10-28"])
    }
    @Test func repairedActionSpansKeepSharedDateAndSeparateClocks() throws {
        let source = "내일 오전 9시 런닝하고 저녁에 회식"
        let candidates = try ScheduleExtractionGuard.groundActions(["런닝", "회식"], source: source)
        let result = ScheduleExtractionGuard.validate(
            candidates, source: source, context: guardContext())
        #expect(result.issues.isEmpty)
        #expect(result.drafts.map(\.title) == ["런닝", "회식"])
        #expect(result.drafts.map(\.dateText) == ["2026-10-28", "2026-10-28"])
        #expect(result.drafts.map(\.timeText) == ["09:00", ""])
    }

    @Test func repairedRepeatedTitlesUseAllDistinctOccurrences() throws {
        let source = "내일 회의하고 모레 회의"
        let candidates = try ScheduleExtractionGuard.groundActions(["회의", "회의"], source: source)
        let result = ScheduleExtractionGuard.validate(
            candidates, source: source, context: guardContext())
        #expect(result.issues.isEmpty)
        #expect(result.drafts.map(\.dateText) == ["2026-10-28", "2026-10-29"])
    }

    @Test func metadataSubstringIsNotAnotherActionOccurrence() throws {
        let source = "내일 회의\n장소: 가상 회의실"
        let candidates = try ScheduleExtractionGuard.groundActions(["회의"], source: source)
        let result = ScheduleExtractionGuard.validate(
            candidates, source: source, context: guardContext())
        #expect(result.issues.isEmpty)
        #expect(result.drafts.count == 1)
    }

    @Test func overlappingWholeInputQuotesCannotShareAnotherActionsClock() {
        let source = "내일 런닝하고 회식"
        let result = ScheduleExtractionGuard.validate(
            [
                candidate(source, action: "런닝", date: "내일"),
                candidate(source, action: "회식", date: "내일"),
            ], source: source, context: guardContext())
        #expect(result.issues.contains { $0.contains("여러 행동") })
    }

    @Test func repairedClausesUseTemporalBoundariesWithoutFixedActionWords() throws {
        let source = "내일 오전 10시 도서관 가고 오후 2시 치과 예약"
        let candidates = try ScheduleExtractionGuard.groundActions(
            ["도서관", "치과 예약"], source: source)
        let result = ScheduleExtractionGuard.validate(
            candidates, source: source, context: guardContext())
        #expect(result.issues.isEmpty)
        #expect(result.drafts.map(\.timeText) == ["10:00", "14:00"])
    }

    @Test func anotherActionsMetadataIsRejected() {
        let source = "내일 회의\n장소: 회의실 A\n모레 점심\n장소: 식당 B"
        let result = ScheduleExtractionGuard.validate(
            [
                candidate("내일 회의", action: "회의", date: "내일", notes: "장소: 식당 B"),
                candidate("모레 점심", action: "점심", date: "모레"),
            ], source: source, context: guardContext())
        #expect(result.issues.contains { $0.contains("다른 행동에 속하거나") })
    }

    @Test func missingActionEvidenceIsRejected() {
        let result = ScheduleExtractionGuard.validate(
            [candidate("내일 회의", action: "런닝", date: "내일")],
            source: "내일 회의", context: guardContext())
        #expect(!result.issues.isEmpty)
    }

    @Test func sharedDateDoesNotShareClock() {
        let result = ScheduleExtractionGuard.validate(
            [
                candidate("내일 오전 9시 런닝", action: "런닝", date: "내일", time: "오전 9시"),
                candidate("저녁에 회식", action: "회식", date: "내일"),
            ], source: "내일 오전 9시 런닝하고 저녁에 회식", context: guardContext())
        #expect(result.issues.isEmpty)
        #expect(result.drafts.map(\.dateText) == ["2026-10-28", "2026-10-28"])
        #expect(result.drafts.map(\.timeText) == ["09:00", ""])
        #expect(result.drafts[1].notes.contains("저녁"))
    }

    @Test func anotherActionsClockIsRejected() {
        let result = ScheduleExtractionGuard.validate(
            [
                candidate("내일 오전 9시 런닝", action: "런닝", date: "내일", time: "오전 9시"),
                candidate("저녁에 회식", action: "회식", date: "내일", time: "오전 9시"),
            ], source: "내일 오전 9시 런닝하고 저녁에 회식", context: guardContext())
        #expect(result.issues.contains { $0.contains("다른 행동의 시각") })
    }

    @Test func nearestDateOverridesPreviousDay() {
        let result = ScheduleExtractionGuard.validate(
            [
                candidate("내일 런닝", action: "런닝", date: "내일"),
                candidate("모레 정훈 점심", action: "정훈 점심", date: "모레"),
            ], source: "내일 런닝하고 모레 정훈 점심", context: guardContext())
        #expect(result.issues.isEmpty)
        #expect(result.drafts.map(\.dateText) == ["2026-10-28", "2026-10-29"])
    }

    @Test func incorrectDateReferenceIsRejected() {
        let result = ScheduleExtractionGuard.validate(
            [
                candidate("내일 런닝", action: "런닝", date: "내일"),
                candidate("모레 점심", action: "점심", date: "내일"),
            ], source: "내일 런닝하고 모레 점심", context: guardContext())
        #expect(result.issues.contains { $0.contains("dateText") })
    }

    @Test func wholeInputQuoteDoesNotHideMissingAction() {
        let source = "내일 런닝하고 저녁 회식"
        let result = ScheduleExtractionGuard.validate(
            [candidate(source, action: "런닝", date: "내일", notes: "저녁 회식")],
            source: source, context: guardContext())
        #expect(result.issues.contains { $0.contains("누락 의심") })
    }

    @Test func compoundTitleIsNotSplitByConjunction() {
        let source = "디자인 및 개발 회의"
        let result = ScheduleExtractionGuard.validate(
            [candidate(source, action: source)], source: source, context: guardContext())
        #expect(result.issues.isEmpty)
        #expect(result.drafts.count == 1)
    }

    @Test func duplicateEvidenceIsNotSilentlyAccepted() {
        let item = candidate("내일 회의", action: "회의", date: "내일")
        let result = ScheduleExtractionGuard.validate(
            [item, item], source: "내일 회의", context: guardContext())
        #expect(result.issues.contains { $0.contains("중복 추출") })
    }

    @Test func repeatedTitlesWithDifferentDateQuotesAreSeparate() {
        let result = ScheduleExtractionGuard.validate(
            [
                candidate("내일 회의", action: "회의", date: "내일"),
                candidate("모레 회의", action: "회의", date: "모레"),
            ], source: "내일 회의하고 모레 회의", context: guardContext())
        #expect(result.issues.isEmpty)
        #expect(result.drafts.map(\.dateText) == ["2026-10-28", "2026-10-29"])
    }

    @Test func ambiguousRepeatedSourceIsNotAttachedToFirstOccurrence() {
        let result = ScheduleExtractionGuard.validate(
            [candidate("회의", action: "회의")], source: "회의\n회의", context: guardContext())
        #expect(!result.issues.isEmpty)
    }

    @Test func unsupportedGroundedDateNeedsConfirmation() {
        let source = "다음 주 화요일 회의"
        let result = ScheduleExtractionGuard.validate(
            [candidate(source, action: "회의", date: "다음 주 화요일")],
            source: source, context: guardContext())
        #expect(result.issues.isEmpty)
        #expect(result.drafts.first?.dateNeedsConfirmation == true)
        #expect(result.drafts.first?.dateText.isEmpty == true)
    }

    @Test func numericRelativeDateDoesNotBecomeMonthAndDay() {
        let source = "2주 후 회의"
        let result = ScheduleExtractionGuard.validate(
            [candidate(source, action: "회의", date: "2주 후")],
            source: source, context: guardContext())
        #expect(result.issues.isEmpty)
        #expect(result.drafts.first?.dateNeedsConfirmation == true)
        #expect(result.drafts.first?.dateText.isEmpty == true)
    }

    @Test func overflowingYearDoesNotBecomeCurrentYear() {
        let date = "9999999999999999999999999999년 4월 10일"
        let source = "\(date) 회의"
        let result = ScheduleExtractionGuard.validate(
            [candidate(source, action: "회의", date: date)], source: source, context: guardContext())
        #expect(result.issues.isEmpty)
        #expect(result.drafts.first?.dateNeedsConfirmation == true)
        #expect(result.drafts.first?.dateText != "2026-04-10")
    }

    @Test func dateSubstringInsideTitleCannotJustifyTomorrow() {
        let source = "내일신문 구독"
        let result = ScheduleExtractionGuard.validate(
            [candidate(source, action: source, date: "내일")], source: source, context: guardContext()
        )
        #expect(!result.issues.isEmpty)
    }

    @Test func dateWordInNewspaperTitleDoesNotBecomeTomorrow() {
        let source = "내일신문 구독"
        let result = ScheduleExtractionGuard.validate(
            [candidate(source, action: source)], source: source, context: guardContext())
        #expect(result.issues.isEmpty)
        #expect(result.drafts.first?.dateText == "2026-10-27")
    }

    @Test func nilPlaceholderDoesNotLeakToNotes() {
        let result = ScheduleExtractionGuard.validate(
            [candidate("내일 회의", action: "회의", date: "내일", time: "nil")],
            source: "내일 회의", context: guardContext())
        #expect(result.issues.isEmpty)
        #expect(result.drafts.first?.notes.contains("시작 시각 확인 필요: nil") == false)
    }
}

private actor ScriptedModel: ScheduleModelServing {
    var responses: [[GroundedSchedule]]
    var calls = 0
    var feedbackHistory: [[String]] = []
    init(_ responses: [[GroundedSchedule]]) { self.responses = responses }
    nonisolated func availabilityDescription() -> String { "합성 모델" }
    func extract(text: String, context: AnalysisContext, feedback: [String]) async throws
        -> [GroundedSchedule]
    {
        feedbackHistory.append(feedback)
        let response = responses[min(calls, responses.count - 1)]
        calls += 1
        return response
    }
    func select(candidates: [ScheduleDraft], guidance: String) async throws -> [Int] { [0] }
}

struct ExtractionRetryTests {
    @Test func metadataOnlyInputDoesNotCreateModelActivities() async {
        let model = ScriptedModel([[candidate("장소: 회의실", action: "회의실")]])
        do {
            _ = try await ScheduleAnalyzer(model: model).analyze(
                text: "장소: 회의실", context: guardContext())
            Issue.record("메타정보만 있는 입력이 일정으로 반환됨")
        } catch {
            if case AnalysisFailure.emptyResult = error {
            } else {
                Issue.record("일정 없음과 오류를 구분해야 함")
            }
        }
        #expect(await model.calls == 0)
    }

    @Test func emptyRepairCannotHideAnUnverifiedAction() async {
        let model = ScriptedModel([[candidate("내일 회의", action: "런닝")], []])
        do {
            _ = try await ScheduleAnalyzer(model: model).analyze(
                text: "내일 회의", context: guardContext())
            Issue.record("미확인 행동이 정상 결과로 반환됨")
        } catch {
            #expect(error.localizedDescription.contains("일정 분리 확인 필요"))
        }
        #expect(await model.calls == 2)
    }
    @Test func validResultDoesNotTriggerRepair() async throws {
        let model = ScriptedModel([[candidate("내일 회의", action: "회의", date: "내일")]])
        let result = try await ScheduleAnalyzer(model: model).analyze(
            text: "내일 회의", context: guardContext())
        #expect(result.count == 1)
        #expect(await model.calls == 1)
    }

    @Test func violationTriggersOneRepairWithFeedback() async throws {
        let model = ScriptedModel([
            [candidate("내일 회의", action: "런닝")],
            [candidate("내일 회의", action: "회의", date: "내일")],
        ])
        let result = try await ScheduleAnalyzer(model: model).analyze(
            text: "내일 회의", context: guardContext())
        #expect(result.first?.title == "회의")
        #expect(await model.calls == 2)
        #expect(await model.feedbackHistory.last?.isEmpty == false)
    }

    @Test func repeatedViolationStopsWithoutReturningPartialSuccess() async {
        let model = ScriptedModel([[candidate("내일 회의", action: "런닝")]])
        do {
            _ = try await ScheduleAnalyzer(model: model).analyze(
                text: "내일 회의", context: guardContext())
            Issue.record("확인되지 않은 후보가 정상 결과로 반환됨")
        } catch {
            #expect(error.localizedDescription.contains("일정 분리 확인 필요"))
        }
        #expect(await model.calls == 2)
    }
}
