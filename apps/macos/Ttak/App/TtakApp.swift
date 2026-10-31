import SwiftUI

@main
struct TtakApp: App {
    #if DEBUG
        @NSApplicationDelegateAdaptor(TransparentMenuDelegate.self) private var menuDelegate
    #endif
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

            Window("Ttak 기술 검증", id: "technical-validation") {
                ScheduleInputView()
            }
            .defaultLaunchBehavior(.suppressed)
        #endif

        #if !DEBUG
            MenuBarExtra("Ttak", systemImage: "checkmark.circle") {
                ScheduleInputView()
            }
            .menuBarExtraStyle(.window)
        #endif

    }
}

#if DEBUG
    /// A transparent panel avoids the system material supplied by MenuBarExtra's window style.
    @MainActor
    final class TransparentMenuDelegate: NSObject, NSApplicationDelegate {
        private var statusItem: NSStatusItem?
        private var panel: NSPanel?
        private var globalMonitor: Any?
        private var localMonitor: Any?
        /// Owned here so input and results survive the panel being closed and reopened.
        private let flowModel = ScheduleFlowSampleView.makeModel()

        func applicationDidFinishLaunching(_ notification: Notification) {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            item.button?.image = NSImage(
                systemSymbolName: "checkmark.circle", accessibilityDescription: "Ttak")
            item.button?.target = self
            item.button?.action = #selector(togglePanel)
            statusItem = item
        }

        @objc private func togglePanel() {
            if panel?.isVisible == true {
                closePanel()
                return
            }
            guard let button = statusItem?.button, let buttonWindow = button.window else { return }
            let panel = KeyablePanel(
                contentRect: NSRect(x: 0, y: 0, width: 440, height: 100),
                styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.level = .popUpMenu
            panel.isReleasedWhenClosed = false
            let host = ResizingHostingView(
                rootView: ScheduleFlowSampleView(menuBar: true, model: flowModel))
            host.panel = panel
            panel.contentView = host
            self.panel = panel
            let buttonRect = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
            host.topCenter = NSPoint(x: buttonRect.midX, y: buttonRect.minY)
            host.resizePanel()
            panel.makeKeyAndOrderFront(nil)
            globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [
                .leftMouseDown, .rightMouseDown,
            ]) { [weak self] _ in
                Task { @MainActor in
                    guard NSApp.modalWindow == nil, let self else { return }
                    // The icon click is closed by togglePanel; closing here would reopen it.
                    guard !self.isStatusItemClick() else { return }
                    self.closePanel()
                }
            }
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: [
                .leftMouseDown, .rightMouseDown, .keyDown,
            ]) { [weak self, weak panel] event in
                if event.type == .keyDown && event.keyCode == 53 {
                    guard NSApp.modalWindow == nil, event.window === panel else { return event }
                    self?.closePanel()
                    return nil
                }
                return event
            }
        }

        private func isStatusItemClick() -> Bool {
            guard let button = statusItem?.button, let window = button.window else { return false }
            let iconRect = window.convertToScreen(button.convert(button.bounds, to: nil))
            return iconRect.contains(NSEvent.mouseLocation)
        }

        private func closePanel() {
            panel?.orderOut(nil)
            panel = nil
            if let globalMonitor {
                NSEvent.removeMonitor(globalMonitor)
                self.globalMonitor = nil
            }
            if let localMonitor {
                NSEvent.removeMonitor(localMonitor)
                self.localMonitor = nil
            }
        }
    }

    private final class KeyablePanel: NSPanel {
        override var canBecomeKey: Bool { true }
    }

    private final class ResizingHostingView: NSHostingView<ScheduleFlowSampleView> {
        weak var panel: NSPanel?
        var topCenter: NSPoint = .zero
        private var pendingResize = false

        override func layout() {
            super.layout()
            guard !pendingResize else { return }
            pendingResize = true
            DispatchQueue.main.async { [weak self] in
                self?.pendingResize = false
                self?.resizePanel()
            }
        }

        func resizePanel() {
            guard let panel, topCenter != .zero else { return }
            let height = max(1, fittingSize.height)
            let width: CGFloat = 440
            let screen = NSScreen.screens.first { $0.frame.contains(topCenter) } ?? NSScreen.main
            let visibleFrame = screen?.visibleFrame ?? .zero
            let desiredX = topCenter.x - width / 2
            let x =
                visibleFrame.isEmpty
                ? desiredX : max(visibleFrame.minX, min(desiredX, visibleFrame.maxX - width))
            let frame = NSRect(x: x, y: topCenter.y - height, width: width, height: height)
            guard panel.frame != frame else { return }
            panel.setFrame(frame, display: true)
        }
    }
#endif
