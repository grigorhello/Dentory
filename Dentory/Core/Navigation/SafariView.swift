import SafariServices
import SwiftUI

/// A web page in the in-app browser (Account › Help, MS-137). SwiftUI has no in-app browser before iOS 26, so this
/// wraps `SFSafariViewController`; its Done button calls `onDone`, which closes the cover it sits in.
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    let onDone: () -> Void

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.dismissButtonStyle = .done
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {
        context.coordinator.onDone = onDone
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onDone: onDone)
    }

    final class Coordinator: NSObject, SFSafariViewControllerDelegate {
        var onDone: () -> Void

        init(onDone: @escaping () -> Void) {
            self.onDone = onDone
        }

        func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
            onDone()
        }
    }
}
