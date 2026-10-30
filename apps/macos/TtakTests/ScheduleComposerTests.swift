import AppKit
import ImageIO
import Testing
import UniformTypeIdentifiers

@testable import Ttak

@MainActor
struct ScheduleComposerTests {
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

}
