import SwiftUI

/// 표시와 액션 전달만 담당한다. 요청 실행과 재시도 정책은 호출부가 소유한다.
struct ScheduleStatusView: View {
    enum Kind {
        case progress, information, warning, failure, success

        var symbol: String {
            switch self {
            case .progress: "clock"
            case .information: "info.circle"
            case .warning: "exclamationmark.triangle"
            case .failure: "xmark.circle"
            case .success: "checkmark.circle"
            }
        }

        var label: String {
            switch self {
            case .progress: "진행 중"
            case .information: "안내"
            case .warning: "확인 필요"
            case .failure: "실패"
            case .success: "완료"
            }
        }
    }

    struct Action {
        let title: String
        let perform: () -> Void
    }

    let kind: Kind
    let title: String
    let message: String
    var action: Action? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Group {
                if kind == .progress {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: kind.symbol).font(.title3)
                }
            }
            .frame(width: 24, height: 24)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                    .accessibilityLabel("\(kind.label): \(title)")
                ScheduleMessageView(message: message)
                    .id(message)
                    .foregroundStyle(.secondary)
                if let action {
                    Button(action.title, action: action.perform)
                        .buttonStyle(.bordered)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(16)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
        .frame(maxWidth: 500)
        .accessibilityElement(children: .contain)
    }
}
