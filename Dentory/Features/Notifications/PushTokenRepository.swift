/// This device's APNs token on the server (MS-144): registered for the signed-in member, removed when they sign out
/// here, so pushes follow whoever is signed in on the device.
protocol PushTokenRepository: Sendable {
    func register(token: String) async throws
    func remove(token: String) async throws
}
