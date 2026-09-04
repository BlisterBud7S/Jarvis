import UIKit
import Vision

struct ScreenElement: Codable {
    let text: String
    let x: Double
    let y: Double
    let width: Double
    let height: Double
    let confidence: Float
    let type: ElementType

    enum ElementType: String, Codable {
        case text, button, field, link, icon, unknown
    }

    var centerX: Double { x + width / 2 }
    var centerY: Double { y + height / 2 }
}

class ScreenReader {

    func readScreen(_ image: UIImage) async -> ScreenAnalysis {
        async let texts = recognizeText(in: image)
        async let elements = detectElements(in: image)

        let t = await texts
        let e = await elements

        return ScreenAnalysis(
            fullText: t.map { $0.text }.joined(separator: "\n"),
            elements: t + e,
            screenWidth: Double(image.size.width),
            screenHeight: Double(image.size.height)
        )
    }

    private func recognizeText(in image: UIImage) async -> [ScreenElement] {
        guard let cgImage = image.cgImage else { return [] }

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard error == nil,
                      let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                let imageHeight = Double(cgImage.height)
                let imageWidth = Double(cgImage.width)

                let elements = observations.compactMap { obs -> ScreenElement? in
                    guard let candidate = obs.topCandidates(1).first else { return nil }

                    let box = obs.boundingBox
                    return ScreenElement(
                        text: candidate.string,
                        x: box.origin.x * imageWidth,
                        y: (1 - box.origin.y - box.height) * imageHeight,
                        width: box.width * imageWidth,
                        height: box.height * imageHeight,
                        confidence: candidate.confidence,
                        type: classifyText(candidate.string)
                    )
                }

                continuation.resume(returning: elements)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }

    private func detectElements(in image: UIImage) async -> [ScreenElement] {
        guard let cgImage = image.cgImage else { return [] }

        return await withCheckedContinuation { continuation in
            let request = VNDetectRectanglesRequest { request, error in
                guard error == nil,
                      let observations = request.results as? [VNRectangleObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                let imageHeight = Double(cgImage.height)
                let imageWidth = Double(cgImage.width)

                let elements = observations.map { obs -> ScreenElement in
                    let box = obs.boundingBox
                    return ScreenElement(
                        text: "",
                        x: box.origin.x * imageWidth,
                        y: (1 - box.origin.y - box.height) * imageHeight,
                        width: box.width * imageWidth,
                        height: box.height * imageHeight,
                        confidence: obs.confidence,
                        type: .button
                    )
                }

                continuation.resume(returning: elements)
            }

            request.minimumSize = 0.02
            request.maximumObservations = 30
            request.minimumConfidence = 0.5

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }

    private func classifyText(_ text: String) -> ScreenElement.ElementType {
        let lower = text.lowercased()

        // Common button labels
        let buttonWords = ["ok", "cancel", "done", "save", "send", "delete", "edit",
                          "share", "next", "back", "submit", "continue", "confirm",
                          "open", "close", "yes", "no", "allow", "deny", "accept",
                          "decline", "sign in", "log in", "sign up", "search",
                          "tap", "press", "click", "start", "stop", "play", "pause"]
        if buttonWords.contains(lower) || buttonWords.contains(where: { lower == $0 }) {
            return .button
        }

        // URLs
        if lower.contains("http") || lower.contains("www.") || lower.contains(".com") {
            return .link
        }

        return .text
    }

    func findElement(matching query: String, in analysis: ScreenAnalysis) -> ScreenElement? {
        let lower = query.lowercased()

        // Exact match first
        if let exact = analysis.elements.first(where: { $0.text.lowercased() == lower }) {
            return exact
        }

        // Contains match
        if let partial = analysis.elements.first(where: { $0.text.lowercased().contains(lower) }) {
            return partial
        }

        // Fuzzy match
        return analysis.elements
            .filter { !$0.text.isEmpty }
            .min(by: { levenshteinDistance($0.text.lowercased(), lower) < levenshteinDistance($1.text.lowercased(), lower) })
    }

    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let a = Array(s1)
        let b = Array(s2)
        var dist = [[Int]](repeating: [Int](repeating: 0, count: b.count + 1), count: a.count + 1)

        for i in 0...a.count { dist[i][0] = i }
        for j in 0...b.count { dist[0][j] = j }

        for i in 1...a.count {
            for j in 1...b.count {
                if a[i-1] == b[j-1] {
                    dist[i][j] = dist[i-1][j-1]
                } else {
                    dist[i][j] = min(dist[i-1][j] + 1, dist[i][j-1] + 1, dist[i-1][j-1] + 1)
                }
            }
        }
        return dist[a.count][b.count]
    }
}

struct ScreenAnalysis: Codable {
    let fullText: String
    let elements: [ScreenElement]
    let screenWidth: Double
    let screenHeight: Double

    var summary: String {
        let textElements = elements.filter { !$0.text.isEmpty }
        let buttons = textElements.filter { $0.type == .button }.map { $0.text }
        let links = textElements.filter { $0.type == .link }.map { $0.text }
        let texts = textElements.filter { $0.type == .text }.prefix(20).map { $0.text }

        var summary = "Screen content:\n"
        if !buttons.isEmpty { summary += "Buttons: \(buttons.joined(separator: ", "))\n" }
        if !links.isEmpty { summary += "Links: \(links.joined(separator: ", "))\n" }
        if !texts.isEmpty { summary += "Text: \(texts.joined(separator: " | "))\n" }
        return summary
    }

    func toJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(self) else { return "{}" }
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}
