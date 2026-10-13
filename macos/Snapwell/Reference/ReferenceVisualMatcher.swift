import Foundation
import Vision
import ImageIO
import CryptoKit

/// On-device image comparison: no remote calls, no inferred subjects or timecodes.
actor ReferenceVisualMatcher {
    private var prints: [String: VNFeaturePrintObservation] = [:]
    private func feature(_ data: Data) throws -> VNFeaturePrintObservation {
        let key = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        if let value = prints[key] { return value }
        guard data.count <= 20 * 1024 * 1024, let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil), image.width <= 12000, image.height <= 12000 else {
            throw ReferenceError.message("Image preview is invalid or too large for comparison.")
        }
        let request = VNGenerateImageFeaturePrintRequest()
        request.revision = VNGenerateImageFeaturePrintRequestRevision2
        // Normalize preview geometry so letterbox padding does not dominate different reference aspect ratios.
        request.imageCropAndScaleOption = .scaleFill
        try VNImageRequestHandler(cgImage: image).perform([request])
        guard let observation = request.results?.first as? VNFeaturePrintObservation else { throw ReferenceError.message("Visual comparison did not produce a feature print.") }
        if prints.count >= 128 { prints.removeAll(keepingCapacity: true) }
        prints[key] = observation; return observation
    }
    func distance(reference: Data, candidate: Data) throws -> Double {
        let a = try feature(reference), b = try feature(candidate)
        var distance: Float = 0; try a.computeDistance(&distance, to: b)
        guard distance.isFinite, distance >= 0 else { throw ReferenceError.message("Visual comparison returned an invalid distance.") }
        return Double(distance)
    }
}
