import SwiftUI

/// Push on the signed-in tabs (MS-144): the explainer when it is due, and each tapped notification handed to `open`.
struct PushNotificationsModifier: ViewModifier {
    @Bindable var push: PushNotifications
    let session: Session
    let open: (NotificationLink) -> Void

    func body(content: Content) -> some View {
        content
            .task(id: session.userID) { await push.signedIn(as: session) }
            .onChange(of: push.pendingLink, initial: true) { _, link in
                guard let link else { return }
                push.pendingLink = nil
                open(link)
            }
            .msSheet(isPresented: $push.isExplainerPresented) {
                PushExplainerSheet(push: push)
            }
    }
}

extension View {
    func pushNotifications(
        _ push: PushNotifications, session: Session, open: @escaping (NotificationLink) -> Void
    ) -> some View {
        modifier(PushNotificationsModifier(push: push, session: session, open: open))
    }
}
