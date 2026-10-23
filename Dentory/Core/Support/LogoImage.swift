import UIKit

/// The clinic logo as stored: centre-cropped to a square and re-encoded as JPEG (f3 "square works best").
nonisolated enum LogoImage {
    static let maxSide: CGFloat = 512
    static let contentType = "image/jpeg"

    /// Nil when the data is not an image.
    static func squareJPEG(from data: Data, maxSide: CGFloat = LogoImage.maxSide) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let side = min(image.size.width, image.size.height, maxSide)
        guard side > 0 else { return nil }
        let scale = side / min(image.size.width, image.size.height)
        let drawn = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let origin = CGPoint(x: (side - drawn.width) / 2, y: (side - drawn.height) / 2)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format)
        let square = renderer.image { _ in
            image.draw(in: CGRect(origin: origin, size: drawn))
        }
        return square.jpegData(compressionQuality: 0.85)
    }
}
