#if DEBUG
    import SwiftUI

    struct ScheduleResultItemSampleView: View {
        @State private var drafts = Self.samples
        @State private var excludedIDs: [UUID] = []
        private let lists = [
            ReminderList(id: "dev", title: "Dev"),
            ReminderList(id: "personal", title: "일상"),
            ReminderList(id: "work", title: "일상"),
        ]

        var body: some View {
            VStack(alignment: .leading, spacing: 20) {
                Text("수정은 아래 합성 초안에 즉시 반영됩니다. 제외는 샘플에서만 처리합니다.")
                    .foregroundStyle(.white.opacity(0.75))
                ForEach($drafts) { $draft in
                    if !draft.isExcluded {
                        ScheduleResultItem(draft: $draft, lists: lists, calendar: .current) { id in
                            if let index = drafts.firstIndex(where: { $0.id == id }) {
                                drafts[index].isExcluded = true
                                excludedIDs.append(id)
                            }
                        }
                        Text(
                            "현재 값: \(draft.title) / \(draft.dateText) / \(draft.timeText.isEmpty ? "시각 없음" : draft.timeText) / 목록 ID: \(draft.listID ?? "미선택")"
                        )
                        .font(.caption).textSelection(.enabled)
                        .foregroundStyle(.white.opacity(0.75))
                    }
                }
                Text("제외 요청: \(excludedIDs.count)건")
                    .foregroundStyle(.white.opacity(0.75))
                Button("합성 샘플 초기화") {
                    drafts = Self.samples
                    excludedIDs = []
                }
            }
            .frame(maxWidth: 500, alignment: .leading)
            .padding(24)
            .background(
                LinearGradient(
                    colors: [
                        Color(.sRGB, red: 0.22, green: 0.23, blue: 0.26),
                        Color(.sRGB, red: 0.12, green: 0.13, blue: 0.15),
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 20)
            )
        }

        private static var samples: [ScheduleDraft] {
            [
                ScheduleDraft(
                    title: "개발 스터디", dateText: "2026-10-31", timeText: "15:00", listID: "dev"),
                ScheduleDraft(
                    title: "팀 회식", dateText: "2026-10-31",
                    notes: "시간 원문: 저녁. 장소: 합성 식당. 종료 원문: 회식이 끝날 때까지."),
                ScheduleDraft(
                    title: "날짜 충돌 확인", dateText: "2026-10-31", listID: "dev",
                    notes: "날짜 원문: 10월 31일 월요일. 날짜와 요일이 일치하지 않아요.", dateNeedsConfirmation: true),
                ScheduleDraft(
                    title: "긴 제목과 부가 정보가 여러 줄로 표시되는지 확인하는 합성 프로젝트 일정 검토 회의", dateText: "2026-11-01",
                    timeText: "09:30", listID: "work",
                    notes: String(
                        repeating: "장소: 합성 회의실. 종료 정보: 오후 5시까지. 준비물과 논의할 사항을 원문 그대로 확인합니다.\n",
                        count: 5)),
                ScheduleDraft(
                    title: "잘못된 날짜와 사용할 수 없는 목록", dateText: "2026-02-30", timeText: "25:00",
                    listID: "missing"),
            ]
        }
    }
#endif
