#if DEBUG
    import SwiftUI

    struct SchedulePrototypeView: View {
        private enum Phase: Equatable {
            case input, analyzing, reviewing, registering, completed
        }

        @State private var text = ""
        @State private var attachment: ImageAttachment?
        @State private var drafts: [ScheduleDraft] = []
        @State private var phase: Phase = .input
        @State private var registeredCount = 0
        private let lists = [
            ReminderList(id: "dev", title: "Dev"),
            ReminderList(id: "personal", title: "일상"),
        ]

        var body: some View {
            VStack(alignment: .leading, spacing: 20) {
                Text("모의 프로토타입: 입력과 관계없이 합성 일정 2개를 표시하며 실제 분석과 저장은 실행하지 않아요.")
                    .font(.callout)
                Button("예시 입력 채우기") {
                    text = "내일 오후 3시 개발 스터디, 저녁 팀 회식"
                    phase = .input
                }
                .disabled(phase != .input && phase != .completed)
                ScheduleComposer(
                    text: $text, attachment: $attachment,
                    canAnalyze: phase == .input || phase == .completed,
                    isAnalyzing: phase == .analyzing,
                    isEnabled: phase == .input || phase == .completed,
                    onAnalyze: { phase = .analyzing }
                )
                if phase == .analyzing {
                    ScheduleStatusView(
                        kind: .progress, title: "일정을 분석하고 있어요",
                        message: "샘플 일정을 준비하고 있어요.")
                }
                if phase == .reviewing || phase == .registering {
                    ScheduleResultPanel(
                        drafts: $drafts, lists: lists, calendar: .current,
                        onCancel: {
                            drafts = []
                            phase = .input
                        },
                        onRegister: { included in
                            registeredCount = included.count
                            phase = .registering
                        }
                    )
                    .disabled(phase == .registering)
                }
                if phase == .registering {
                    ScheduleStatusView(
                        kind: .progress, title: "등록 중이에요",
                        message: "실제 미리 알림을 만들지 않는 모의 등록입니다.")
                }
                if phase == .completed {
                    ScheduleStatusView(
                        kind: .success, title: "\(registeredCount)개 일정 모의 등록 완료",
                        message: "입력과 결과를 초기화했어요. 새 입력으로 다시 확인할 수 있어요.")
                }
            }
            .frame(maxWidth: 500, alignment: .leading)
            .padding(24)
            .background(
                Color(nsColor: .windowBackgroundColor),
                in: RoundedRectangle(cornerRadius: 20)
            )
            .environment(\.colorScheme, .light)
            .task(id: phase) {
                if phase == .completed {
                    do {
                        try await Task.sleep(for: .seconds(3))
                    } catch { return }
                    guard !Task.isCancelled, phase == .completed else { return }
                    phase = .input
                    return
                }
                guard phase == .analyzing || phase == .registering else { return }
                let pendingPhase = phase
                do {
                    try await Task.sleep(for: .milliseconds(800))
                } catch { return }
                guard !Task.isCancelled, phase == pendingPhase else { return }
                if pendingPhase == .analyzing {
                    let date = ScheduleDateParser.dateText(
                        Calendar.current.startOfDay(for: Date()), calendar: .current)
                    drafts = [
                        ScheduleDraft(
                            title: "개발 스터디", dateText: date, timeText: "15:00",
                            listID: "dev", notes: "장소: 합성 공유 오피스"),
                        ScheduleDraft(
                            title: "팀 회식", dateText: date, notes: "시간 원문: 저녁"),
                    ]
                    phase = .reviewing
                } else {
                    text = ""
                    attachment = nil
                    drafts = []
                    phase = .completed
                }
            }
        }
    }
#endif
