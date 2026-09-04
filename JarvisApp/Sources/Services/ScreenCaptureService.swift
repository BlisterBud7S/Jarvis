import UIKit
import ReplayKit

class ScreenCaptureService {

    func captureScreen() -> UIImage? {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }) else {
            return nil
        }

        let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
        return renderer.image { ctx in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
    }

    func captureAndEncode(quality: CGFloat = 0.8) -> String? {
        guard let image = captureScreen() else { return nil }
        return image.jpegData(compressionQuality: quality)?.base64EncodedString()
    }

    func captureFullScreen() -> UIImage? {
        let screens = UIScreen.main
        let bounds = screens.bounds
        let scale = screens.scale
        let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)

        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        defer { UIGraphicsEndImageContext() }

        guard let context = UIGraphicsGetCurrentContext() else { return nil }

        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                context.saveGState()
                context.translateBy(x: window.center.x, y: window.center.y)
                context.concatenate(window.transform)
                context.translateBy(
                    x: -window.bounds.size.width * window.layer.anchorPoint.x,
                    y: -window.bounds.size.height * window.layer.anchorPoint.y
                )
                window.layer.render(in: context)
                context.restoreGState()
            }
        }

        return UIGraphicsGetImageFromCurrentImageContext()
    }
}
