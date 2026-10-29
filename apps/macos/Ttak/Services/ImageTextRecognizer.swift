import Foundation
import Vision

protocol ImageTextRecognizing: Sendable {
    func recognize(data: Data) async throws -> String
}

enum ImageRecognitionFailure: LocalizedError {
    case noText
    case unsupportedKorean

    var errorDescription: String? {
        switch self {
        case .noText: "이미지에서 읽을 수 있는 글자를 찾지 못했어요."
        case .unsupportedKorean: "이 환경의 OCR은 한국어 인식을 지원하지 않아요."
        }
    }
}

struct ImageTextRecognizer: ImageTextRecognizing {
    func recognize(data: Data) async throws -> String {
        // Vision's synchronous work runs on a separate task, never in the UI actor.
        let work = Task.detached(priority: .userInitiated) {
            try Task.checkCancellation()
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            let languages = try request.supportedRecognitionLanguages()
            guard languages.contains("ko-KR") else {
                throw ImageRecognitionFailure.unsupportedKorean
            }
            request.recognitionLanguages = ["ko-KR", "en-US"].filter(languages.contains)
            request.usesLanguageCorrection = true
            let handler = VNImageRequestHandler(data: data, options: [:])
            try handler.perform([request])
            try Task.checkCancellation()
            let text = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: "\n")
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ImageRecognitionFailure.noText
            }
            return text
        }
        return try await withTaskCancellationHandler {
            try await work.value
        } onCancel: {
            work.cancel()
        }
    }
}
