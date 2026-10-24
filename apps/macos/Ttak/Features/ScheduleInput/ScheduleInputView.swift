import AppKit
import SwiftUI

struct ScheduleInputView: View {
    @State private var input = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ttak")
                .font(.headline)

            TextField("일정을 말하듯 적어주세요", text: $input, axis: .vertical)
                .lineLimit(3...6)
                .textFieldStyle(.roundedBorder)
                .focused($isInputFocused)

            Text("날짜를 생략하면 오늘로 등록돼요.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("초기 개발 화면 · 분석과 저장 기능은 준비 중입니다.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            Button("Ttak 종료") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(20)
        .frame(width: 360)
        .onAppear {
            isInputFocused = true
        }
    }
}
