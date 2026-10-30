#if DEBUG
    import SwiftUI

    struct ScheduleStatusSampleView: View {
        @State private var selectedSample = StatusSample.samples[0].id
        @State private var usesLongMessage = false
        @State private var actionCount = 0
        @State private var lastAction: String?

        private var sample: StatusSample {
            StatusSample.samples.first { $0.id == selectedSample } ?? StatusSample.samples[0]
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 20) {
                Text("문구와 버튼은 검토용 제안입니다. 실제 서비스 연결과 복구 정책은 후속 작업에서 정합니다.")
                    .font(.callout).foregroundStyle(.secondary)
                Picker("표시할 상태", selection: $selectedSample) {
                    ForEach(StatusSample.samples) { sample in
                        Text("\(sample.group) / \(sample.title)").tag(sample.id)
                    }
                }
                Toggle("긴 설명으로 레이아웃 확인", isOn: $usesLongMessage)
                ScheduleStatusView(
                    kind: sample.kind,
                    title: sample.title,
                    message: sample.message
                        + (usesLongMessage
                            ? " 입력한 내용은 이 안내와 별도로 유지됩니다. 현재 상황을 확인한 뒤 다음 행동을 선택해 주세요. 이 문장은 좁은 창에서 여러 줄 설명과 버튼이 겹치거나 잘리지 않는지 확인하기 위한 샘플입니다."
                            : ""),
                    action: sample.actionTitle.map { title in
                        ScheduleStatusView.Action(title: title) {
                            actionCount += 1
                            lastAction = "\(sample.title): \(title)"
                        }
                    }
                )
                Text("로컬 액션 실행: \(actionCount)회")
                    .font(.caption.monospacedDigit())
                if let lastAction {
                    Text("마지막 동작: \(lastAction). 실제 요청은 실행하지 않았어요.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Button("샘플 초기화") {
                    actionCount = 0
                    lastAction = nil
                    usesLongMessage = false
                }
                Divider()
                Text(
                    "부분 성공과 결과 확인 필요에는 재저장 버튼을 제공하지 않습니다. 저장 결과를 확인하는 로컬 액션만 제안하며, 재시도나 중복 방지 정책은 정의하지 않습니다."
                )
                .font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: 500, alignment: .leading)
        }
    }

    private struct StatusSample: Identifiable {
        let id: String
        let group: String
        let kind: ScheduleStatusView.Kind
        let title: String
        let message: String
        var actionTitle: String? = nil

        static let samples: [StatusSample] = [
            .init(
                id: "analyzing", group: "분석", kind: .progress, title: "일정을 분석하고 있어요",
                message: "입력한 내용에서 일정 정보를 찾고 있어요."),
            .init(
                id: "ocr", group: "분석", kind: .failure, title: "이미지의 글자를 읽지 못했어요",
                message: "글자가 선명한 이미지를 선택하거나 내용을 직접 입력해 주세요.", actionTitle: "입력 확인"),
            .init(
                id: "analysis", group: "분석", kind: .failure, title: "일정 분석에 실패했어요",
                message: "입력한 내용을 분석하지 못했어요. 내용을 확인한 뒤 다시 시도해 주세요.", actionTitle: "다시 분석"),
            .init(
                id: "model", group: "분석", kind: .warning, title: "분석 모델을 사용할 수 없어요",
                message: "이 기기의 모델 사용 가능 상태를 확인해 주세요.", actionTitle: "사용 조건 확인"),
            .init(
                id: "empty", group: "분석", kind: .information, title: "일정을 찾지 못했어요",
                message: "등록할 일정의 제목과 날짜가 포함되어 있는지 확인해 주세요.", actionTitle: "입력 확인"),
            .init(
                id: "permissionPending", group: "권한", kind: .information,
                title: "미리 알림 접근 권한이 필요해요", message: "목록을 확인하고 일정을 등록하려면 미리 알림 접근을 허용해 주세요.",
                actionTitle: "접근 허용"),
            .init(
                id: "permissionDenied", group: "권한", kind: .warning, title: "미리 알림 접근이 허용되지 않았어요",
                message: "권한이 거부되었거나 철회되었어요. 시스템 설정에서 Ttak의 미리 알림 접근 권한을 확인해 주세요.",
                actionTitle: "설정 확인"),
            .init(
                id: "listsLoading", group: "목록", kind: .progress, title: "목록을 불러오고 있어요",
                message: "일정을 저장할 수 있는 미리 알림 목록을 확인하고 있어요."),
            .init(
                id: "listsEmpty", group: "목록", kind: .information, title: "저장 가능한 목록이 없어요",
                message: "미리 알림 앱에서 쓰기 가능한 목록을 준비한 뒤 다시 확인해 주세요.", actionTitle: "목록 다시 확인"),
            .init(
                id: "listsFailed", group: "목록", kind: .failure, title: "목록을 불러오지 못했어요",
                message: "미리 알림 목록 조회에 실패했어요. 잠시 후 다시 확인해 주세요.", actionTitle: "목록 다시 확인"),
            .init(
                id: "saving", group: "저장", kind: .progress, title: "일정을 등록하고 있어요",
                message: "선택한 일정 3개의 저장 결과를 확인하고 있어요."),
            .init(
                id: "saved", group: "저장", kind: .success, title: "일정 3개를 모두 등록했어요",
                message: "선택한 목록에 일정 3개가 저장되었어요."),
            .init(
                id: "saveFailed", group: "저장", kind: .failure, title: "일정을 등록하지 못했어요",
                message: "선택한 일정 3개가 모두 저장되지 않았어요. 저장 결과를 확인해 주세요.", actionTitle: "결과 확인"),
            .init(
                id: "partial", group: "저장", kind: .warning, title: "일부 일정만 등록되었어요",
                message: "3개 중 2개는 저장되었고 1개는 저장되지 않았어요. 다시 등록하기 전에 항목별 결과를 확인해 주세요.",
                actionTitle: "결과 확인"),
            .init(
                id: "unknown", group: "저장", kind: .warning, title: "등록 결과를 확인해야 해요",
                message: "일부 일정의 저장 여부를 확인하지 못했어요. 중복 등록을 피하려면 미리 알림과 항목별 결과를 먼저 확인해 주세요.",
                actionTitle: "결과 확인"),
        ]
    }
#endif
