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
    _ source: String, action: String, date: String? = nil, time: String? = nil, notes: String = "",
    titleParts: [String] = [], location: String? = nil
) -> GroundedSchedule {
    GroundedSchedule(
        sourceText: source, actionText: action, titleParts: titleParts, locationText: location,
        dateText: date,
        startTimeText: time, notes: notes, listID: nil)
}

struct ExtractionGuardTests {
    @Test func nightMidnightBelongsToTheFollowingDay() {
        for (source, expectedDate) in [
            ("오늘 밤 12시에 서버 점검", "2026-10-28"),
            ("내일 밤 12시에 서버 점검", "2026-10-29"),
            ("2026년 12월 31일 밤 12시 점검", "2027-01-01"),
        ] {
            let rows = ScheduleExtractionGuard.groundSources([source], source: source)
            let result = ScheduleExtractionGuard.validate(
                rows, source: source, context: guardContext())
            #expect(result.issues.isEmpty)
            #expect(result.drafts.first?.dateText == expectedDate)
            #expect(result.drafts.first?.timeText == "00:00")
            #expect(result.drafts.first?.notes.contains(source) == true)
        }
    }

    @Test func timeRangeUsesStartAndKeepsFullRangeInNotes() {
        for (source, expected) in [
            ("내일 오후 1시부터 3시까지 디자인 워크숍", "13:00"),
            ("내일 18시부터 20시까지 독서모임 회식", "18:00"),
            ("내일 11시부터 1시까지 회의", "11:00"),
        ] {
            let rows = ScheduleExtractionGuard.groundSources([source], source: source)
            let result = ScheduleExtractionGuard.validate(
                rows, source: source, context: guardContext())
            #expect(result.issues.isEmpty)
            #expect(result.drafts.count == 1)
            #expect(result.drafts.first?.timeText == expected)
            #expect(result.drafts.first?.notes.contains(source) == true)
            #expect(result.drafts.first?.title.contains("부터") == false)
            #expect(result.drafts.first?.title.contains("까지") == false)
        }
    }

    @Test func keywordTitlesKeepShortTitlesAndFullEvidenceSeparately() throws {
        let scopes = [
            "내일 오전 9시 반에 민수랑 온라인 줌으로 기획안 검토",
            "12시에는 지수랑 합정에서 점심 약속 있어",
            "모레 오후 3시에는 도서관에서 내일신문 자료 조사",
            "18시부터 20시까지 독서모임 회식 있어",
        ]
        let source = scopes[0] + "하고 " + scopes[1] + ". " + scopes[2] + "하고 " + scopes[3]
        let rows = ScheduleExtractionGuard.groundSources(scopes, source: source).map { row in
            var formatted = row
            formatted.titleKeywords = ScheduleTitleNormalizer.compactKeywords(
                action: row.actionText)
            return formatted
        }
        let result = ScheduleExtractionGuard.validate(rows, source: source, context: guardContext())
        #expect(result.issues.isEmpty)
        #expect(rows.allSatisfy { $0.titleKeywords != nil })
        #expect(
            result.drafts.map(\.title) == [
                "민수 온라인 줌 미팅", "지수 합정 점심", "도서관 자료조사", "독서모임 회식",
            ])
        #expect(result.drafts.map(\.timeText) == ["09:30", "12:00", "15:00", "18:00"])
        #expect(result.drafts[0].notes.contains("기획안 검토"))
        #expect(result.drafts[2].notes.contains("내일신문"))
        #expect(result.drafts[3].notes.contains("20시까지"))
    }

    @Test func keywordTitleCannotBorrowAnotherPersonOrVenue() {
        #expect(throws: AnalysisFailure.self) {
            try ScheduleTitleNormalizer.keywordTitle(["지수", "부산", "점심"], source: "민수랑 합정에서 점심")
        }
    }

    @Test func keywordTitleCannotDropNegationOrChangeCancellationIntoAMeeting() {
        let source = "민수 없이 회의 취소 여부 확인"
        #expect(throws: AnalysisFailure.self) {
            try ScheduleTitleNormalizer.keywordTitle(["민수", "미팅"], source: source)
        }
        #expect(throws: AnalysisFailure.self) {
            try ScheduleTitleNormalizer.keywordTitle(["민수", "없이", "회의", "취소"], source: source)
        }
        #expect(throws: Never.self) {
            try ScheduleTitleNormalizer.keywordTitle(
                ["민수", "없이", "회의", "취소", "여부", "확인"], source: source)
        }
    }

    @Test func meetingAliasNeedsAMeetingContext() throws {
        #expect(try ScheduleTitleNormalizer.keywordTitle(["미팅"], source: "줌으로 기획안 검토") == "미팅")
        #expect(throws: AnalysisFailure.self) {
            try ScheduleTitleNormalizer.keywordTitle(["미팅"], source: "줌 설치")
        }
        #expect(throws: AnalysisFailure.self) {
            try ScheduleTitleNormalizer.keywordTitle(["미팅"], source: "회의실 청소")
        }
    }

    @Test func compactTitlesUseNewNamesAndPreserveUnclearOrCriticalActions() {
        #expect(
            ScheduleTitleNormalizer.compactKeywords(action: "유진이랑 카페봄에서 아침 식사") == [
                "유진", "카페봄", "아침식사",
            ])
        #expect(
            ScheduleTitleNormalizer.compactKeywords(action: "지수랑 도서관에서 자료 정리하기") == [
                "지수", "도서관", "자료정리",
            ])
        #expect(
            ScheduleTitleNormalizer.compactKeywords(action: "온라인 줌 미팅 있어") == ["온라인", "줌", "미팅"])
        for action in [
            "민수 없이 온라인 회의 취소 여부 확인", "회의 안 하기", "아리랑 공연", "민수랑 역 앞에서 점심",
            "온라인 회의 일정 변경", "민수랑 점심 대신 병원 가기", "줌 검토 내용 삭제",
        ] {
            #expect(ScheduleTitleNormalizer.compactKeywords(action: action) == nil)
        }
    }

    @Test func keywordTitleDistinguishesClockFromAProperName() throws {
        #expect(try ScheduleTitleNormalizer.keywordTitle(["내일신문"], source: "내일신문 구독") == "내일신문")
        #expect(throws: AnalysisFailure.self) {
            try ScheduleTitleNormalizer.keywordTitle(["9시", "회의"], source: "9시 회의")
        }
    }

    @Test func compactTitlesKeepAPersonAndTheirGroupTogether() throws {
        let source = "내일 18시에 민수랑 개발팀 회식 있어"
        var rows = ScheduleExtractionGuard.groundSources([source], source: source)
        rows[0].titleKeywords = ScheduleTitleNormalizer.compactKeywords(action: rows[0].actionText)
        let result = ScheduleExtractionGuard.validate(rows, source: source, context: guardContext())
        #expect(result.issues.isEmpty)
        #expect(result.drafts.first?.title == "민수 개발팀 회식")
        #expect(result.drafts.first?.timeText == "18:00")
        #expect(result.drafts.first?.notes.contains(source) == true)
        #expect(
            ScheduleTitleNormalizer.compactKeywords(action: "개발팀과 민수랑 개발팀 회식")
                == nil)
    }

    @Test func ambiguousConjunctionsKeepTheFullTitle() throws {
        for action in ["결과 회의", "성과 회의", "학과 회의", "디자인과 개발 회의", "친구와 저녁 식사"] {
            #expect(ScheduleTitleNormalizer.compactKeywords(action: action) == nil)
            #expect(
                try ScheduleTitleNormalizer.normalize(action: action, parts: [action]) == action)
        }
        for (action, parts) in [
            ("결과 회의", ["결", "회의"]),
            ("디자인과 개발 회의", ["디자인", "개발 회의"]),
        ] {
            #expect(throws: AnalysisFailure.self) {
                try ScheduleTitleNormalizer.normalize(action: action, parts: parts)
            }
        }
    }

    @Test func aLeadingNumericClockCannotBecomeTheActionTitle() {
        let source = "9시에 산책"
        let result = ScheduleExtractionGuard.validate(
            [candidate(source, action: source, time: "9시")], source: source, context: guardContext()
        )
        #expect(result.issues.contains { $0.contains("앞의 숫자 시작 시각") })
    }

    @Test func digitsInsideAnActionArePreserved() {
        let source = "12시에 3D 모델링 회의"
        let result = ScheduleExtractionGuard.validate(
            [candidate(source, action: "3D 모델링 회의", time: "12시")], source: source,
            context: guardContext())
        #expect(result.issues.isEmpty)
        #expect(result.drafts.first?.title == "3D 모델링 회의")
    }

    @Test func aClockCannotBecomeAnUnsupportedDate() {
        let source = "9시에 산책"
        let result = ScheduleExtractionGuard.validate(
            [candidate(source, action: "산책", date: "9시", time: "9시")], source: source,
            context: guardContext())
        #expect(result.issues.contains { $0.contains("숫자 시각을 dateText") })
        #expect(result.drafts.isEmpty)
        #expect(result.checks.contains { $0.field == "dateText" && $0.status == "rejected" })
    }

    @Test func sourceGroundingPreservesPeopleGroupsPlacesAndClocks() {
        let source = "9시에 산책갈거야\n그리고 12시에 민수랑 점심 약속 있어 역 앞에서\n그리고 18시에 독서모임 회식있어"
        let rows = ScheduleExtractionGuard.groundSources(
            [
                "9시에 산책갈거야", "12시에 민수랑 점심 약속 있어 역 앞에서", "18시에 독서모임 회식있어",
            ], source: source)
        let result = ScheduleExtractionGuard.validate(rows, source: source, context: guardContext())
        #expect(result.issues.isEmpty)
        #expect(result.drafts.map(\.title) == ["산책", "민수랑 점심 약속 있어 역 앞에서", "독서모임 회식"])
        #expect(result.drafts.map(\.timeText) == ["09:00", "12:00", "18:00"])
        #expect(result.drafts.allSatisfy { !$0.dateNeedsConfirmation })
    }

    @Test func sourceGroundingCannotSilentlyDropAPersonOutsideTheQuote() {
        let source = "12시에 민수랑 점심"
        let rows = ScheduleExtractionGuard.groundSources(["점심"], source: source)
        let result = ScheduleExtractionGuard.validate(rows, source: source, context: guardContext())
        #expect(result.issues.contains { $0.contains("원문에서 빠진 정보") })
    }

    @Test func sourceGroundingAttachesMetadataToThePrecedingActivity() {
        let source = "내일 9시 회의\n장소: 회의실 A\n준비물: 노트북\n모레 12시 점심\n장소: 식당 B"
        let rows = ScheduleExtractionGuard.groundSources(["내일 9시 회의", "모레 12시 점심"], source: source)
        let result = ScheduleExtractionGuard.validate(rows, source: source, context: guardContext())
        #expect(result.issues.isEmpty)
        #expect(result.drafts[0].notes.contains("장소: 회의실 A"))
        #expect(result.drafts[0].notes.contains("준비물: 노트북"))
        #expect(!result.drafts[0].notes.contains("식당 B"))
        #expect(result.drafts[1].notes.contains("장소: 식당 B"))
    }

    @Test func temporalParticlesCannotRemoveAProperNamePrefix() {
        let source = "9시 에스파 공연"
        let rows = ScheduleExtractionGuard.groundSources([source], source: source)
        let result = ScheduleExtractionGuard.validate(rows, source: source, context: guardContext())
        #expect(result.issues.isEmpty)
        #expect(result.drafts.first?.title == "에스파 공연")
    }

    @Test func anAttachedAmbiguousTemporalParticleIsPreserved() {
        let source = "9시에스파 공연"
        let rows = ScheduleExtractionGuard.groundSources([source], source: source)
        #expect(rows.first?.actionText == "에스파 공연")
    }

    @Test func multipleValidStartClocksKeepTheExistingHoldBoundary() {
        let source = "9시 또는 10시에 회의"
        let rows = ScheduleExtractionGuard.groundSources([source], source: source)
        let result = ScheduleExtractionGuard.validate(rows, source: source, context: guardContext())
        #expect(result.timeConfirmation.contains { $0.contains("시작 시각 후보가 여러 개") })
        #expect(result.timeConfirmation.contains { $0.contains("시작 시각을 하나만") })
        #expect(!result.timeConfirmation.contains { $0.contains("시작 시각을 확인할 수 없어요") })
        #expect(result.checks.contains { $0.field == "startTimeText" && $0.status == "rejected" })
    }

    @Test func mixedValidAndUnparseableStartClocksExplainBothProblems() {
        let source = "내일 오전 9시 또는 밤 1시에 회의"
        let rows = ScheduleExtractionGuard.groundSources([source], source: source)
        let result = ScheduleExtractionGuard.validate(rows, source: source, context: guardContext())
        #expect(result.timeConfirmation.contains { $0.contains("시작 시각 후보가 여러 개") })
        #expect(result.timeConfirmation.contains { $0.contains("해석할 수 없는 시각: 밤 1시") })
        #expect(result.issues.isEmpty)
    }

    @Test func messageTimestampDoesNotHideLaterUnparseableScheduleTime() {
        let source = "내일 발송시간: 13:08이고 밤 1시에 회의"
        let rows = ScheduleExtractionGuard.groundSources([source], source: source)
        let result = ScheduleExtractionGuard.validate(rows, source: source, context: guardContext())
        #expect(result.timeConfirmation.contains { $0.contains("밤 1시") })
        #expect(!result.timeConfirmation.contains { $0.contains("13:08") })
        let validSource = "발송시간: 13:08이고 9시에 회의"
        #expect(ScheduleTimeParser.clock(from: "13:08", source: validSource) == nil)
        #expect(ScheduleTimeParser.clock(from: "9시", source: validSource)?.hour == 9)
    }

    @Test func messageTimestampLabelWithParticleIsNotAStartTime() {
        let source = "내일 9시에 회의, 메시지 발송시간은 13:08"
        let rows = ScheduleExtractionGuard.groundSources([source], source: source)
        let result = ScheduleExtractionGuard.validate(rows, source: source, context: guardContext())
        #expect(result.timeConfirmation.isEmpty)
        #expect(ScheduleTimeParser.clock(from: "13:08", source: source) == nil)
        #expect(result.drafts.first?.timeText == "09:00")
    }

    @Test func aTrailingConnectorIsRemovedOnlyBeforeAnotherLocatedSchedule() {
        let source = "내일 9시 회의하고 12시 점심"
        let rows = ScheduleExtractionGuard.groundSources(["내일 9시 회의하고", "12시 점심"], source: source)
        let result = ScheduleExtractionGuard.validate(rows, source: source, context: guardContext())
        #expect(result.issues.isEmpty)
        #expect(result.drafts.map(\.title) == ["회의", "점심"])
        let unsplit = ScheduleExtractionGuard.groundSources([source], source: source)
        let rejected = ScheduleExtractionGuard.validate(
            unsplit, source: source, context: guardContext())
        #expect(!rejected.issues.isEmpty)
    }

    @Test func aTrailingConnectorWithoutTheNextScheduleIsNotSilentlyRemoved() {
        let source = "내일 9시 회의하고 12시 점심"
        let rows = ScheduleExtractionGuard.groundSources(["내일 9시 회의하고"], source: source)
        #expect(rows.first?.actionText == "회의하고")
        #expect(
            !ScheduleExtractionGuard.validate(rows, source: source, context: guardContext()).issues
                .isEmpty)
    }

    @Test func aDateWordInsideANameDoesNotMatchTheSharedDatePrefix() {
        let source = "내일 15시에 내일신문 구독 신청"
        let rows = ScheduleExtractionGuard.groundSources([source], source: source)
        let result = ScheduleExtractionGuard.validate(rows, source: source, context: guardContext())
        #expect(result.issues.isEmpty)
        #expect(result.drafts.first?.title == "내일신문 구독 신청")
        #expect(result.drafts.first?.dateText == "2026-10-28")
    }

    @Test func separatelyExtractedMetadataStaysInThePrecedingActivityNotes() {
        let source = "내일 오전 9시 회의\n장소: 가상 회의실\n준비물: 노트북\n모레 점심 팀 식사"
        let rows = ScheduleExtractionGuard.groundSources(
            [
                "내일 오전 9시 회의", "장소: 가상 회의실", "준비물: 노트북", "모레 점심 팀 식사",
            ], source: source)
        #expect(rows.count == 2)
        let result = ScheduleExtractionGuard.validate(rows, source: source, context: guardContext())
        #expect(result.issues.isEmpty)
        #expect(result.drafts.map(\.title) == ["회의", "점심 팀 식사"])
        #expect(result.drafts.first?.notes.contains("장소: 가상 회의실") == true)
        #expect(result.drafts.first?.notes.contains("준비물: 노트북") == true)
        #expect(result.drafts.last?.notes.contains("노트북") == false)
    }

    @Test func sourceScopesContainingOnlyGroundedMetadataDoNotCreateAnActivity() {
        let source = "장소: 가상 회의실\n준비물: 노트북"
        let rows = ScheduleExtractionGuard.groundSources([source], source: source)
        #expect(rows.isEmpty)
    }

    @Test func mixedMetadataAndActivityScopesAreNotDiscarded() {
        let source = "장소: 가상 회의실\n내일 오전 9시 회의"
        let rows = ScheduleExtractionGuard.groundSources([source], source: source)
        #expect(rows.count == 1)
        #expect(rows.first?.sourceText == source)
        #expect(
            !ScheduleExtractionGuard.validate(rows, source: source, context: guardContext()).issues
                .isEmpty)
    }

    @Test func inventedOrPartialMetadataScopesStillReachTheEvidenceGuard() {
        let source = "장소: 가상 회의실"
        #expect(ScheduleExtractionGuard.groundSources(["장소: 없는 회의실"], source: source).count == 1)
        #expect(ScheduleExtractionGuard.groundSources(["장소:"], source: source).count == 1)
    }

    @Test func metadataNormalizationCannotHideTheMissingFinalActivity() {
        let source = "내일 오전 9시 회의\n장소: 가상 회의실\n준비물: 노트북\n모레 점심 팀 식사"
        let rows = ScheduleExtractionGuard.groundSources(
            [
                "내일 오전 9시 회의", "장소: 가상 회의실", "준비물: 노트북",
            ], source: source)
        #expect(rows.count == 1)
        let result = ScheduleExtractionGuard.validate(rows, source: source, context: guardContext())
        #expect(result.issues.contains { $0.contains("원문에서 빠진 정보") || $0.contains("누락 의심") })
    }

    @Test func explicitMetadataBeforeTheFirstActivityIsNotSilentlyLost() {
        let source = "장소: 가상 회의실\n준비물: 노트북\n내일 오전 9시 회의"
        let rows = ScheduleExtractionGuard.groundSources(
            [
                "장소: 가상 회의실", "준비물: 노트북", "내일 오전 9시 회의",
            ], source: source)
        #expect(rows.count == 1)
        let result = ScheduleExtractionGuard.validate(rows, source: source, context: guardContext())
        #expect(result.issues.contains { $0.contains("부가 정보의 귀속") && $0.contains("장소:") })
        #expect(result.issues.contains { $0.contains("부가 정보의 귀속") && $0.contains("준비물:") })
        #expect(result.drafts.first?.notes.contains("가상 회의실") == false)
    }

    @Test func aDescriptiveCaptureHeaderDoesNotRequireAnActivityOwner() {
        let source = "합성 대화 캡처\n내일 오전 9시 회의"
        let rows = ScheduleExtractionGuard.groundSources(["내일 오전 9시 회의"], source: source)
        let result = ScheduleExtractionGuard.validate(rows, source: source, context: guardContext())
        #expect(result.issues.isEmpty)
    }

    @Test func diagnosticChecksDistinguishRejectionFromUnevaluatedFields() {
        let source = "9시 산책"
        let result = ScheduleExtractionGuard.validate(
            [candidate(source, action: "산책", time: "9시", location: "없는 장소")],
            source: source, context: guardContext())
        #expect(!result.issues.isEmpty)
        #expect(result.drafts.isEmpty)
        #expect(result.checks.contains { $0.field == "sourceText" && $0.status == "accepted" })
        #expect(result.checks.contains { $0.field == "locationText" && $0.status == "rejected" })
        #expect(result.checks.contains { $0.field == "titleParts" && $0.status == "not-evaluated" })
    }

    @Test(arguments: [["런닝갈거야"], ["런닝", "갈거야"], ["런닝"]])
    func conversationalEndingMayBeIncludedOrOmittedInTitleParts(parts: [String]) throws {
        #expect(try ScheduleTitleNormalizer.normalize(action: "런닝갈거야", parts: parts) == "런닝")
    }

    @Test func normalizerPreservesSourceAdjacency() throws {
        #expect(
            try ScheduleTitleNormalizer.normalize(action: "가상동에서", parts: ["가상동", "에서"]) == "가상동에서")
        #expect(
            try ScheduleTitleNormalizer.normalize(action: "온라인 줌 미팅", parts: ["온라인", "줌", "미팅"])
                == "온라인 줌 미팅")
        #expect(
            try ScheduleTitleNormalizer.normalize(action: "아리랑 공연", parts: ["아리", "랑", "공연"])
                == "아리랑 공연")
    }

    @Test func modelWhitespaceDoesNotReplaceTheActualSourceBoundaries() {
        let source = "가상동에서 온라인 미팅"
        let result = ScheduleExtractionGuard.validate(
            [
                candidate(source, action: "가상동 에서 온 라인 미팅", titleParts: ["가상동", "에서", "온라인", "미팅"])
            ], source: source, context: guardContext())
        #expect(result.issues.isEmpty)
        #expect(result.drafts.first?.title == source)
    }

    @Test func spacedModelEvidenceCannotHideAnActionConnector() {
        let source = "회의하고 점심"
        let result = ScheduleExtractionGuard.validate(
            [
                candidate(source, action: "회의하 고 점심", titleParts: [source])
            ], source: source, context: guardContext())
        #expect(!result.issues.isEmpty)
    }

    @Test func conversationalEndingAndLocationAreNormalizedByAppCode() {
        let source = "12시에 민수랑 점심 약속 있어 가상동에서"
        let action = "민수랑 점심 약속 있어 가상동에서"
        let result = ScheduleExtractionGuard.validate(
            [
                candidate(
                    source, action: action, time: "12시",
                    titleParts: ["민수", "점심 약속", "있어", "가상동", "에서"], location: "가상동")
            ], source: source, context: guardContext())
        #expect(result.issues.isEmpty)
        #expect(result.drafts.first?.title == "민수 점심 약속")
        #expect(result.drafts.first?.timeText == "12:00")
        #expect(result.drafts.first?.notes.contains("장소: 가상동") == true)
        #expect(result.drafts.first?.notes.contains(source) == true)
    }

    @Test func omittedEndingAndLocationDoNotConflictWithEvidenceGuard() {
        let source = "민수랑 점심 약속 있어 가상동에서"
        let result = ScheduleExtractionGuard.validate(
            [
                candidate(source, action: source, titleParts: ["민수", "점심 약속"], location: "가상동")
            ], source: source, context: guardContext())
        #expect(result.issues.isEmpty)
        #expect(result.drafts.first?.title == "민수 점심 약속")
    }

    @Test func locationOutsideTheActionPhraseStillSurvivesInNotes() {
        let source = "민수랑 점심 약속 있어 가상동에서"
        let result = ScheduleExtractionGuard.validate(
            [
                candidate(
                    source, action: "민수랑 점심 약속", titleParts: ["민수", "점심 약속"], location: "가상동")
            ], source: source, context: guardContext())
        #expect(result.issues.isEmpty)
        #expect(result.drafts.first?.title == "민수 점심 약속")
        #expect(result.drafts.first?.notes.contains("장소: 가상동") == true)
    }

    @Test func repairRetainsLocationEvidenceUntilNotesAreBuilt() throws {
        let source = "민수랑 점심 약속 있어 가상동에서"
        let rows = try ScheduleExtractionGuard.groundActions(
            [
                GroundedAction(
                    actionText: source, titleParts: ["민수", "점심 약속"], locationText: "가상동")
            ], source: source)
        let result = ScheduleExtractionGuard.validate(rows, source: source, context: guardContext())
        #expect(result.issues.isEmpty)
        #expect(result.drafts.first?.title == "민수 점심 약속")
        #expect(result.drafts.first?.notes.contains("장소: 가상동") == true)
    }

    @Test(arguments: ["민수 점심 약속 있어", "민수 점심 약속 있어요", "민수 점심 약속 있습니다", "민수 점심 약속 있어!"])
    func commonConversationalEndingsAreRemoved(action: String) throws {
        #expect(
            try ScheduleTitleNormalizer.normalize(action: action, parts: [action]) == "민수 점심 약속")
    }

    @Test(arguments: [
        "회의 안 있어", "회의안갈거야", "회의못갈거야", "집에 갈거야", "찾아갈거야", "노래 '갈거야' 듣기", "회의 취소하지 않기",
    ])
    func predicatesWithProtectedMeaningArePreserved(action: String) throws {
        #expect(try ScheduleTitleNormalizer.normalize(action: action, parts: [action]) == action)
    }

    @Test func cancellationAndNegationCannotBeOmittedToCleanTheTitle() throws {
        for (action, parts) in [
            ("회의 취소 있어", ["회의"]), ("회의 안 있어", ["회의", "있어"]), ("온라인 줌 미팅 있어", ["온라인", "미팅"]),
        ] {
            #expect(throws: (any Error).self) {
                try ScheduleTitleNormalizer.normalize(action: action, parts: parts)
            }
        }
        #expect(
            try ScheduleTitleNormalizer.normalize(action: "회의 취소 있어", parts: ["회의", "취소", "있어"])
                == "회의 취소")
    }

    @Test(arguments: [
        ("가상역에서 회의", "가상"), ("온라인 줌 미팅", "온라인"), ("다른동 회의", "가상동"), ("가상동 회의 가상동", "가상동"),
    ])
    func absentAmbiguousOrNonVenueLocationIsRejected(source: String, location: String) {
        let result = ScheduleExtractionGuard.validate(
            [
                candidate(source, action: source, titleParts: [source], location: location)
            ], source: source, context: guardContext())
        #expect(!result.issues.isEmpty)
    }

    @Test func aVenueAndExistencePhraseCannotBecomeATitle() {
        #expect(throws: (any Error).self) {
            try ScheduleTitleNormalizer.normalize(
                action: "가상동 있어", parts: ["가상동", "있어"], location: "가상동")
        }
    }

    @Test func aLocationCannotBecomeAnActivityTitleByItself() {
        #expect(throws: (any Error).self) {
            try ScheduleTitleNormalizer.normalize(action: "가상동에서", parts: ["가상동"], location: "가상동")
        }
    }

    @Test func titleFragmentsRemoveOnlyTheLocatedParticle() {
        let source = "12시에 민수랑 점심"
        let result = ScheduleExtractionGuard.validate(
            [
                candidate(source, action: "민수랑 점심", time: "12시", titleParts: ["민수", "점심"])
            ], source: source, context: guardContext())
        #expect(result.issues.isEmpty)
        #expect(result.drafts.first?.title == "민수 점심")
        #expect(result.drafts.first?.timeText == "12:00")
        #expect(result.drafts.first?.notes.contains("민수랑 점심") == true)
    }

    @Test(arguments: ["온라인 줌 미팅", "아리랑 공연", "디자인 및 개발 회의", "친구와 저녁 식사"])
    func completeTitlePhraseKeepsAllItsWords(action: String) throws {
        #expect(
            try ScheduleTitleNormalizer.normalize(action: action, parts: [action]) == action)
    }

    @Test func titleCannotDropAPersonModeOrNegation() {
        for (action, parts) in [
            ("민수랑 점심", ["점심"]), ("온라인 줌 미팅", ["온라인", "미팅"]), ("회의 취소", ["회의"]),
            ("회의 말고 점심", ["회의", "점심"]),
        ] {
            let result = ScheduleExtractionGuard.validate(
                [
                    candidate(action, action: action, titleParts: parts)
                ], source: action, context: guardContext())
            #expect(!result.issues.isEmpty)
        }
    }

    @Test func titleFragmentsCannotHideMergedActivities() {
        let source = "회의하고 점심"
        let result = ScheduleExtractionGuard.validate(
            [
                candidate(source, action: source, titleParts: ["회의", "점심"])
            ], source: source, context: guardContext())
        #expect(!result.issues.isEmpty)
    }

    @Test func titleFragmentsKeepCompoundConjunctions() {
        let action = "디자인 및 개발 회의"
        #expect(throws: (any Error).self) {
            try ScheduleTitleNormalizer.normalize(action: action, parts: ["디자인", "개발 회의"])
        }
    }

    @Test func titleCannotInventOrReorderWords() {
        for parts in [["점심", "민수"], ["민수", "저녁"], ["민수", ""]] {
            #expect(throws: (any Error).self) {
                try ScheduleTitleNormalizer.normalize(action: "민수랑 점심", parts: parts)
            }
        }
    }

    @Test func missingTitlePartsKeepSourcePhrase() throws {
        #expect(
            try ScheduleTitleNormalizer.normalize(action: "민수랑 점심", parts: []) == "민수랑 점심")
    }

    @Test func repairKeepsTitleFragmentsAndVagueTimeWithTheFollowingActivity() throws {
        let source = "9시에 산책갈거야 그리고 12시에 민수랑 점심 일정있고 저녁에 개발 동아리 회식 있어"
        let activities = [
            GroundedAction(actionText: "산책", titleParts: ["산책"]),
            GroundedAction(actionText: "민수랑 점심", titleParts: ["민수", "점심"]),
            GroundedAction(actionText: "개발 동아리 회식", titleParts: ["개발 동아리 회식"]),
        ]
        let candidates = try ScheduleExtractionGuard.groundActions(activities, source: source)
        let result = ScheduleExtractionGuard.validate(
            candidates, source: source, context: guardContext())
        #expect(result.issues.isEmpty)
        #expect(result.drafts.map(\.title) == ["산책", "민수 점심", "개발 동아리 회식"])
        #expect(result.drafts.map(\.timeText) == ["09:00", "12:00", ""])
        #expect(candidates[2].sourceText.hasPrefix("저녁에"))
        #expect(!candidates[1].sourceText.contains("저녁에"))
    }

    @Test func precedingQuoteCannotKeepTheNextActionsTimeOfDay() {
        let source = "12시에 민수랑 점심 일정있고 저녁에 동아리 회식 있어"
        let result = ScheduleExtractionGuard.validate(
            [
                candidate("12시에 민수랑 점심 일정있고 저녁에", action: "민수랑 점심", time: "12시"),
                candidate("동아리 회식 있어", action: "동아리 회식"),
            ], source: source, context: guardContext())
        #expect(result.issues.contains { $0.contains("시간대") })
    }

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

private actor DiagnosticRecorder {
    var events: [ScheduleAnalysisDiagnostic] = []
    func append(_ event: ScheduleAnalysisDiagnostic) { events.append(event) }
}

struct ExtractionRetryTests {
    @Test(arguments: [
        "내일 오후 3시로부터 2시간 후에 회의", "내일 오후 3시보다 2시간 전에 회의",
        "2시간 후에 운동", "30분 뒤에 회의", "1시간 30분 후에 점검",
        "내일 오후 3시(2시간 후)에 회의",
    ])
    func relativeStartTimeRequiresConfirmationWithoutRetry(source: String) async {
        let model = ScriptedModel([ScheduleExtractionGuard.groundSources([source], source: source)])
        do {
            _ = try await ScheduleAnalyzer(model: model).analyze(
                text: source, context: guardContext())
            Issue.record("상대 시각의 기준 시각이 실제 시작 시각으로 반환됨")
        } catch {
            guard case AnalysisFailure.timeNeedsConfirmation(let message) = error else {
                Issue.record("시각 확인 필요 오류와 다른 오류가 반환됨: \(error)")
                return
            }
            #expect(message.contains("상대 시작 시각"))
        }
        #expect(await model.calls == 1)
    }

    @Test func multipleValidStartClocksAreHeldWithoutModelRetry() async {
        let source = "내일 오전 9시 또는 오전 10시에 회의"
        let model = ScriptedModel([ScheduleExtractionGuard.groundSources([source], source: source)])
        do {
            _ = try await ScheduleAnalyzer(model: model).analyze(
                text: source, context: guardContext())
            Issue.record("복수 시작 시각이 정상 초안으로 반환됨")
        } catch {
            guard case AnalysisFailure.timeNeedsConfirmation(let message) = error else {
                Issue.record("시각 확인 필요 오류와 다른 오류가 반환됨: \(error)")
                return
            }
            #expect(message.contains("시작 시각 후보가 여러 개"))
        }
        #expect(await model.calls == 1)
    }

    @Test(arguments: [
        "내일 밤 1시에 서버 점검", "내일 저녁 7시에 식사", "모레 아침 9시에 산책",
        "내일 밤 12시 30분에 백업", "내일 25시에 회의", "내일 9시 60분에 점검",
        "내일 오후 13시에 회의", "내일 밤 1시부터 3시까지 회의",
        "내일 9시 또는 밤 1시에 회의",
    ])
    func unparseableStartIsHeldWithoutModelRetry(source: String) async {
        let model = ScriptedModel([ScheduleExtractionGuard.groundSources([source], source: source)])
        do {
            _ = try await ScheduleAnalyzer(model: model).analyze(
                text: source, context: guardContext())
            Issue.record("해석할 수 없는 시작 시각이 정상 초안으로 반환됨")
        } catch {
            guard case AnalysisFailure.timeNeedsConfirmation = error else {
                Issue.record("시각 확인 필요 오류와 다른 오류가 반환됨: \(error)")
                return
            }
        }
        #expect(await model.calls == 1)
    }

    @Test func unparseableClockInOneOfSeveralSchedulesHoldsAllDrafts() async {
        let source = "내일 9시 회의하고 밤 1시에 서버 점검"
        let rows = ScheduleExtractionGuard.groundSources(
            ["내일 9시 회의", "밤 1시에 서버 점검"], source: source)
        let model = ScriptedModel([rows])
        do {
            _ = try await ScheduleAnalyzer(model: model).analyze(
                text: source, context: guardContext())
            Issue.record("시각 확인이 필요한 일정이 포함된 결과가 반환됨")
        } catch {
            guard case AnalysisFailure.timeNeedsConfirmation(let message) = error else {
                Issue.record("시각 확인 필요 오류와 다른 오류가 반환됨: \(error)")
                return
            }
            #expect(message.contains("밤 1시"))
        }
        #expect(await model.calls == 1)
    }

    @Test(arguments: [
        ("내일 회의", ""), ("내일 저녁에 회의", ""),
        ("내일 오전 9시에 회의", "09:00"), ("내일 밤 12시에 서버 점검", "00:00"),
        ("내일 오후 1시부터 밤 3시까지 회의", "13:00"),
        ("내일 오후 3시에 2시간 회의", "15:00"), ("내일 2시간 운동 후 휴식", ""),
        ("내일 18시까지 자료 제출", ""), ("내일 11시부터 1시까지 회의", "11:00"),
        ("내일 오전 9시에 회의\n메시지 발송 시각: 13:08", "09:00"),
    ])
    func validOrEndOnlyTimeDoesNotTriggerConfirmation(source: String, expected: String) async throws
    {
        let model = ScriptedModel([ScheduleExtractionGuard.groundSources([source], source: source)])
        let drafts = try await ScheduleAnalyzer(model: model).analyze(
            text: source, context: guardContext())
        #expect(drafts.count == 1)
        #expect(drafts.first?.timeText == expected)
        #expect(await model.calls == 1)
    }

    @Test func optInDiagnosticsPreserveTheSingleRepairBoundary() async throws {
        let model = ScriptedModel([
            [candidate("내일 회의", action: "런닝")],
            [candidate("내일 회의", action: "회의", date: "내일")],
        ])
        let recorder = DiagnosticRecorder()
        let result = try await ScheduleAnalyzer(
            model: model, observer: { await recorder.append($0) }
        )
        .analyze(text: "내일 회의", context: guardContext())
        #expect(result.first?.title == "회의")
        #expect(await model.calls == 2)
        let events = await recorder.events
        #expect(events.filter { $0.stage == "guard" }.map(\.attempt) == [1, 2])
        let first = try #require(events.first { $0.stage == "guard" })
        let checks = try JSONDecoder().decode(
            [ScheduleGuardCheck].self, from: Data(first.payload.utf8))
        #expect(checks.contains { $0.field == "actionText" && $0.status == "rejected" })
        #expect(events.allSatisfy { $0.elapsedSeconds >= 0 })
    }

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
    @Test func titleLossTriggersTheExistingSingleRepair() async throws {
        let source = "12시에 민수랑 점심"
        let model = ScriptedModel([
            [candidate(source, action: "민수랑 점심", time: "12시", titleParts: ["점심"])],
            [candidate(source, action: "민수랑 점심", time: "12시", titleParts: ["민수", "점심"])],
        ])
        let result = try await ScheduleAnalyzer(model: model).analyze(
            text: source, context: guardContext())
        #expect(result.first?.title == "민수 점심")
        #expect(result.first?.timeText == "12:00")
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

struct GeminiScheduleModelTests {
    @Test func parsesStructuredResponseAndPreservesGuard() async throws {
        let model = GeminiScheduleModel(
            apiKey: "test-key",
            transport: { request in
                #expect(request.value(forHTTPHeaderField: "x-goog-api-key") == "test-key")
                #expect(request.url?.path.contains("gemini-3.5-flash-lite") == true)
                let response = HTTPURLResponse(
                    url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                let body =
                    #"{"candidates":[{"finishReason":"STOP","content":{"parts":[{"text":"{\"schedules\":[{\"sourceText\":\"내일 9시 회의\"}]}"}]}}]}"#
                return (Data(body.utf8), response)
            })
        let drafts = try await ScheduleAnalyzer(model: model).analyze(
            text: "내일 9시 회의", context: guardContext())
        #expect(drafts.count == 1)
        #expect(drafts[0].timeText == "09:00")
    }

    @Test func rejectsHttpErrorsWithoutExposingResponse() async throws {
        let model = GeminiScheduleModel(
            apiKey: "test-key",
            transport: { request in
                (
                    Data("secret".utf8),
                    HTTPURLResponse(
                        url: request.url!, statusCode: 429, httpVersion: nil, headerFields: nil)!
                )
            })
        do {
            _ = try await model.extract(text: "회의", context: guardContext(), feedback: [])
            Issue.record("HTTP error should fail")
        } catch {
            #expect(error.localizedDescription.contains("429"))
            #expect(!error.localizedDescription.contains("secret"))
        }
    }

    @Test func rejectsMissingKeyAndIncompleteResponse() async throws {
        let missing = GeminiScheduleModel(apiKey: "")
        await #expect(throws: AnalysisFailure.self) {
            try await missing.extract(text: "회의", context: guardContext(), feedback: [])
        }
        let incomplete = GeminiScheduleModel(
            apiKey: "test-key",
            transport: { request in
                let response = HTTPURLResponse(
                    url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (
                    Data(
                        #"{"candidates":[{"finishReason":"MAX_TOKENS","content":{"parts":[{"text":"{}"}]}}]}"#
                            .utf8), response
                )
            })
        await #expect(throws: AnalysisFailure.self) {
            try await incomplete.extract(text: "회의", context: guardContext(), feedback: [])
        }
    }
}
