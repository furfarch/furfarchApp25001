import Foundation
import Vision
import UIKit
import AVFoundation

struct PlateRecognitionResult {
    let rawCandidates: [String]
    let bestMatch: String?
}

enum PlateRecognizer {
    // Adjust regex to your region's plate format as needed
    private static let plateRegex = try! NSRegularExpression(pattern: "^[A-Z0-9\\-]{5,10}$", options: [])

    static func recognize(from image: UIImage, completion: @escaping (PlateRecognitionResult) -> Void) {
        let request = VNRecognizeTextRequest { req, err in
            if let err = err {
                print("DEBUG: VNRecognizeTextRequest error: \(err)")
            }
            let observations = (req.results as? [VNRecognizedTextObservation]) ?? []
            print("DEBUG: PlateRecognizer found observations: \(observations.count)")

            let candidateTuples: [(string: String, confidence: Float)] = observations.flatMap { obs in
                obs.topCandidates(3).map { ($0.string, $0.confidence) }
            }
            print("DEBUG: PlateRecognizer raw candidates: \(candidateTuples.map { "\($0.string) (\($0.confidence))" })")

            let normalizedConservative = candidateTuples.map { (s, c) in (normalizePlateCandidate(s, aggressiveMap: false), c) }
            let normalizedAggressive = candidateTuples.map { (s, c) in (normalizePlateCandidate(s, aggressiveMap: true), c) }

            func bestMatch(from list: [(string: String, confidence: Float)]) -> (String, Float)? {
                let valid = list.filter { isPlateLike($0.string) }
                return valid.max(by: { $0.confidence < $1.confidence })
            }

            let bestA = bestMatch(from: normalizedConservative)
            let bestB = bestMatch(from: normalizedAggressive)
            let best = [bestA, bestB].compactMap { $0 }.max(by: { $0.1 < $1.1 })?.0

            let raw = Array(Set(normalizedConservative.map { $0.0 } + normalizedAggressive.map { $0.0 }))

            DispatchQueue.main.async {
                completion(.init(rawCandidates: raw, bestMatch: best))
            }
        }

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en-US", "en-GB", "de-DE", "fr-FR"]

        if let cgImage = image.cgImage {
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do { try handler.perform([request]) } catch {
                    print("DEBUG: VNImageRequestHandler.perform failed: \(error)")
                    DispatchQueue.main.async { completion(.init(rawCandidates: [], bestMatch: nil)) }
                }
            }
            return
        }

        if let ci = CIImage(image: image) {
            let handler = VNImageRequestHandler(ciImage: ci, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do { try handler.perform([request]) } catch {
                    print("DEBUG: VNImageRequestHandler.perform failed (CIImage): \(error)")
                    DispatchQueue.main.async { completion(.init(rawCandidates: [], bestMatch: nil)) }
                }
            }
            return
        }

        print("DEBUG: PlateRecognizer cannot create CGImage or CIImage from UIImage")
        DispatchQueue.main.async { completion(.init(rawCandidates: [], bestMatch: nil)) }
    }

    static func recognize(from cgImage: CGImage, completion: @escaping (PlateRecognitionResult) -> Void) {
        let uiImage = UIImage(cgImage: cgImage)
        recognize(from: uiImage, completion: completion)
    }

    static func recognize(from ciImage: CIImage, completion: @escaping (PlateRecognitionResult) -> Void) {
        let context = CIContext(options: nil)
        if let cg = context.createCGImage(ciImage, from: ciImage.extent) {
            recognize(from: cg, completion: completion)
        } else {
            DispatchQueue.main.async { completion(.init(rawCandidates: [], bestMatch: nil)) }
        }
    }

    static func recognize(from pixelBuffer: CVPixelBuffer, completion: @escaping (PlateRecognitionResult) -> Void) {
        let request = VNRecognizeTextRequest { req, err in
            if let err = err { print("DEBUG: VNRecognizeTextRequest error: \(err)") }
            let observations = (req.results as? [VNRecognizedTextObservation]) ?? []

            let candidateTuples: [(string: String, confidence: Float)] = observations.flatMap { obs in
                obs.topCandidates(3).map { ($0.string, $0.confidence) }
            }
            let normalizedConservative = candidateTuples.map { (s, c) in (normalizePlateCandidate(s, aggressiveMap: false), c) }
            let normalizedAggressive = candidateTuples.map { (s, c) in (normalizePlateCandidate(s, aggressiveMap: true), c) }

            func bestMatch(from list: [(string: String, confidence: Float)]) -> (String, Float)? {
                let valid = list.filter { isPlateLike($0.string) }
                return valid.max(by: { $0.confidence < $1.confidence })
            }
            let bestA = bestMatch(from: normalizedConservative)
            let bestB = bestMatch(from: normalizedAggressive)
            let best = [bestA, bestB].compactMap { $0 }.max(by: { $0.1 < $1.1 })?.0
            let raw = Array(Set(normalizedConservative.map { $0.0 } + normalizedAggressive.map { $0.0 }))
            DispatchQueue.main.async { completion(.init(rawCandidates: raw, bestMatch: best)) }
        }

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en-US", "en-GB", "de-DE", "fr-FR"]

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            do { try handler.perform([request]) } catch {
                print("DEBUG: VNImageRequestHandler.perform failed (pixelBuffer): \(error)")
                DispatchQueue.main.async { completion(.init(rawCandidates: [], bestMatch: nil)) }
            }
        }
    }

    static func recognize(from sampleBuffer: CMSampleBuffer, completion: @escaping (PlateRecognitionResult) -> Void) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            DispatchQueue.main.async { completion(.init(rawCandidates: [], bestMatch: nil)) }
            return
        }
        recognize(from: pixelBuffer, completion: completion)
    }

    private static func normalizePlateCandidate(_ text: String, aggressiveMap: Bool) -> String {
        var t = text.uppercased()
        t = t.replacingOccurrences(of: " ", with: "")
        t = t.replacingOccurrences(of: "·", with: "")
        t = t.replacingOccurrences(of: "—", with: "-")
        t = t.replacingOccurrences(of: "–", with: "-")

        if aggressiveMap {
            t = t.map { ch -> Character in
                switch ch {
                case "O": return "0"
                case "I": return "1"
                case "S": return "5"
                case "B": return "8"
                default:  return ch
                }
            }.reduce(into: "", { $0.append($1) })
        }

        return t
    }

    private static func isPlateLike(_ text: String) -> Bool {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return plateRegex.firstMatch(in: text, options: [], range: range) != nil
    }

    #if canImport(UIKit)
    /// Captures a snapshot of the key window/screen and runs recognition on it.
    static func recognizeFromScreen(completion: @escaping (PlateRecognitionResult) -> Void) {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first,
              let window = windowScene.keyWindow ?? windowScene.windows.first(where: { $0.isKeyWindow }) ?? windowScene.windows.first
        else {
            print("DEBUG: No key window available for screen snapshot")
            completion(.init(rawCandidates: [], bestMatch: nil))
            return
        }

        let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
        let image = renderer.image { ctx in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: false)
        }
        recognize(from: image, completion: completion)
    }
    #endif
}

