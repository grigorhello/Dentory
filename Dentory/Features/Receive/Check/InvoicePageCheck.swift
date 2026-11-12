import CoreGraphics
import Foundation
import ImageIO
import Vision

/// Whether a captured page can be read, checked on the device before the invoice is uploaded (MS-163), off the main
/// actor like `InvoiceCapture`: too dark when its mean luminance is low, hard to read when Vision makes out too few
/// words. It leans towards passing, since a missed bad photo costs one failed reading and a false alarm a tap every
/// time; anything that keeps the check from running passes the page. The thresholds come from `InvoicePageCheckTests`,
/// which measure them on a photo of the sample invoice and print what they measured (the PR of MS-163 has the table).
nonisolated enum InvoicePageCheck {
    /// The page is checked at this long edge at most: about what the invoice reader looks at (the Claude API scales an
    /// image down to 1,568 pixels on its long edge), so a page passes when the reader can make it out, and the check
    /// stays quick on a page of several megapixels.
    static let checkedPixelLength = 1_568

    /// Below this mean luminance (0 black to 1 white) the page is too dark.
    static let darkLuminance = 0.2

    /// The long edge of the thumbnail the luminance is averaged over.
    static let luminancePixelLength = 64

    /// A word counts when its line's top candidate is at least this confident (Vision's accurate recognizer answers
    /// 0.3, 0.5 or 1 on these pages, and a line it doubts most is still a line a person can read).
    static let confidenceFloor: Float = 0.3

    /// Fewer readable words than this and the page is hard to read. The sample invoice's photo gives about 220 sharp,
    /// 36 under a blur a person can still mostly read, and 6 or fewer once the line items are gone.
    static let minimumWords = 15

    /// One line of text Vision found: its words and how sure it was of them.
    nonisolated struct RecognizedLine: Equatable, Sendable {
        let words: Int
        let confidence: Float
    }

    /// What makes a JPEG page unreadable, or nil.
    @concurrent
    static func problem(inJPEG data: Data) async -> InvoicePageProblem? {
        guard let image = checkedImage(from: data) else { return nil }
        return problem(in: image)
    }

    /// Too dark first, which needs no text recognition; then too few readable words. Vision's fast recognizer reads
    /// a sharp page in a fraction of a second but gives up on a slight blur a person still reads, so only a page it
    /// reads too little of goes on to the accurate recognizer, which decides. A Vision error passes the page.
    static func problem(in image: CGImage) -> InvoicePageProblem? {
        if let luminance = meanLuminance(of: image), luminance < darkLuminance {
            return .dark
        }
        guard let quick = try? recognizedLines(in: image, level: .fast) else { return nil }
        guard readableWords(in: quick) < minimumWords else { return nil }
        guard let careful = try? recognizedLines(in: image, level: .accurate) else { return nil }
        return readableWords(in: careful) < minimumWords ? .blurry : nil
    }

    /// The page decoded upright at `checkedPixelLength` on its long edge at most.
    static func checkedImage(from data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: checkedPixelLength
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    /// The mean gray level of a small grayscale thumbnail, from 0 (black) to 1 (white).
    static func meanLuminance(of image: CGImage) -> Double? {
        let longEdge = max(image.width, image.height)
        guard longEdge > 0 else { return nil }
        let scale = Double(luminancePixelLength) / Double(longEdge)
        let width = max(1, Int((Double(image.width) * scale).rounded()))
        let height = max(1, Int((Double(image.height) * scale).rounded()))
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }
        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let data = context.data else { return nil }
        let bytesPerRow = context.bytesPerRow
        let pixels = data.bindMemory(to: UInt8.self, capacity: bytesPerRow * height)
        var total = 0
        for row in 0..<height {
            for column in 0..<width {
                total += Int(pixels[row * bytesPerRow + column])
            }
        }
        return Double(total) / Double(width * height) / 255
    }

    /// The lines of text Vision recognizes on the page at `level`.
    static func recognizedLines(in image: CGImage, level: VNRequestTextRecognitionLevel) throws -> [RecognizedLine] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = level
        try VNImageRequestHandler(cgImage: image).perform([request])
        return (request.results ?? []).compactMap { observation in
            guard let top = observation.topCandidates(1).first else { return nil }
            return RecognizedLine(
                words: top.string.split(whereSeparator: \.isWhitespace).count, confidence: top.confidence
            )
        }
    }

    /// The words on lines at least `floor` confident.
    static func readableWords(in lines: [RecognizedLine], floor: Float = confidenceFloor) -> Int {
        lines.filter { $0.confidence >= floor }.reduce(0) { $0 + $1.words }
    }
}
