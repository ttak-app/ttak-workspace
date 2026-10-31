import Foundation
import Testing

@testable import Ttak

private actor AnalyzerProbe {
    private(set) var texts: [String] = []
    private(set) var contextLists: [[ReminderList]] = []

    func record(text: String, lists: [ReminderList]) {
        texts.append(text)
        contextLists.append(lists)
    }
}

private struct StubAnalyzer: ScheduleAnalyzing {
    enum Behavior: Sendable {
        case drafts([ScheduleDraft])
        case failure(AnalysisFailure)
        case unclassified
        case hangs
    }

    let behavior: Behavior
    let probe = AnalyzerProbe()

    func availabilityDescription() -> String { "stub" }

    func analyze(text: String, context: AnalysisContext) async throws -> [ScheduleDraft] {
        await probe.record(text: text, lists: context.lists)
        switch behavior {
        case .drafts(let drafts): return drafts
        case .failure(let failure): throw failure
        case .unclassified: throw URLError(.cannotParseResponse)
        case .hangs:
            try await Task.sleep(for: .seconds(60))
            return []
        }
    }
}

private struct UnclassifiedFailure: Error {}

private func makeInput(text: String, imageData: Data? = nil) -> ScheduleFlowModel.Input {
    ScheduleFlowModel.Input(text: text, imageData: imageData, imageName: nil)
}

private func makeContext() -> AnalysisContext {
    AnalysisContext(referenceDate: Date(), calendar: .current, lists: [])
}

private func makeResponse(
    _ request: URLRequest, status: Int, body: String
) -> (Data, URLResponse) {
    (
        Data(body.utf8),
        HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
    )
}

private func caughtFailure(_ operation: () async throws -> some Any) async -> (any Error)? {
    do {
        _ = try await operation()
        return nil
    } catch {
        return error
    }
}

struct ScheduleFlowAnalyzerTests {
    private let lists = [ReminderList(id: "work", title: "업무")]
    private let sampleDraft = ScheduleDraft(title: "런닝", dateText: "2026-10-31", timeText: "09:00")

    @Test("성공하면 초안을 반환하고 입력 텍스트와 목록을 분석기에 전달한다")
    func returnsDraftsAndPassesContext() async throws {
        let stub = StubAnalyzer(behavior: .drafts([sampleDraft]))
        let adapter = ScheduleFlowAnalyzer(analyzer: stub, lists: lists)
        let drafts = try await adapter.analyze(makeInput(text: "9시에 런닝, 11시에 점심"))
        #expect(drafts == [sampleDraft])
        #expect(await stub.probe.texts == ["9시에 런닝, 11시에 점심"])
        #expect(await stub.probe.contextLists == [lists])
    }

    @Test("일정 없음은 오류가 아니라 빈 결과로 바꾼다")
    func convertsEmptyResultToEmptyList() async throws {
        let stub = StubAnalyzer(behavior: .failure(.emptyResult))
        let adapter = ScheduleFlowAnalyzer(analyzer: stub, lists: lists)
        #expect(try await adapter.analyze(makeInput(text: "그냥 메모")).isEmpty)
    }

    @Test("텍스트가 없으면 이미지가 있어도 분석기를 호출하지 않는다")
    func skipsAnalyzerWithoutText() async throws {
        let stub = StubAnalyzer(behavior: .drafts([sampleDraft]))
        let adapter = ScheduleFlowAnalyzer(analyzer: stub, lists: lists)
        let drafts = try await adapter.analyze(
            makeInput(text: "  \n", imageData: Data([1, 2, 3])))
        #expect(drafts.isEmpty)
        #expect(await stub.probe.texts.isEmpty)
    }

    @Test("분류된 실패는 그대로 전달하고 분류되지 않은 오류는 응답 오류로 바꾼다")
    func keepsClassifiedFailuresAndMapsUnclassified() async {
        let classified = ScheduleFlowAnalyzer(
            analyzer: StubAnalyzer(behavior: .failure(.network)), lists: lists)
        let classifiedError = await caughtFailure {
            try await classified.analyze(makeInput(text: "회의"))
        }
        #expect(classifiedError?.localizedDescription == AnalysisFailure.network.errorDescription)

        let unclassified = ScheduleFlowAnalyzer(
            analyzer: StubAnalyzer(behavior: .unclassified), lists: lists)
        let unclassifiedError = await caughtFailure {
            try await unclassified.analyze(makeInput(text: "회의"))
        }
        #expect(
            unclassifiedError?.localizedDescription
                == AnalysisFailure.invalidResponse.errorDescription)
    }

    @Test("응답이 없으면 제한 시간 뒤 시간 초과로 실패한다")
    func timesOutWhenAnalyzerHangs() async {
        let adapter = ScheduleFlowAnalyzer(
            analyzer: StubAnalyzer(behavior: .hangs), lists: lists, timeout: .milliseconds(50))
        let error = await caughtFailure { try await adapter.analyze(makeInput(text: "회의")) }
        #expect(error?.localizedDescription == AnalysisFailure.timedOut.errorDescription)
    }

    @Test("바깥 task를 취소하면 취소 오류를 전달한다")
    func propagatesCancellation() async {
        let adapter = ScheduleFlowAnalyzer(
            analyzer: StubAnalyzer(behavior: .hangs), lists: lists, timeout: .seconds(30))
        let task = Task { try await adapter.analyze(makeInput(text: "회의")) }
        try? await Task.sleep(for: .milliseconds(50))
        task.cancel()
        let error = await caughtFailure { try await task.value }
        #expect(error is CancellationError)
    }

    @MainActor
    @Test("시간 초과 시 흐름 모델은 실패 안내로 바뀌고 입력을 유지한다")
    func flowModelShowsTimeoutAndKeepsInput() async {
        let adapter = ScheduleFlowAnalyzer(
            analyzer: StubAnalyzer(behavior: .hangs), lists: lists, timeout: .milliseconds(50))
        let model = ScheduleFlowModel(lists: lists, analyze: adapter.analyze, register: { _ in })
        model.text = "9시에 런닝"
        model.startAnalysis()
        #expect(model.phase == .analyzing)
        for _ in 0..<500 where model.phase == .analyzing {
            try? await Task.sleep(for: .milliseconds(10))
        }
        #expect(model.phase == .failure(AnalysisFailure.timedOut.errorDescription ?? ""))
        #expect(model.text == "9시에 런닝")
        #expect(model.canAnalyze)
    }
}

struct GeminiFailureClassificationTests {
    private func extractError(_ model: GeminiScheduleModel) async -> (any Error)? {
        await caughtFailure {
            try await model.extract(text: "회의", context: makeContext(), feedback: [])
        }
    }

    @Test("API 키가 없으면 키 미설정으로 분류한다")
    func classifiesMissingKey() async {
        let error = await extractError(GeminiScheduleModel(apiKey: " "))
        #expect(error?.localizedDescription == AnalysisFailure.missingAPIKey.errorDescription)
    }

    @Test("연결 실패는 네트워크 오류로 분류하고 취소는 취소로 둔다")
    func classifiesNetworkAndCancellation() async {
        let offline = GeminiScheduleModel(
            apiKey: "test-key", transport: { _ in throw URLError(.notConnectedToInternet) })
        #expect(
            await extractError(offline)?.localizedDescription
                == AnalysisFailure.network.errorDescription)
        let cancelled = GeminiScheduleModel(
            apiKey: "test-key", transport: { _ in throw URLError(.cancelled) })
        #expect(await extractError(cancelled) is CancellationError)
    }

    @Test("2xx가 아닌 응답은 상태 코드를 담은 서버 오류로 분류한다")
    func classifiesServerError() async {
        let model = GeminiScheduleModel(
            apiKey: "test-key",
            transport: { makeResponse($0, status: 500, body: "internal secret") })
        let message = await extractError(model)?.localizedDescription
        #expect(message == AnalysisFailure.server(500).errorDescription)
        #expect(message?.contains("secret") == false)
    }

    @Test("완료되지 않은 응답과 깨진 응답은 응답 오류로 분류한다")
    func classifiesInvalidResponses() async {
        let unfinished = GeminiScheduleModel(
            apiKey: "test-key",
            transport: {
                makeResponse(
                    $0, status: 200,
                    body:
                        #"{"candidates":[{"finishReason":"MAX_TOKENS","content":{"parts":[{"text":"{}"}]}}]}"#
                )
            })
        #expect(
            await extractError(unfinished)?.localizedDescription
                == AnalysisFailure.invalidResponse.errorDescription)
        let broken = GeminiScheduleModel(
            apiKey: "test-key", transport: { makeResponse($0, status: 200, body: "not json") })
        #expect(
            await extractError(broken)?.localizedDescription
                == AnalysisFailure.invalidResponse.errorDescription)
    }
}
