import AppKit
import ImageIO
import UniformTypeIdentifiers

struct ImageAttachment: Equatable {
    static let supportedTypes: [UTType] = [.png, .jpeg, .heic, .tiff]

    let id = UUID()
    let data: Data
    let name: String
    let preview: CGImage

    init?(data: Data, name: String) {
        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let identifier = CGImageSourceGetType(source),
            Self.supportedTypes.contains(where: { $0.identifier == identifier as String }),
            let preview = CGImageSourceCreateThumbnailAtIndex(
                source, 0,
                [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: 128,
                    kCGImageSourceShouldCacheImmediately: true,
                ] as CFDictionary)
        else { return nil }
        self.data = data
        self.name = name
        self.preview = preview
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
}

enum ImageAttachmentImport {
    enum Failure: LocalizedError {
        case unreadable
        case unsupported

        var errorDescription: String? {
            switch self {
            case .unreadable: "이미지를 읽지 못했어요. 기존 입력은 유지돼요."
            case .unsupported: "읽을 수 있는 PNG, JPEG, HEIC, TIFF 이미지를 첨부해 주세요."
            }
        }
    }

    static func readFile(at url: URL) throws -> ImageAttachment {
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }
        let data: Data
        do { data = try Data(contentsOf: url) } catch {
            throw Failure.unreadable
        }
        guard let attachment = ImageAttachment(data: data, name: url.lastPathComponent) else {
            throw Failure.unsupported
        }
        return attachment
    }

    @MainActor
    static func readPasteboard(_ pasteboard: NSPasteboard) throws -> ImageAttachment? {
        let types = ImageAttachment.supportedTypes.map {
            NSPasteboard.PasteboardType($0.identifier)
        }
        // Image representations take precedence over accompanying names or URLs.
        // Pure text falls through to the native text editor.
        if let type = pasteboard.availableType(from: types) {
            guard let data = pasteboard.data(forType: type) else { throw Failure.unreadable }
            guard let attachment = ImageAttachment(data: data, name: "붙여넣은 이미지") else {
                throw Failure.unsupported
            }
            return attachment
        }
        if let urls = pasteboard.readObjects(
            forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
            let url = urls.first,
            let type = UTType(filenameExtension: url.pathExtension), type.conforms(to: .image)
        {
            return try readFile(at: url)
        }
        if pasteboard.types?.contains(where: {
            UTType($0.rawValue)?.conforms(to: .image) == true
        }) == true {
            throw Failure.unsupported
        }
        return nil
    }
}
