import SwiftUI

@main
struct TtakApp: App {
    var body: some Scene {
        MenuBarExtra("Ttak", systemImage: "checkmark.circle") {
            ScheduleInputView()
        }
        .menuBarExtraStyle(.window)

        #if DEBUG
            Window("Ttak 컴포넌트 갤러리", id: ComponentGalleryView.windowID) {
                ComponentGalleryView()
            }
            .defaultSize(width: 880, height: 640)
        #endif
    }
}
