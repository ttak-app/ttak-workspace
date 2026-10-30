import AppKit
import ImageIO
import SwiftUI
import Testing
import UniformTypeIdentifiers

@testable import Ttak

@MainActor
struct ScheduleComposerTests {
    @Test("Command V는 이미지 붙여넣기 경로를 직접 호출하고 비활성 입력에서는 소비하지 않는다")
    func imagePasteShortcut() throws {
        let editor = ComposerNativeTextView()
        editor.isEditable = true
        var pasteCount = 0
        editor.onPasteImage = { _ in
            pasteCount += 1
            return true
        }
        let event = try #require(
            NSEvent.keyEvent(
                with: .keyDown, location: .zero, modifierFlags: .command,
                timestamp: 0, windowNumber: 0, context: nil,
                characters: "v", charactersIgnoringModifiers: "v", isARepeat: false, keyCode: 9))
        #expect(editor.performKeyEquivalent(with: event))
        #expect(pasteCount == 1)
        editor.isEditable = false
        #expect(!editor.performKeyEquivalent(with: event))
        #expect(pasteCount == 1)
    }

    @Test("같은 물리 키 위치의 다른 문자는 이미지 붙여넣기를 호출하지 않는다")
    func nonPasteShortcut() throws {
        let editor = ComposerNativeTextView()
        var pasteCount = 0
        editor.onPasteImage = { _ in
            pasteCount += 1
            return true
        }
        let event = try #require(
            NSEvent.keyEvent(
                with: .keyDown, location: .zero, modifierFlags: .command,
                timestamp: 0, windowNumber: 0, context: nil,
                characters: "x", charactersIgnoringModifiers: "x", isARepeat: false, keyCode: 9))
        _ = editor.performKeyEquivalent(with: event)
        #expect(pasteCount == 0)
    }

    @Test("실제 Composer에서 Command V는 PNG를 첨부 상태에 저장하고 텍스트를 보존한다")
    func composerImagePasteIntegration() throws {
        let bitmap = try #require(
            NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: 2, pixelsHigh: 2,
                bitsPerSample: 8, samplesPerPixel: 3, hasAlpha: false,
                isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        let png = try #require(bitmap.representation(using: .png, properties: [:]))
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        pasteboard.setData(png, forType: .png)
        var text = "기존 입력"
        var attachment: ImageAttachment?
        let host = NSHostingView(
            rootView: ScheduleComposer(
                text: Binding(get: { text }, set: { text = $0 }),
                attachment: Binding(get: { attachment }, set: { attachment = $0 }),
                canAnalyze: true, isAnalyzing: false, isEnabled: true, onAnalyze: {}))
        host.frame = NSRect(x: 0, y: 0, width: 500, height: 300)
        host.layoutSubtreeIfNeeded()
        func findEditor(in view: NSView) -> ComposerNativeTextView? {
            if let editor = view as? ComposerNativeTextView { return editor }
            for child in view.subviews {
                if let editor = findEditor(in: child) { return editor }
            }
            return nil
        }
        let editor = try #require(findEditor(in: host))
        editor.imagePasteboard = pasteboard
        let event = try #require(
            NSEvent.keyEvent(
                with: .keyDown, location: .zero, modifierFlags: .command,
                timestamp: 0, windowNumber: 0, context: nil,
                characters: "v", charactersIgnoringModifiers: "v", isARepeat: false, keyCode: 9))
        #expect(editor.performKeyEquivalent(with: event))
        let pasted = try #require(attachment)
        #expect(pasted.data == png)
        #expect(pasted.name == "붙여넣은 이미지")
        #expect(text == "기존 입력")
    }

    @Test("일반 텍스트 편집기도 스크린샷 PNG와 TIFF 붙여넣기를 허용한다")
    func screenshotPasteboardTypes() {
        let editor = ComposerNativeTextView()
        editor.isRichText = false
        #expect(editor.readablePasteboardTypes.contains(.png))
        #expect(editor.readablePasteboardTypes.contains(.tiff))
    }

    @Test("첨부 가능한 PNG, JPEG, HEIC, TIFF는 원본 데이터와 이름을 보존한다")
    func supportedImageFormats() throws {
        let bitmap = try #require(
            NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: 2, pixelsHigh: 2,
                bitsPerSample: 8, samplesPerPixel: 3, hasAlpha: false,
                isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        for format in [NSBitmapImageRep.FileType.png, .jpeg, .tiff] {
            let data = try #require(bitmap.representation(using: format, properties: [:]))
            let attachment = try #require(ImageAttachment(data: data, name: "합성 이미지"))
            #expect(attachment.data == data)
            #expect(attachment.name == "합성 이미지")
        }
        let image = try #require(bitmap.cgImage)
        let encodedHEIC = NSMutableData()
        let destination = try #require(
            CGImageDestinationCreateWithData(
                encodedHEIC, UTType.heic.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        #expect(ImageAttachment(data: encodedHEIC as Data, name: "합성.heic") != nil)
    }

    @Test("잘못된 데이터는 첨부 값으로 만들지 않는다")
    func invalidData() {
        #expect(ImageAttachment(data: Data(), name: "empty.png") == nil)
        #expect(ImageAttachment(data: Data("not an image".utf8), name: "fake.png") == nil)
    }

    @Test("확장자가 PNG여도 GIF 데이터는 지원 형식으로 취급하지 않는다")
    func unsupportedFormat() throws {
        let gif = try #require(
            Data(base64Encoded: "R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7"))
        #expect(ImageAttachment(data: gif, name: "renamed.png") == nil)
    }

    @Test("일반 텍스트 클립보드는 이미지 붙여넣기가 소비하지 않는다")
    func textPasteboard() throws {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        pasteboard.setString("내일 오후 3시 회의", forType: .string)
        #expect(try ImageAttachmentImport.readPasteboard(pasteboard) == nil)
    }

    @Test("Finder 이미지 파일 URL 클립보드를 읽는다")
    func fileURLPasteboard() throws {
        let bitmap = try #require(
            NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: 2, pixelsHigh: 2,
                bitsPerSample: 8, samplesPerPixel: 3, hasAlpha: false,
                isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        let data = try #require(bitmap.representation(using: .png, properties: [:]))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID()).png")
        try data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        #expect(pasteboard.writeObjects([url as NSURL]))
        let attachment = try #require(try ImageAttachmentImport.readPasteboard(pasteboard))
        #expect(attachment.data == data)
        #expect(attachment.name == url.lastPathComponent)
    }

    @Test("손상된 이미지 클립보드는 실패로 전달한다")
    func corruptPasteboard() {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        pasteboard.setData(Data("broken".utf8), forType: .png)
        #expect(throws: ImageAttachmentImport.Failure.self) {
            try ImageAttachmentImport.readPasteboard(pasteboard)
        }
    }
    @Test("네이티브 편집기의 실행 취소와 다시 실행은 부모 입력 교체 이후 초기화된다")
    func nativeUndoRedoAndParentReplacement() {
        let editor = ComposerNativeTextView()
        editor.allowsUndo = true
        editor.insertText("합성 회의", replacementRange: NSRange(location: NSNotFound, length: 0))
        #expect(editor.undoManager?.canUndo == true)
        editor.undo(nil)
        #expect(editor.string.isEmpty)
        editor.redo(nil)
        #expect(editor.string == "합성 회의")
        editor.replaceTextFromParent("부모가 바꾼 입력")
        editor.undo(nil)
        #expect(editor.string == "부모가 바꾼 입력")
        #expect(editor.undoManager?.canUndo == false)
        #expect(editor.undoManager?.canRedo == false)
    }

    @Test("한 편집기의 초기화는 다른 편집기의 실행 취소 이력을 지우지 않는다")
    func independentUndoHistories() {
        let first = ComposerNativeTextView()
        let second = ComposerNativeTextView()
        first.allowsUndo = true
        second.allowsUndo = true
        first.insertText("첫 입력", replacementRange: NSRange(location: NSNotFound, length: 0))
        second.insertText("둘째 입력", replacementRange: NSRange(location: NSNotFound, length: 0))
        first.replaceTextFromParent("")
        second.undo(nil)
        #expect(second.string.isEmpty)
        #expect(first.string.isEmpty)
    }

    @Test("편집기의 Command Z와 Command Shift Z가 전용 이력에 연결된다")
    func undoKeyboardShortcuts() throws {
        let editor = ComposerNativeTextView()
        editor.allowsUndo = true
        editor.insertText("키보드 검증", replacementRange: NSRange(location: NSNotFound, length: 0))
        let undoEvent = try #require(
            NSEvent.keyEvent(
                with: .keyDown, location: .zero, modifierFlags: .command,
                timestamp: 0, windowNumber: 0, context: nil, characters: "z",
                charactersIgnoringModifiers: "z", isARepeat: false, keyCode: 6))
        #expect(editor.performKeyEquivalent(with: undoEvent))
        #expect(editor.string.isEmpty)
        let redoEvent = try #require(
            NSEvent.keyEvent(
                with: .keyDown, location: .zero, modifierFlags: [.command, .shift],
                timestamp: 0, windowNumber: 0, context: nil, characters: "Z",
                charactersIgnoringModifiers: "z", isARepeat: false, keyCode: 6))
        #expect(editor.performKeyEquivalent(with: redoEvent))
        #expect(editor.string == "키보드 검증")
    }

    @Test("원본 파일을 덮어쓰거나 지워도 첨부 스냅샷과 미리보기를 유지한다")
    func fileAttachmentSnapshot() throws {
        let data = try pngData()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID()).png")
        defer { try? FileManager.default.removeItem(at: url) }
        try data.write(to: url)
        let attachment = try ImageAttachmentImport.readFile(at: url)
        try Data("overwritten".utf8).write(to: url)
        #expect(attachment.data == data)
        try FileManager.default.removeItem(at: url)
        #expect(attachment.data == data)
        #expect(attachment.preview.width > 0)
        #expect(attachment.preview.height > 0)
    }

    @Test("미리보기는 128px 이하로 생성되고 값 복사에서 첨부 정체성을 유지한다")
    func cachedThumbnailAndIdentity() throws {
        let data = try pngData(width: 512, height: 256)
        let attachment = try #require(ImageAttachment(data: data, name: "wide.png"))
        let copy = attachment
        #expect(attachment.preview.width == 128)
        #expect(attachment.preview.height == 64)
        #expect(copy.preview === attachment.preview)
        #expect(copy == attachment)
        let replacement = try #require(ImageAttachment(data: data, name: "wide.png"))
        #expect(replacement.id != attachment.id)
        #expect(replacement != attachment)
        #expect(attachment.data == data)
    }

    @Test("혼합 클립보드에서는 함께 제공된 문자열보다 이미지 표현이 우선한다")
    func mixedPasteboardPrefersImage() throws {
        let data = try pngData()
        for text in ["poster.png", "https://example.com/poster.png", "내일 오후 3시 회의"] {
            let pasteboard = NSPasteboard.withUniqueName()
            defer { pasteboard.releaseGlobally() }
            #expect(pasteboard.setString(text, forType: .string))
            #expect(pasteboard.setData(data, forType: .png))
            let attachment = try #require(try ImageAttachmentImport.readPasteboard(pasteboard))
            #expect(attachment.data == data)
        }
    }

    @Test("비QWERTY 배열의 Z 문자로 실행 취소하고 QWERTY Z 위치의 W는 소비하지 않는다")
    func undoFollowsKeyboardCharacter() throws {
        let editor = ComposerNativeTextView()
        editor.allowsUndo = true
        editor.insertText("배열 검증", replacementRange: NSRange(location: NSNotFound, length: 0))
        let closeEvent = try #require(
            NSEvent.keyEvent(
                with: .keyDown, location: .zero, modifierFlags: .command,
                timestamp: 0, windowNumber: 0, context: nil, characters: "w",
                charactersIgnoringModifiers: "w", isARepeat: false, keyCode: 6))
        #expect(!editor.performKeyEquivalent(with: closeEvent))
        #expect(editor.string == "배열 검증")
        let undoEvent = try #require(
            NSEvent.keyEvent(
                with: .keyDown, location: .zero, modifierFlags: [.command, .capsLock],
                timestamp: 0, windowNumber: 0, context: nil, characters: "Z",
                charactersIgnoringModifiers: "Z", isARepeat: false, keyCode: 13))
        #expect(editor.performKeyEquivalent(with: undoEvent))
        #expect(editor.string.isEmpty)
        let redoEvent = try #require(
            NSEvent.keyEvent(
                with: .keyDown, location: .zero, modifierFlags: [.command, .shift],
                timestamp: 0, windowNumber: 0, context: nil, characters: "Z",
                charactersIgnoringModifiers: "z", isARepeat: false, keyCode: 13))
        #expect(editor.performKeyEquivalent(with: redoEvent))
        #expect(editor.string == "배열 검증")
    }

    private func pngData(width: Int = 32, height: Int = 16) throws -> Data {
        let bitmap = try #require(
            NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
                bitsPerSample: 8, samplesPerPixel: 3, hasAlpha: false,
                isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        let pixels = try #require(bitmap.bitmapData)
        pixels.initialize(repeating: 0x88, count: bitmap.bytesPerRow * height)
        return try #require(bitmap.representation(using: .png, properties: [:]))
    }

}
