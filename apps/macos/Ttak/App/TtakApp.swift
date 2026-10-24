import SwiftUI

@main
struct TtakApp: App {
    var body: some Scene {
        MenuBarExtra("Ttak", systemImage: "checkmark.circle") {
            ScheduleInputView()
        }
        .menuBarExtraStyle(.window)
    }
}
