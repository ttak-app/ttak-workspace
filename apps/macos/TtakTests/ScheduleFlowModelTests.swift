import AppKit
import Testing

@testable import Ttak

@MainActor
private final class FlowAnalysisStub {
    var inputs: [ScheduleFlowModel.Input] = []
    var pending: [CheckedContinuation<[ScheduleDraft], any Error>] = []

    func analyze(_ input: ScheduleFlowModel.Input) async throws -> [ScheduleDraft] {
        inputs.append(input)
        return try await withCheckedThrowingContinuation { pending.append($0) }
    }
}

@MainActor
private final class AnalysisProbe {
    var isStarted = false
    var isCancelled = false
}

@MainActor
struct ScheduleFlowModelTests {
    private let lists = [ReminderList(id: "work", title: "업무")]

    private func draft(_ title: String = "회의") -> ScheduleDraft {
        ScheduleDraft(title: title, dateText: "2026-10-31", listID: "work")
    }

    private func waitUntil(_ predicate: () -> Bool) async {
        for _ in 0..<1000 {
            if predicate() { return }
            await Task.yield()
        }
        Issue.record("비동기 상태 전이가 완료되지 않았습니다.")
    }

    @Test("중복 요청은 무시하고 취소한 이전 응답은 새로운 결과를 덮어쓰지 않는다")
    func cancelledResponseCannotReplaceNewResult() async {
        let stub = FlowAnalysisStub()
        let model = ScheduleFlowModel(lists: lists, analyze: stub.analyze, register: { _ in })
        model.text = "첫 입력"
        model.startAnalysis()
        model.startAnalysis()
        await waitUntil { stub.pending.count == 1 }
        #expect(stub.inputs.count == 1)
        #expect(model.phase == .analyzing)
        model.cancelAnalysis()
        model.text = "두 번째 입력"
        model.startAnalysis()
        await waitUntil { stub.pending.count == 2 }
        stub.pending[1].resume(returning: [draft("새 결과")])
        await waitUntil { model.phase == .reviewing }
        stub.pending[0].resume(returning: [draft("이전 결과")])
        for _ in 0..<10 { await Task.yield() }
        #expect(model.drafts.map(\.title) == ["새 결과"])
        #expect(stub.inputs.map(\.text) == ["첫 입력", "두 번째 입력"])
    }

    @Test("빈 결과와 오류는 구분하며 재시도할 수 있다")
    func emptyFailureAndRetry() async {
        enum SampleError: LocalizedError {
            case failed
            var errorDescription: String? { "샘플 실패" }
        }
        let stub = FlowAnalysisStub()
        let model = ScheduleFlowModel(lists: lists, analyze: stub.analyze, register: { _ in })
        model.text = "일정"
        model.startAnalysis()
        await waitUntil { stub.pending.count == 1 }
        stub.pending[0].resume(returning: [])
        await waitUntil { model.phase == .empty }
        #expect(model.text == "일정")
        #expect(model.canAnalyze)
        model.startAnalysis()
        await waitUntil { stub.pending.count == 2 }
        stub.pending[1].resume(throwing: SampleError.failed)
        await waitUntil { model.phase == .failure("샘플 실패") }
        #expect(model.text == "일정")
        model.startAnalysis()
        await waitUntil { stub.pending.count == 3 }
        stub.pending[2].resume(returning: [draft()])
        await waitUntil { model.phase == .reviewing }
        #expect(model.drafts.count == 1)
    }

    @Test("이미지와 원문은 취소 후 유지하고 유효한 편집 결과만 전달한다")
    func imagePreservationAndRegistration() async throws {
        let bitmap = try #require(
            NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: 1, pixelsHigh: 1, bitsPerSample: 8,
                samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        let data = try #require(bitmap.representation(using: .png, properties: [:]))
        let attachment = try #require(ImageAttachment(data: data, name: "sample.png"))
        let stub = FlowAnalysisStub()
        var registered: [[ScheduleDraft]] = []
        let model = ScheduleFlowModel(lists: lists, analyze: stub.analyze) { registered.append($0) }
        model.text = "원래 입력"
        model.attachment = attachment
        model.startAnalysis()
        await waitUntil { stub.pending.count == 1 }
        #expect(stub.inputs[0].imageData == data)
        stub.pending[0].resume(returning: [draft(), draft("제외")])
        await waitUntil { model.phase == .reviewing }
        model.drafts[0].title = "수정한 회의"
        model.drafts[1].isExcluded = true
        model.registerDrafts()
        #expect(registered.count == 1)
        #expect(registered[0].map(\.title) == ["수정한 회의"])
        model.drafts[0].listID = nil
        model.registerDrafts()
        #expect(registered.count == 1)
        model.cancelReview()
        #expect(model.phase == .input)
        #expect(model.text == "원래 입력")
        #expect(model.attachment == attachment)
        #expect(model.drafts.isEmpty)
    }

    @Test("모델이 해제되면 진행 중인 분석 task를 취소한다")
    func deinitCancelsRunningAnalysis() async {
        let probe = AnalysisProbe()
        var model: ScheduleFlowModel? = ScheduleFlowModel(
            lists: lists,
            analyze: { _ in
                probe.isStarted = true
                do {
                    try await Task.sleep(for: .seconds(30))
                } catch {
                    probe.isCancelled = true
                    throw error
                }
                return []
            },
            register: { _ in })
        model?.text = "입력"
        model?.startAnalysis()
        await waitUntil { probe.isStarted }
        model = nil
        await waitUntil { probe.isCancelled }
        #expect(probe.isCancelled)
    }
}
