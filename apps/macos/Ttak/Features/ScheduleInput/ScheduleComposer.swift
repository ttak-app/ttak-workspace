import AppKit
import SwiftUI

struct ScheduleComposer: View {
    @Binding var text: String
    @Binding var attachment: ImageAttachment?
    let canAnalyze: Bool
    let isAnalyzing: Bool
    let isEnabled: Bool
    let onAnalyze: () -> Void

    @State private var attachmentError: String?

    private var canRequestAnalysis: Bool {
        isEnabled && !isAnalyzing && canAnalyze
            && (attachment != nil || !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let attachment, let image = NSImage(data: attachment.data) {
                HStack(spacing: 12) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 84, height: 72)
                        .accessibilityLabel("첨부 이미지 미리보기")
                    Text(attachment.name)
                        .font(.caption)
                        .lineLimit(2)
                    Spacer(minLength: 8)
                    Button("삭제", systemImage: "xmark") {
                        self.attachment = nil
                        attachmentError = nil
                    }
                    .disabled(!isEnabled)
                    .accessibilityLabel("첨부 이미지 삭제")
                }
                .padding(10)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            }

            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(attachment == nil ? "일정을 말하듯 적어주세요" : "이미지에 대한 설명을 덧붙여도 좋아요")
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 5)
                        .padding(.top, 8)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                ComposerTextEditor(
                    text: $text, isEnabled: isEnabled,
                    onPasteImage: pasteImage, onAnalyze: requestAnalysis
                )
                .frame(height: 108)
            }

            if let attachmentError {
                Text(attachmentError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .accessibilityLabel("첨부 오류: \(attachmentError)")
            }

            HStack {
                Button("이미지 첨부", systemImage: "plus") { selectImage() }
                    .disabled(!isEnabled)
                    .help("PNG, JPEG, HEIC, TIFF 이미지 한 장을 선택하거나 입력창에서 ⌘V로 붙여넣으세요.")
                Spacer()
                if isAnalyzing {
                    ProgressView().controlSize(.small)
                    Text("분석 중")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Button("분석", systemImage: "arrow.up") { requestAnalysis() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canRequestAnalysis)
                    .help("⌘Enter로 분석")
            }
        }
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
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

private struct ComposerTextEditor: NSViewRepresentable {
    @Binding var text: String
    let isEnabled: Bool
    let onPasteImage: (NSPasteboard) -> Bool
    let onAnalyze: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let editor = ComposerNativeTextView()
        editor.delegate = context.coordinator
        editor.isRichText = false
        editor.importsGraphics = false
        editor.drawsBackground = false
        editor.font = .preferredFont(forTextStyle: .body)
        editor.textColor = .labelColor
        editor.textContainerInset = NSSize(width: 0, height: 8)
        editor.isHorizontallyResizable = false
        editor.isVerticallyResizable = true
        editor.minSize = NSSize(width: 0, height: 108)
        editor.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        editor.autoresizingMask = [.width]
        editor.textContainer?.widthTracksTextView = true
        editor.textContainer?.containerSize = NSSize(
            width: 0, height: CGFloat.greatestFiniteMagnitude)
        editor.setAccessibilityLabel("일정 또는 이미지 보조 설명")
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.documentView = editor
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let editor = scroll.documentView as? ComposerNativeTextView else { return }
        context.coordinator.parent = self
        if editor.string != text { editor.string = text }
        editor.isEditable = isEnabled
        editor.textColor = isEnabled ? .labelColor : .disabledControlTextColor
        editor.onPasteImage = onPasteImage
        editor.onAnalyze = onAnalyze
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ComposerTextEditor

        init(_ parent: ComposerTextEditor) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let editor = notification.object as? NSTextView else { return }
            parent.text = editor.string
        }
    }
}

private final class ComposerNativeTextView: NSTextView {
    var onPasteImage: ((NSPasteboard) -> Bool)?
    var onAnalyze: (() -> Void)?

    override func paste(_ sender: Any?) {
        guard isEditable else { return }
        if onPasteImage?(.general) == true { return }
        super.paste(sender)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if modifiers == .command && (event.keyCode == 36 || event.keyCode == 76) {
            onAnalyze?()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}
