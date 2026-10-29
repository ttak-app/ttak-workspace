#if DEBUG
    import SwiftUI

    struct ComponentGalleryView: View {
        static let windowID = "component-gallery"

        var body: some View {
            VStack(alignment: .leading, spacing: 20) {
                Text("컴포넌트 갤러리").font(.largeTitle)
                Text("개발용 샘플입니다. 실제 분석이나 미리 알림 저장을 실행하지 않아요.")
                    .foregroundStyle(.secondary)
                ScheduleMessageView(message: "앱과 같은 ScheduleMessageView로 표시한 샘플 안내입니다.")
            }
            .padding(24)
            .frame(minWidth: 720, minHeight: 480, alignment: .topLeading)
        }
    }
#endif
