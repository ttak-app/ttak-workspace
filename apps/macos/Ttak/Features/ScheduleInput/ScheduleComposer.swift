import AppKit
import SwiftUI

struct ScheduleComposer: View {
    @Binding var text: String
    @Binding var attachment: ImageAttachment?
    let canAnalyze: Bool
    let isAnalyzing: Bool
    let isEnabled: Bool
    var showsAttachment = true
    let onAnalyze: () -> Void

    @State private var attachmentError: String?
    @State private var editorHeight: CGFloat = 26
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var canRequestAnalysis: Bool {
        isEnabled && !isAnalyzing && canAnalyze
            && (attachment != nil || !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                Button(action: selectImage) {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .regular))
                        .frame(width: 30, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .disabled(!isEnabled)
                .accessibilityLabel("이미지 첨부")
                .help("PNG, JPEG, HEIC, TIFF 이미지 한 장을 선택하거나 입력창에서 ⌘V로 붙여넣으세요.")

                ZStack(alignment: .topLeading) {
                    if text.isEmpty {
                        Text(attachment == nil ? "일정을 적거나 이미지를 첨부하세요" : "이미지에 대한 설명을 덧붙여도 좋아요")
                            .font(.system(size: 16))
                            .foregroundStyle(.tertiary)
                            .padding(.leading, 5)
                            .padding(.top, 3)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                    ComposerTextEditor(
                        text: $text, height: $editorHeight, isEnabled: isEnabled,
                        onPasteImage: pasteImage, onAnalyze: requestAnalysis
                    )
                    .frame(height: editorHeight)
                }
                .frame(maxWidth: .infinity)

                Button(action: requestAnalysis) {
                    ZStack {
                        Circle().fill(.background.opacity(colorScheme == .dark ? 0.6 : 0.85))
                        if isAnalyzing {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 19, weight: .medium))
                                .foregroundStyle(.secondary)
                                .opacity(canRequestAnalysis ? 1 : 0.4)
                        }
                    }
                    .frame(width: 36, height: 36)
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(!canRequestAnalysis)
                .accessibilityLabel(isAnalyzing ? "분석 중" : "일정 분석하기")
                .help("⌘Enter로 분석")
            }
            .padding(.leading, 12)
            .padding(.trailing, 13)
            .padding(.vertical, 9)
            .glassEffect(
                .regular.tint(
                    colorScheme == .dark
                        ? Color(nsColor: .controlBackgroundColor).opacity(0.45)
                        : TtakTokens.Colors.brandTint.opacity(0.35)
                ),
                in: RoundedRectangle(cornerRadius: 30)
            )
            .background {
                ComposerAmbientGlow(reduceMotion: reduceMotion)
            }
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.18 : 0.08), radius: 12, y: 5)

            if showsAttachment, let attachment {
                HStack(spacing: 12) {
                    Image(attachment.preview, scale: 2, label: Text("첨부 이미지 미리보기"))
                        .resizable()
                        .scaledToFit()
                        .frame(width: 64, height: 64)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 9))
                        .accessibilityLabel("첨부 이미지 미리보기")
                    Text(attachment.name)
                        .font(.caption)
                        .lineLimit(2)
                    Spacer(minLength: 8)
                    Button("삭제", systemImage: "xmark") {
                        self.attachment = nil
                        attachmentError = nil
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .disabled(!isEnabled)
                    .accessibilityLabel("첨부 이미지 삭제")
                }
                .padding(12)
                .glassEffect(
                    .regular.tint(Color(nsColor: .windowBackgroundColor).opacity(0.35)),
                    in: RoundedRectangle(cornerRadius: 18)
                )
                .transition(
                    reduceMotion
                        ? .opacity
                        : .offset(y: -28).combined(with: .opacity)
                )
            }

            if let attachmentError {
                Text(attachmentError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 16)
                    .accessibilityLabel("첨부 오류: \(attachmentError)")
            }
        }
        .animation(
            reduceMotion ? .easeOut(duration: 0.15) : .easeOut(duration: 0.4),
            value: attachment != nil
        )
        .frame(maxWidth: 500)
        .onChange(of: attachment?.id) { _, _ in
            attachmentError = nil
        }
    }

    private func requestAnalysis() {
        guard canRequestAnalysis else { return }
        onAnalyze()
    }

    private func selectImage() {
        guard isEnabled else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = ImageAttachment.supportedTypes
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url, isEnabled else { return }
        do {
            attachment = try ImageAttachmentImport.readFile(at: url)
            attachmentError = nil
        } catch {
            attachmentError = error.localizedDescription
        }
    }

    private func pasteImage(_ pasteboard: NSPasteboard) -> Bool {
        guard isEnabled else { return true }
        do {
            guard let image = try ImageAttachmentImport.readPasteboard(pasteboard) else {
                return false
            }
            attachment = image
            attachmentError = nil
            return true
        } catch {
            attachmentError = error.localizedDescription
            return true
        }
    }
}

private struct ComposerAmbientGlow: View {
    let reduceMotion: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 30)
            .fill(
                LinearGradient(
                    colors: [
                        TtakTokens.Colors.brandCoral,
                        TtakTokens.Colors.brandOrange,
                        TtakTokens.Colors.logoCoral,
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .padding(.horizontal, 6)
            .blur(radius: 18)
            .phaseAnimator(reduceMotion ? [false] : [false, true]) { glow, isBright in
                glow
                    .opacity(isBright ? 0.38 : 0.2)
                    .scaleEffect(x: isBright ? 1.015 : 0.985, y: isBright ? 1.12 : 0.94)
            } animation: { _ in
                .easeInOut(duration: 3)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

private struct ComposerTextEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var height: CGFloat
    let isEnabled: Bool
    let onPasteImage: (NSPasteboard) -> Bool
    var showsAttachment = true
    let onAnalyze: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let editor = ComposerNativeTextView()
        editor.delegate = context.coordinator
        editor.isRichText = false
        editor.allowsUndo = true
        editor.importsGraphics = false
        editor.drawsBackground = false
        editor.font = .systemFont(ofSize: 16)
        editor.textColor = .labelColor
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.minimumLineHeight = 22
        paragraphStyle.maximumLineHeight = 22
        editor.defaultParagraphStyle = paragraphStyle
        editor.typingAttributes = [
            .font: NSFont.systemFont(ofSize: 16),
            .paragraphStyle: paragraphStyle,
            .foregroundColor: NSColor.labelColor,
        ]
        editor.textContainerInset = NSSize(width: 0, height: 2)
        editor.isHorizontallyResizable = false
        editor.isVerticallyResizable = true
        editor.minSize = NSSize(width: 0, height: 26)
        editor.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        editor.autoresizingMask = [.width]
        editor.textContainer?.widthTracksTextView = true
        editor.textContainer?.lineFragmentPadding = 0
        editor.textContainer?.containerSize = NSSize(
            width: 0, height: CGFloat.greatestFiniteMagnitude)
        editor.setAccessibilityLabel("일정 또는 이미지 보조 설명")
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.scrollerStyle = .overlay
        scroll.documentView = editor
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let editor = scroll.documentView as? ComposerNativeTextView else { return }
        context.coordinator.parent = self
        if editor.string != text && !editor.hasMarkedText() {
            editor.replaceTextFromParent(text)
        }
        editor.isEditable = isEnabled
        editor.textColor = isEnabled ? .labelColor : .disabledControlTextColor
        editor.onPasteImage = onPasteImage
        editor.onAnalyze = onAnalyze
        editor.onWidthChange = { [weak coordinator = context.coordinator, weak editor] in
            guard let editor else { return }
            coordinator?.scheduleHeightUpdate(for: editor)
        }
        context.coordinator.scheduleHeightUpdate(for: editor)
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ComposerTextEditor
        private var isHeightUpdateScheduled = false

        init(_ parent: ComposerTextEditor) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let editor = notification.object as? NSTextView else { return }
            parent.text = editor.string
            scheduleHeightUpdate(for: editor)
        }

        func scheduleHeightUpdate(for editor: NSTextView) {
            guard !isHeightUpdateScheduled else { return }
            isHeightUpdateScheduled = true
            // Layout can run during a SwiftUI update. Publish the measured height on the next turn.
            Task { @MainActor [weak self, weak editor] in
                guard let self else { return }
                isHeightUpdateScheduled = false
                guard let editor, let container = editor.textContainer,
                    let manager = editor.layoutManager, container.containerSize.width > 0
                else { return }
                manager.ensureLayout(for: container)
                let usedHeight = max(
                    manager.usedRect(for: container).maxY,
                    manager.extraLineFragmentRect.maxY)
                let contentHeight = max(26, ceil(usedHeight + editor.textContainerInset.height * 2))
                let measuredHeight = min(92, contentHeight)
                if parent.height != measuredHeight { parent.height = measuredHeight }
                let documentHeight = max(measuredHeight, contentHeight)
                if editor.frame.height != documentHeight {
                    editor.setFrameSize(NSSize(width: editor.frame.width, height: documentHeight))
                }
            }
        }
    }
}

final class ComposerNativeTextView: NSTextView {
    private let inputUndoManager = UndoManager()

    override var undoManager: UndoManager? { inputUndoManager }

    func replaceTextFromParent(_ text: String) {
        inputUndoManager.removeAllActions()
        string = text
    }

    @objc func undo(_ sender: Any?) {
        guard isEditable, inputUndoManager.canUndo else { return }
        inputUndoManager.undo()
    }

    @objc func redo(_ sender: Any?) {
        guard isEditable, inputUndoManager.canRedo else { return }
        inputUndoManager.redo()
    }

    var onPasteImage: ((NSPasteboard) -> Bool)?
    var onAnalyze: (() -> Void)?
    var onWidthChange: (() -> Void)?

    override func setFrameSize(_ newSize: NSSize) {
        let didChangeWidth = frame.width != newSize.width
        super.setFrameSize(newSize)
        if didChangeWidth { onWidthChange?() }
    }

    override var readablePasteboardTypes: [NSPasteboard.PasteboardType] {
        Array(Set(super.readablePasteboardTypes + [.png, .tiff, .fileURL]))
    }

    override func paste(_ sender: Any?) {
        guard isEditable else { return }
        if onPasteImage?(.general) == true { return }
        super.paste(sender)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
        if modifiers == .command,
            event.charactersIgnoringModifiers?.lowercased() == "v" || event.keyCode == 9
        {
            guard isEditable else { return false }
            paste(nil)
            return true
        }
        if event.charactersIgnoringModifiers?.lowercased() == "z" {
            if modifiers == .command {
                undo(nil)
                return true
            }
            if modifiers == [.command, .shift] {
                redo(nil)
                return true
            }
        }
        if modifiers == .command && (event.keyCode == 36 || event.keyCode == 76) {
            onAnalyze?()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}
