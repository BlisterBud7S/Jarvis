import UIKit

class ScreenCaptureService {

    func captureScreen() -> UIImage? {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }) else {
            return nil
        }

        let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
        return renderer.image { context in
            window.layer.render(in: context.cgContext)
        }
    }

    func captureAndEncode(quality: CGFloat = 0.7) -> String? {
        guard let image = captureScreen() else { return nil }
        return image.jpegData(compressionQuality: quality)?.base64EncodedString()
    }
}
