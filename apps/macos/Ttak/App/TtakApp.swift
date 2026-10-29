import SwiftUI

@main
struct TtakApp: App {
    var body: some Scene {
        #if DEBUG
            Window("Ttak 컴포넌트 갤러리", id: ComponentGalleryView.windowID) {
                ComponentGalleryView()
                    .onAppear {
                        NSApplication.shared.activate(ignoringOtherApps: true)
                    }
            }
            .defaultSize(width: 880, height: 640)
            .defaultLaunchBehavior(.presented)
        #endif

        MenuBarExtra("Ttak", systemImage: "checkmark.circle") {
            ScheduleInputView()
        }
        .menuBarExtraStyle(.window)

    }
}
