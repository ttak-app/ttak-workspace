import Foundation
import Observation

/// Owns the input and temporary results for a service-independent schedule flow.
@MainActor
@Observable
final class ScheduleFlowModel {
    enum Phase: Equatable {
        case input
        case analyzing
        case reviewing
        case empty
        case failure(String)
    }

    struct Input: Sendable {
        let text: String
        let imageData: Data?
        let imageName: String?
    }

    typealias Analyze = @MainActor (Input) async throws -> [ScheduleDraft]
    typealias Register = @MainActor ([ScheduleDraft]) -> Void

    var text = ""
    var attachment: ImageAttachment?
    var drafts: [ScheduleDraft] = []
    private(set) var phase: Phase = .input
    let lists: [ReminderList]
    let calendar: Calendar

    private let analyze: Analyze
    private let register: Register
    private var analysisTask: Task<Void, Never>?
    private var requestID: UUID?
    private var isRegistering = false

    init(
        lists: [ReminderList], calendar: Calendar = .current,
        analyze: @escaping Analyze, register: @escaping Register
    ) {
        self.lists = lists
        self.calendar = calendar
        self.analyze = analyze
        self.register = register
    }

    isolated deinit {
        analysisTask?.cancel()
    }

    var canAnalyze: Bool {
        switch phase {
        case .input, .empty, .failure:
            return attachment != nil
                || !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .analyzing, .reviewing:
            return false
        }
    }

    func startAnalysis() {
        guard canAnalyze else { return }
        let input = Input(text: text, imageData: attachment?.data, imageName: attachment?.name)
        let id = UUID()
        requestID = id
        drafts = []
        phase = .analyzing
        let analyze = self.analyze
        analysisTask = Task { [weak self] in
            do {
                let result = try await analyze(input)
                guard !Task.isCancelled, let self, self.requestID == id, self.phase == .analyzing
                else { return }
                self.analysisTask = nil
                self.requestID = nil
                self.drafts = result
                self.phase = result.isEmpty ? .empty : .reviewing
            } catch {
                guard !Task.isCancelled, let self, self.requestID == id, self.phase == .analyzing
                else { return }
                self.analysisTask = nil
                self.requestID = nil
                self.phase = .failure(error.localizedDescription)
            }
        }
    }

    func cancelAnalysis() {
        requestID = nil
        analysisTask?.cancel()
        analysisTask = nil
        if phase == .analyzing { phase = .input }
    }

    func cancelReview() {
        guard phase == .reviewing else { return }
        drafts = []
        phase = .input
    }

    func registerDrafts() {
        guard phase == .reviewing, !isRegistering else { return }
        let included = drafts.filter { !$0.isExcluded }
        guard !included.isEmpty,
            included.allSatisfy({ $0.validationMessage(lists: lists, calendar: calendar) == nil })
        else { return }
        isRegistering = true
        defer { isRegistering = false }
        register(included)
    }
}
