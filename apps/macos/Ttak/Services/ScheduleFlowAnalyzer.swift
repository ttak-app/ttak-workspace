import Foundation

/// Adapts the Gemini analyzer to the analysis closure injected into `ScheduleFlowModel`.
struct ScheduleFlowAnalyzer: Sendable {
    var analyzer: any ScheduleAnalyzing = ScheduleAnalyzer()
    var lists: [ReminderList]
    var timeout: Duration = .seconds(30)

    func analyze(_ input: ScheduleFlowModel.Input) async throws -> [ScheduleDraft] {
        // OCR is not connected yet, so image-only input is treated as no schedule without a request.
        // Remove this guard when image analysis is connected.
        let text = input.text
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        let context = AnalysisContext(referenceDate: Date(), calendar: .current, lists: lists)
        do {
            return try await withTimeout { [analyzer] in
                try await analyzer.analyze(text: text, context: context)
            }
        } catch AnalysisFailure.emptyResult {
            return []
        } catch let failure as AnalysisFailure {
            throw failure
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            // Unclassified errors such as decoding failures would otherwise expose system messages.
            throw AnalysisFailure.invalidResponse
        }
    }

    private func withTimeout(
        _ operation: @escaping @Sendable () async throws -> [ScheduleDraft]
    ) async throws -> [ScheduleDraft] {
        let timeout = self.timeout
        return try await withThrowingTaskGroup(of: [ScheduleDraft].self) { group in
            defer { group.cancelAll() }
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(for: timeout)
                throw AnalysisFailure.timedOut
            }
            guard let first = try await group.next() else { throw CancellationError() }
            return first
        }
    }
}
