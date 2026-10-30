import SwiftUI

/// Composes the input and its progress state using an externally supplied flow model.
struct ScheduleFlowView: View {
    @Bindable var model: ScheduleFlowModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScheduleComposer(
                text: $model.text,
                attachment: $model.attachment,
                canAnalyze: model.canAnalyze,
                isAnalyzing: model.phase == .analyzing,
                isEnabled: model.phase != .analyzing && model.phase != .reviewing,
                showsAttachment: model.phase != .reviewing,
                onAnalyze: model.startAnalysis
            )
            if model.phase == .empty {
                ScheduleStatusView(
                    kind: .information,
                    title: "일정을 찾지 못했어요",
                    message: "입력을 확인한 뒤 다시 분석해 주세요.",
                    action: model.canAnalyze
                        ? .init(title: "다시 분석", perform: model.startAnalysis) : nil
                )
            }
            if case .failure(let message) = model.phase {
                ScheduleStatusView(
                    kind: .failure,
                    title: "일정을 분석하지 못했어요",
                    message: message,
                    action: model.canAnalyze
                        ? .init(title: "다시 분석", perform: model.startAnalysis) : nil
                )
            }
            if model.phase == .reviewing {
                ScheduleResultPanel(
                    drafts: $model.drafts,
                    lists: model.lists,
                    calendar: model.calendar,
                    onCancel: model.cancelReview,
                    onRegister: { _ in model.registerDrafts() }
                )
            }
        }
        .frame(maxWidth: 500, alignment: .leading)
        .onDisappear { model.cancelAnalysis() }
    }
}

#if DEBUG
    /// A temporary entry point for exercising the flow without external services.
    struct ScheduleFlowSampleView: View {
        @State private var model: ScheduleFlowModel
        private let menuBar: Bool

        init(menuBar: Bool = false) {
            self.menuBar = menuBar
            _model = State(
                initialValue: ScheduleFlowModel(
                    lists: [ReminderList(id: "sample-dev", title: "샘플 목록")],
                    analyze: { _ in
                        try await Task.sleep(for: .milliseconds(800))
                        let date = ScheduleDateParser.dateText(
                            Calendar.current.startOfDay(for: Date()), calendar: .current)
                        return [
                            ScheduleDraft(title: "샘플 일정", dateText: date, listID: "sample-dev")
                        ]
                    },
                    register: { _ in }
                )
            )
        }

        var body: some View {
            content
            .frame(width: menuBar ? 440 : nil)
        }

        private var content: some View {
            VStack(alignment: .leading, spacing: 20) {
                if !menuBar {
                    Text("개발용 모의 화면입니다. 입력과 관계없이 샘플 일정을 사용하며 실제 분석과 저장은 실행하지 않아요.")
                        .font(.callout)
                }
                ScheduleFlowView(model: model)
            }
            .padding(.horizontal, menuBar ? 20 : 0)
            .padding(.top, menuBar ? 10 : 0)
            .padding(.bottom, menuBar ? 20 : 0)
        }
    }
#endif
