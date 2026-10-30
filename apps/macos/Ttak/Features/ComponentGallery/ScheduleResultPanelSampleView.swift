#if DEBUG
    import SwiftUI

    struct ScheduleResultPanelSampleView: View {
        @State private var drafts = Self.samples
        @State private var actionMessage = "아직 실행한 액션이 없어요."
        @State private var isPresented = true
        private let lists = [ReminderList(id: "dev", title: "Dev")]

        var body: some View {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Button("복수 일정") { reset(Self.samples) }
                    Button("단일 일정") { reset(Array(Self.samples.prefix(1))) }
                    Button("빈 결과") { reset([]) }
                }
                if isPresented {
                    ScheduleResultPanel(drafts: $drafts, lists: lists, calendar: .current) {
                        isPresented = false
                        actionMessage = "취소 요청: 결과 패널을 닫았어요."
                    } onRegister: { registered in
                        actionMessage =
                            "등록 요청: \(registered.map(\.title).joined(separator: ", ")) (실제 저장 없음)"
                    }
                }
                Text(actionMessage)
                    .font(.callout)
                    .textSelection(.enabled)
                Text("합성 데이터만 사용합니다. 위 샘플 버튼으로 취소 후 다시 열 수 있어요.")
                    .font(.caption)
            }
            .frame(maxWidth: 500, alignment: .leading)
            .padding(24)
            .background(
                LinearGradient(
                    colors: [
                        Color(.sRGB, red: 0.22, green: 0.23, blue: 0.26),
                        Color(.sRGB, red: 0.12, green: 0.13, blue: 0.15),
                    ], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 20)
            )
        }

        private func reset(_ samples: [ScheduleDraft]) {
            drafts = samples
            isPresented = true
            actionMessage = "샘플을 초기화했어요."
        }

        private static var samples: [ScheduleDraft] {
            [
                ScheduleDraft(
                    title: "개발 스터디", dateText: "2026-10-31", timeText: "15:00",
                    listID: "dev", notes: "장소: 합성 공유 오피스"),
                ScheduleDraft(
                    title: "팀 회식", dateText: "2026-10-31", notes: "시간 원문: 저녁"),
            ]
        }
    }
#endif
