import CoreImage
import Foundation
import Testing
import Vision
@testable import Dentory

/// MS-163: the page check's thresholds, measured on a photo of the sample invoice (`docs/demo`, scaled to the check's
/// 1,568 pixels) and variants made from it here. Sharp passes; a Gaussian blur a person can still mostly read passes,
/// one that hides the line items is hard to read; a dark exposure is too dark; a blank page is hard to read. The
/// first test prints what it measured (lines starting `MS-163`), which sets the thresholds in `InvoicePageCheck`.
@Suite(.serialized)
struct InvoicePageCheckTests {
    private final class BundleToken {}

    /// The fixture's long edge over the original photo's 2,400 pixels: a blur radius on the original, times this, is
    /// the same blur on the fixture.
    private static let fixtureScale = Double(InvoicePageCheck.checkedPixelLength) / 2_400

    private static let context = CIContext()

    private static func fixtureData() throws -> Data {
        let bundle = Bundle(for: BundleToken.self)
        let url = try #require(bundle.url(forResource: "northbridge-invoice-photo", withExtension: "jpg"))
        return try Data(contentsOf: url)
    }

    private static func fixture() throws -> CGImage {
        let data = try fixtureData()
        return try #require(InvoicePageCheck.checkedImage(from: data))
    }

    /// Gaussian blur of `radius` pixels on the original photo's scale.
    private static func blurred(_ image: CGImage, originalRadius radius: Double) throws -> CGImage {
        let input = CIImage(cgImage: image)
        let output = input.clampedToExtent()
            .applyingGaussianBlur(sigma: radius * fixtureScale)
            .cropped(to: input.extent)
        return try #require(context.createCGImage(output, from: input.extent))
    }

    /// The photo taken `ev` stops darker.
    private static func darkened(_ image: CGImage, ev: Double) throws -> CGImage {
        let input = CIImage(cgImage: image)
        let output = input.applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: ev])
        return try #require(context.createCGImage(output, from: input.extent))
    }

    /// A white page with nothing on it, the fixture's size.
    private static func blank(like image: CGImage) throws -> CGImage {
        let extent = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        return try #require(context.createCGImage(CIImage(color: .white).cropped(to: extent), from: extent))
    }

    private static func milliseconds(_ duration: Duration) -> Double {
        let parts = duration.components
        return Double(parts.seconds) * 1_000 + Double(parts.attoseconds) / 1e15
    }

    private static func decimal(_ value: Double) -> String {
        String(format: "%.3f", value)
    }

    /// One line per recognition level: luminance, time, lines and words at each confidence floor, and the verdict.
    private static func printMeasurements(of image: CGImage, named name: String) {
        let luminance = decimal(InvoicePageCheck.meanLuminance(of: image) ?? -1)
        let verdict = InvoicePageCheck.problem(in: image)?.rawValue ?? "pass"
        for level in [VNRequestTextRecognitionLevel.fast, .accurate] {
            let levelName = level == .fast ? "fast" : "accurate"
            let start = ContinuousClock.now
            do {
                let lines = try InvoicePageCheck.recognizedLines(in: image, level: level)
                let elapsed = Int(milliseconds(ContinuousClock.now - start))
                let counts = [0, 0.3, 0.5, 0.8].map { minimum in
                    "\(InvoicePageCheck.readableWords(in: lines, floor: Float(minimum)))@\(minimum)"
                }
                let lineCount = lines.count
                print("MS-163 \(name): luminance \(luminance), \(levelName) \(elapsed) ms, \(lineCount) lines, "
                    + "words \(counts.joined(separator: " ")), verdict \(verdict)")
            } catch {
                print("MS-163 \(name): Vision failed at \(levelName): \(error)")
            }
        }
    }

    // MARK: - Calibration

    /// Prints, for each variant, the mean luminance, the words read at each recognition level and confidence floor,
    /// the time Vision took, and the verdict; then the time of a whole check of the fixture JPEG.
    @Test func measureTheVariants() async throws {
        let sharp = try Self.fixture()
        var variants: [(String, CGImage)] = [("sharp", sharp)]
        for radius in [2.0, 3, 4, 5, 6, 7, 8, 10, 12] {
            let image = try Self.blurred(sharp, originalRadius: radius)
            variants.append(("blur r\(radius)", image))
        }
        for ev in [-1.0, -1.5, -2, -2.5, -3, -4] {
            let image = try Self.darkened(sharp, ev: ev)
            variants.append(("dark \(ev) EV", image))
        }
        let blank = try Self.blank(like: sharp)
        variants.append(("blank", blank))

        let size = "\(sharp.width)x\(sharp.height)"
        let dark = InvoicePageCheck.darkLuminance
        let words = InvoicePageCheck.minimumWords
        let floor = InvoicePageCheck.confidenceFloor
        print("MS-163 fixture \(size), thresholds: luminance < \(dark), words < \(words) at confidence \(floor)")
        for (name, image) in variants {
            Self.printMeasurements(of: image, named: name)
        }
        let data = try Self.fixtureData()
        for run in 1...3 {
            let start = ContinuousClock.now
            let problem = await InvoicePageCheck.problem(inJPEG: data)
            let elapsed = Int(Self.milliseconds(ContinuousClock.now - start))
            print("MS-163 whole check of the fixture JPEG, run \(run): \(elapsed) ms, \(problem?.rawValue ?? "pass")")
        }
    }

    // MARK: - Verdicts

    @Test func theSharpPhotoPasses() async throws {
        let data = try Self.fixtureData()
        let problem = await InvoicePageCheck.problem(inJPEG: data)
        #expect(problem == nil)
    }

    /// Radius 4 on the original is still mostly readable.
    @Test(arguments: [2.0, 4.0])
    func aSlightBlurPasses(originalRadius: Double) throws {
        let sharp = try Self.fixture()
        let image = try Self.blurred(sharp, originalRadius: originalRadius)
        #expect(InvoicePageCheck.problem(in: image) == nil)
    }

    /// From radius 8 on the original nobody can read the line items.
    @Test(arguments: [8.0, 12.0])
    func aBlurThatHidesTheLinesIsHardToRead(originalRadius: Double) throws {
        let sharp = try Self.fixture()
        let image = try Self.blurred(sharp, originalRadius: originalRadius)
        #expect(InvoicePageCheck.problem(in: image) == .blurry)
    }

    @Test func aDarkPhotoIsTooDark() throws {
        let sharp = try Self.fixture()
        let image = try Self.darkened(sharp, ev: -3)
        #expect(InvoicePageCheck.problem(in: image) == .dark)
    }

    @Test func aBlankPageIsHardToRead() throws {
        let sharp = try Self.fixture()
        let image = try Self.blank(like: sharp)
        #expect((InvoicePageCheck.meanLuminance(of: image) ?? 0) > 0.9)
        #expect(InvoicePageCheck.problem(in: image) == .blurry)
    }

    /// The check never stands in the way when it cannot run.
    @Test func whatIsNotAnImagePasses() async {
        let problem = await InvoicePageCheck.problem(inJPEG: Data("not an image".utf8))
        #expect(problem == nil)
        #expect(InvoicePageCheck.readableWords(in: []) == 0)
    }

    @Test func aLargePageIsCheckedAtTheReadersSize() throws {
        let sharp = try Self.fixture()
        let scaled = CIImage(cgImage: sharp).transformed(by: CGAffineTransform(scaleX: 2, y: 2))
        let sRGB = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let data = try #require(Self.context.jpegRepresentation(of: scaled, colorSpace: sRGB))
        let checked = try #require(InvoicePageCheck.checkedImage(from: data))
        #expect(max(checked.width, checked.height) == InvoicePageCheck.checkedPixelLength)
    }

    @Test func confidenceFloorCountsOnlySureLines() {
        let lines = [
            InvoicePageCheck.RecognizedLine(words: 3, confidence: 1),
            InvoicePageCheck.RecognizedLine(words: 5, confidence: 0.3)
        ]
        #expect(InvoicePageCheck.readableWords(in: lines, floor: 0.5) == 3)
        #expect(InvoicePageCheck.readableWords(in: lines, floor: 0) == 8)
    }
}
