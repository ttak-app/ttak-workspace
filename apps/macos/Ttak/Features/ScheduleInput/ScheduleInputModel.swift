import Foundation
import Observation

struct SaveOutcome: Identifiable, Equatable {
    enum Status: Equatable { case saved, notAttempted, unknown }
    let id: UUID
    let title: String
    let status: Status
    let message: String
}

@MainActor
@Observable
final class ScheduleInputModel {
    var input = ""
    private(set) var imageData: Data?
    private(set) var imageName = ""
    var drafts: [ScheduleDraft] = []
    private(set) var lists: [ReminderList] = []
    private(set) var message = ""
    private(set) var modelDescription: String
    private(set) var accessDescription: String
    private(set) var isAnalyzing = false
    private(set) var isLoadingLists = false
    private(set) var isSaving = false
    private(set) var saveOutcomes: [SaveOutcome] = []
    private(set) var hasAttemptedSave = false
    private(set) var analysisCalendar = Calendar.current
    private let analyzer: any ScheduleAnalyzing
    private let recognizer: any ImageTextRecognizing
    private let reminderStore: any ReminderStoring
    private var analysisTask: Task<Void, Never>?
    private var requestID: UUID?

    init(
        analyzer: any ScheduleAnalyzing = ScheduleAnalyzer(),
        recognizer: any ImageTextRecognizing = ImageTextRecognizer(),
        reminderStore: any ReminderStoring = ReminderStore()
    ) {
        self.analyzer = analyzer
        self.recognizer = recognizer
        self.reminderStore = reminderStore
        modelDescription = analyzer.availabilityDescription()
        accessDescription = reminderStore.accessDescription
    }

    var isBusy: Bool { isAnalyzing || isLoadingLists || isSaving }
    var canAnalyze: Bool {
        !isBusy && !hasAttemptedSave
            && (imageData != nil || !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
    var includedDrafts: [ScheduleDraft] { drafts.filter { !$0.isExcluded } }
    var canSave: Bool {
        !isBusy && !hasAttemptedSave && !includedDrafts.isEmpty
            && includedDrafts.allSatisfy {
                $0.validationMessage(lists: lists, calendar: analysisCalendar) == nil
            }
    }

    func refreshAvailability() {
        modelDescription = analyzer.availabilityDescription()
        accessDescription = reminderStore.accessDescription
    }

    func attachImage(_ data: Data, name: String) {
        guard !isBusy && !hasAttemptedSave else { return }
        imageData = data
        imageName = name
        drafts = []
        message = "이미지를 첨부했어요. 분석 후 등록 내용을 확인하세요."
    }

    func removeImage() {
        guard !isBusy && !hasAttemptedSave else { return }
        imageData = nil
        imageName = ""
        drafts = []
        message = ""
    }

    func inputDidChange() {
        // Validation UI only: new input invalidates previews. Persistence policy remains undecided.
        guard !isBusy && !hasAttemptedSave else { return }
        drafts = []
        message = ""
    }

    func loadLists() async {
        guard !isBusy else { return }
        isLoadingLists = true
        defer {
            isLoadingLists = false
            accessDescription = reminderStore.accessDescription
        }
        do {
            lists = try await reminderStore.requestAccess()
            message =
                lists.isEmpty ? "쓰기 가능한 미리 알림 목록이 없어요." : "기존 목록을 불러왔어요. 저장할 테스트 목록을 직접 선택하세요."
        } catch {
            lists = []
            message = error.localizedDescription
        }
    }

    func startAnalysis(now: Date = Date(), calendar: Calendar = .current) {
        guard canAnalyze else { return }
        let id = UUID()
        requestID = id
        let text = input
        let attachment = imageData
        let context = AnalysisContext(
            referenceDate: now, calendar: calendar, lists: lists,
            userGuidance: attachment == nil ? "" : text)
        analysisCalendar = calendar
        drafts = []
        saveOutcomes = []
        message = ""
        isAnalyzing = true
        refreshAvailability()
        analysisTask = Task {
            do {
                var source = text
                if let attachment {
                    do {
                        let recognized = try await recognizer.recognize(data: attachment)
                        source = recognized
                    } catch is CancellationError {
                        throw CancellationError()
                    } catch {
                        guard requestID == id else { return }
                        message = "이미지 인식 실패: \(error.localizedDescription)"
                        isAnalyzing = false
                        return
                    }
                }
                let result = try await analyzer.analyze(text: source, context: context)
                try Task.checkCancellation()
                guard requestID == id else { return }
                guard !result.isEmpty else { throw AnalysisFailure.emptyResult }
                drafts = result
                message = "아직 저장하지 않았어요. 제목과 날짜, 시각, 테스트 목록을 확인하세요."
            } catch is CancellationError {
                if requestID == id { message = "분석을 취소했어요. 입력은 유지돼요." }
            } catch {
                if requestID == id { message = "분석 실패: \(error.localizedDescription)" }
            }
            if requestID == id {
                isAnalyzing = false
                analysisTask = nil
            }
        }
    }

    func cancelAnalysis() {
        analysisTask?.cancel()
        analysisTask = nil
        requestID = nil
        isAnalyzing = false
        message = "분석을 취소했어요. 입력은 유지돼요."
    }

    func waitForAnalysis() async {
        await analysisTask?.value
    }

    func cancelPreview() {
        guard !isBusy else { return }
        drafts = []
        if !hasAttemptedSave { message = "결과를 취소했어요. 입력은 유지돼요." }
    }

    func saveConfirmedDrafts() {
        guard canSave else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            lists = try reminderStore.writableLists()
            guard
                includedDrafts.allSatisfy({
                    $0.validationMessage(lists: lists, calendar: analysisCalendar) == nil
                })
            else {
                message = "목록 또는 권한이 변경됐어요. 저장하지 않았으니 다시 확인하세요."
                return
            }
        } catch {
            message = "저장 전 확인 실패: \(error.localizedDescription)"
            return
        }
        hasAttemptedSave = true
        let selected = includedDrafts
        for draft in selected {
            do {
                _ = try reminderStore.save(draft, calendar: analysisCalendar)
                saveOutcomes.append(
                    SaveOutcome(id: draft.id, title: draft.title, status: .saved, message: "저장 확인됨")
                )
            } catch {
                // A thrown external write is not proof that nothing persisted. Do not retry automatically.
                saveOutcomes.append(
                    SaveOutcome(
                        id: draft.id, title: draft.title, status: .unknown,
                        message: error.localizedDescription))
                let remaining = selected.dropFirst(saveOutcomes.count)
                saveOutcomes += remaining.map {
                    SaveOutcome(
                        id: $0.id, title: $0.title, status: .notAttempted,
                        message: "앞선 저장 오류로 실행하지 않음")
                }
                message = "일부 저장 결과를 확인하지 못했어요. 미리 알림 앱에서 확인하세요. 중복 방지를 위해 이 입력의 재등록은 차단했어요."
                return
            }
        }
        input = ""
        imageData = nil
        imageName = ""
        drafts = []
        hasAttemptedSave = false
        message = "\(saveOutcomes.count)개 등록 완료"
    }

    func beginNewInputAfterCheckingReminders() {
        guard !isBusy else { return }
        input = ""
        imageData = nil
        imageName = ""
        drafts = []
        saveOutcomes = []
        hasAttemptedSave = false
        message = "새 입력을 시작하세요. 이전 결과는 미리 알림 앱에서 확인해야 해요."
    }
}
