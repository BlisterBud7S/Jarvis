import UIKit
import AVFoundation
import Vision

class QRScanner {

    func scanQRFromImage(_ image: UIImage) async -> String? {
        guard let cgImage = image.cgImage else { return nil }

        return await withCheckedContinuation { continuation in
            let request = VNDetectBarcodesRequest { request, error in
                guard error == nil,
                      let results = request.results as? [VNBarcodeObservation],
                      let first = results.first,
                      let payload = first.payloadStringValue else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: payload)
            }
            request.symbologies = [.qr, .ean13, .ean8, .code128, .code39, .upce, .pdf417, .aztec, .dataMatrix]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }
}
