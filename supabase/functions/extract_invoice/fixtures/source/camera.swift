import CoreImage
import CoreImage.CIFilterBuiltins
import AppKit

// photo <in.png> <out.jpg>: the page lying on a desk, shot from above at a slight angle, with uneven light and noise.
// scan <in.png> <out.jpg>: the page as a document scanner returns it: straightened but slightly rotated, a paper tint,
// a little noise.
let context = CIContext(options: [.workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!])

func load(_ path: String) -> CIImage {
    guard let image = CIImage(contentsOf: URL(fileURLWithPath: path)) else { fatalError("unreadable \(path)") }
    return image
}

func noise(_ extent: CGRect, amount: CGFloat, seed: CGFloat) -> CIImage {
    let random = CIFilter.randomGenerator().outputImage!.transformed(by: CGAffineTransform(translationX: seed, y: seed))
    let gray = random.applyingFilter("CIColorMatrix", parameters: [
        "inputRVector": CIVector(x: 0, y: amount, z: 0, w: 0),
        "inputGVector": CIVector(x: 0, y: amount, z: 0, w: 0),
        "inputBVector": CIVector(x: 0, y: amount, z: 0, w: 0),
        "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
        "inputBiasVector": CIVector(x: -amount / 2, y: -amount / 2, z: -amount / 2, w: 0),
    ])
    return gray.cropped(to: extent)
}

func save(_ image: CIImage, _ path: String, quality: CGFloat) {
    let extent = image.extent.integral
    guard let cg = context.createCGImage(image, from: extent) else { fatalError("render failed") }
    let rep = NSBitmapImageRep(cgImage: cg)
    guard let data = rep.representation(using: .jpeg, properties: [.compressionFactor: quality]) else { fatalError("jpeg") }
    try! data.write(to: URL(fileURLWithPath: path))
}

func photo(_ input: String, _ output: String) {
    let page = load(input)
    let width: CGFloat = 1800, height: CGFloat = 2400
    let canvas = CGRect(x: 0, y: 0, width: width, height: height)
    // A dark wooden desk: a warm gradient with grain.
    let desk = CIFilter.linearGradient()
    desk.point0 = CGPoint(x: 0, y: height)
    desk.point1 = CGPoint(x: width, y: 0)
    desk.color0 = CIColor(red: 0.36, green: 0.27, blue: 0.20)
    desk.color1 = CIColor(red: 0.22, green: 0.16, blue: 0.12)
    let grain = noise(canvas, amount: 0.10, seed: 11).applyingFilter("CIMotionBlur", parameters: ["inputRadius": 18, "inputAngle": 0.05])
    var background = grain.applyingFilter("CIAdditionCompositing", parameters: [kCIInputBackgroundImageKey: desk.outputImage!.cropped(to: canvas)])
    // The page, held at a slight angle: the top edge farther from the camera than the bottom one.
    let perspective = CIFilter.perspectiveTransform()
    perspective.inputImage = page
    perspective.topLeft = CGPoint(x: 230, y: 2215)
    perspective.topRight = CGPoint(x: 1585, y: 2250)
    perspective.bottomRight = CGPoint(x: 1660, y: 330)
    perspective.bottomLeft = CGPoint(x: 120, y: 285)
    let tilted = perspective.outputImage!
    // Its shadow on the desk.
    let shadowShape = CIImage(color: CIColor(red: 0, green: 0, blue: 0, alpha: 0.55)).cropped(to: tilted.extent)
    let shadowMask = tilted.applyingFilter("CIColorMatrix", parameters: [
        "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 0), "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 0),
        "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 0), "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0.6),
    ])
    let shadow = shadowMask.transformed(by: CGAffineTransform(translationX: 22, y: -26))
        .applyingGaussianBlur(sigma: 18)
    _ = shadowShape
    background = shadow.composited(over: background).cropped(to: canvas)
    var image = tilted.composited(over: background).cropped(to: canvas)
    // Uneven light: brighter at the top left, a soft vignette.
    let light = CIFilter.radialGradient()
    light.center = CGPoint(x: width * 0.3, y: height * 0.78)
    light.radius0 = 300
    light.radius1 = 2300
    light.color0 = CIColor(red: 1.0, green: 0.99, blue: 0.96)
    light.color1 = CIColor(red: 0.70, green: 0.68, blue: 0.64)
    image = image.applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: light.outputImage!.cropped(to: canvas)])
    // Sensor noise and a touch of softness.
    image = noise(canvas, amount: 0.035, seed: 3).applyingFilter("CIAdditionCompositing", parameters: [kCIInputBackgroundImageKey: image])
    image = image.applyingGaussianBlur(sigma: 0.7).cropped(to: canvas)
    save(image, output, quality: 0.82)
}

func scan(_ input: String, _ output: String) {
    let page = load(input)
    let width: CGFloat = 1700, height: CGFloat = 2200
    let canvas = CGRect(x: 0, y: 0, width: width, height: height)
    let scale = CGAffineTransform(scaleX: width / page.extent.width, y: height / page.extent.height)
    let rotate = CGAffineTransform(translationX: width / 2, y: height / 2).rotated(by: 0.006)
        .translatedBy(x: -width / 2, y: -height / 2)
    let white = CIImage(color: CIColor(red: 0.97, green: 0.965, blue: 0.95)).cropped(to: canvas)
    var image = page.transformed(by: scale.concatenating(rotate))
        .applyingFilter("CIColorControls", parameters: ["inputSaturation": 0.75, "inputContrast": 1.08, "inputBrightness": -0.015])
        .applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: white])
        .composited(over: white).cropped(to: canvas)
    image = noise(canvas, amount: 0.05, seed: 7).applyingFilter("CIAdditionCompositing", parameters: [kCIInputBackgroundImageKey: image])
    image = image.applyingGaussianBlur(sigma: 0.45).cropped(to: canvas)
    save(image, output, quality: 0.78)
}

let args = CommandLine.arguments
switch args[1] {
case "photo": photo(args[2], args[3])
case "scan": scan(args[2], args[3])
default: fatalError("photo or scan")
}
