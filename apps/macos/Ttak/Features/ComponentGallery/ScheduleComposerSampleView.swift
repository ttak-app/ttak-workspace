#if DEBUG
    import AppKit
    import SwiftUI

    struct ScheduleComposerSampleView: View {
        @State private var text = ""
        @State private var attachment: ImageAttachment?
        @State private var selectedState: SampleState = .empty
        @State private var actionCount = 0

        var body: some View {
            VStack(alignment: .leading, spacing: 20) {
                Text("공통 입력과 이미지 첨부").font(.headline)
                Picker("샘플 상태", selection: $selectedState) {
                    ForEach(SampleState.allCases) { state in
                        Text(state.rawValue).tag(state)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: selectedState) { _, state in apply(state) }

                ScheduleComposer(
                    text: $text,
                    attachment: $attachment,
                    canAnalyze: selectedState != .disabled,
                    isAnalyzing: selectedState == .analyzing,
                    isEnabled: selectedState != .disabled,
                    onAnalyze: { actionCount += 1 }
                )
                .frame(maxWidth: 580)
                .padding(.vertical, 32)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity, alignment: .leading)
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

                Text("모의 분석 요청: \(actionCount)회")
                    .monospacedDigit()
                HStack {
                    Button("횟수 초기화") { actionCount = 0 }
                    Button(attachment == nil ? "샘플 이미지 첨부" : "샘플 이미지 삭제") {
                        attachment = attachment == nil ? Self.sampleAttachment() : nil
                    }
                    .disabled(selectedState == .disabled)
                }
                Text("파일 선택과 ⌘V로 실제 이미지를 첨부할 수 있어요. 두 번째 이미지는 기존 이미지를 교체합니다.")
                Text("Enter는 줄바꿈, ⌘Enter는 모의 분석 요청입니다. 분석 진행 상태는 위 메뉴에서 직접 바꿉니다.")
                Text("지원 형식: PNG, JPEG, HEIC, TIFF. 분석이나 저장 서비스는 호출하지 않습니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }

        private func apply(_ state: SampleState) {
            text = state == .empty || state == .image ? "" : "내일 오전 9시에 팀 회의"
            attachment = state == .image || state == .combined ? Self.sampleAttachment() : nil
        }

        private static func sampleAttachment() -> ImageAttachment? {
            let image = NSImage(size: NSSize(width: 640, height: 320), flipped: false) { bounds in
                NSColor.windowBackgroundColor.setFill()
                bounds.fill()
                let title = "일정 이미지 샘플"
                title.draw(
                    at: NSPoint(x: 32, y: 230),
                    withAttributes: [
                        .font: NSFont.systemFont(ofSize: 32, weight: .semibold),
                        .foregroundColor: NSColor.labelColor,
                    ])
                "내일 오전 9시 팀 회의".draw(
                    at: NSPoint(x: 32, y: 140),
                    withAttributes: [
                        .font: NSFont.systemFont(ofSize: 24),
                        .foregroundColor: NSColor.secondaryLabelColor,
                    ])
                return true
            }
            guard let data = image.tiffRepresentation else { return nil }
            return ImageAttachment(data: data, name: "일정 샘플.tiff")
        }
    }

    private enum SampleState: String, CaseIterable, Identifiable {
        case empty = "빈 입력"
        case text = "텍스트"
        case image = "이미지 단독"
        case combined = "이미지와 설명"
        case analyzing = "분석 진행"
        case disabled = "비활성"

        var id: String { rawValue }
    }
#endif
