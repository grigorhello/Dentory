import SwiftUI
import VisionKit

/// VisionKit's document camera for Take a photo (f22): several pages, each found and straightened by its automatic
/// edge detection. It hands back the pages as images, or says it was cancelled or failed; the caller dismisses it.
struct DocumentScanner: UIViewControllerRepresentable {
    /// False on the simulator and on a device without the scanner, where Take a photo opens Photos instead.
    static var isAvailable: Bool {
        VNDocumentCameraViewController.isSupported
    }

    let onScan: ([UIImage]) -> Void
    let onCancel: () -> Void
    let onFailure: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(scanner: self)
    }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: VNDocumentCameraViewController, context: Context) {
        context.coordinator.scanner = self
    }

    /// VisionKit calls its delegate on the main thread.
    final class Coordinator: NSObject, @preconcurrency VNDocumentCameraViewControllerDelegate {
        var scanner: DocumentScanner

        init(scanner: DocumentScanner) {
            self.scanner = scanner
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan
        ) {
            scanner.onScan((0..<scan.pageCount).map(scan.imageOfPage(at:)))
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            scanner.onCancel()
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            scanner.onFailure()
        }
    }
}
