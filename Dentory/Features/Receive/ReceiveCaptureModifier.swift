import PhotosUI
import SwiftUI

/// The pickers behind Take a photo and Upload PDF or image (f22): VisionKit's scanner full screen, or Photos where the
/// device has none, and Files for one PDF or image. What they hand over goes to the view model, which has it prepared
/// and checked off the main actor and sends it on, or opens the check's sheet over the screen (MS-163) once the
/// scanner's cover has gone.
struct ReceiveCaptureModifier: ViewModifier {
    @Bindable var viewModel: ReceiveViewModel
    @State private var photos: [PhotosPickerItem] = []

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $viewModel.isScannerPresented, onDismiss: viewModel.scannerDismissed) {
                DocumentScanner(
                    onScan: scanned, onCancel: { viewModel.isScannerPresented = false },
                    onFailure: { viewModel.failed(.scannerFailed) }
                )
                .ignoresSafeArea()
            }
            .photosPicker(
                isPresented: $viewModel.isPhotoPickerPresented, selection: $photos, selectionBehavior: .ordered,
                matching: .images, preferredItemEncoding: .compatible
            )
            .onChange(of: photos) { _, items in pickedPhotos(items) }
            .fileImporter(
                isPresented: $viewModel.isFileImporterPresented, allowedContentTypes: InvoiceCapture.fileTypes,
                onCompletion: pickedFile
            )
            .msSheet(item: $viewModel.check, onDismiss: viewModel.checkClosed) { check in
                ReceiveCheckSheet(check: check, viewModel: viewModel)
            }
    }

    private func scanned(_ images: [UIImage]) {
        Task { await viewModel.capture(from: .camera) { () async throws(InvoiceCaptureError) in
            try await InvoiceCapture.document(scanned: images)
        } }
    }

    private func pickedPhotos(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        photos = []
        Task { await viewModel.capture(from: .camera) { () async throws(InvoiceCaptureError) in
            try await InvoiceCapture.document(photos: items)
        } }
    }

    private func pickedFile(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            Task { await viewModel.capture(from: .file) { () async throws(InvoiceCaptureError) in
                try await InvoiceCapture.document(fileAt: url)
            } }
        case .failure:
            viewModel.failed(.unreadable(.file))
        }
    }
}

extension View {
    /// Take a photo's and Upload PDF or image's pickers, driven by Receive delivery's view model.
    func receiveCapture(_ viewModel: ReceiveViewModel) -> some View {
        modifier(ReceiveCaptureModifier(viewModel: viewModel))
    }
}
