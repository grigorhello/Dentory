import Testing
import UIKit
@testable import Dentory

struct LogoImageTests {
    private func png(width: CGFloat, height: CGFloat) -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format)
        let image = renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        return image.pngData() ?? Data()
    }

    @Test func cropsToTheShorterSideAndCapsTheSize() throws {
        let wide = try #require(LogoImage.squareJPEG(from: png(width: 400, height: 200)))
        let wideImage = try #require(UIImage(data: wide))
        #expect(wideImage.size == CGSize(width: 200, height: 200))

        let huge = try #require(LogoImage.squareJPEG(from: png(width: 2000, height: 3000), maxSide: 512))
        let hugeImage = try #require(UIImage(data: huge))
        #expect(hugeImage.size == CGSize(width: 512, height: 512))
    }

    @Test func refusesNonImages() {
        #expect(LogoImage.squareJPEG(from: Data("not an image".utf8)) == nil)
    }
}
