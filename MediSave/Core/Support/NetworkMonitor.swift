import Foundation
import Network
import Observation

/// Whether the device has a connection; the offline banner and the write queue (MS-108) read it.
protocol NetworkMonitoring: AnyObject, Sendable {
    @MainActor var isConnected: Bool { get }
}

@MainActor
@Observable
final class NetworkMonitor: NetworkMonitoring {
    private(set) var isConnected = true
    private let monitor = NWPathMonitor()

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            Task { @MainActor [weak self] in
                self?.isConnected = connected
            }
        }
        monitor.start(queue: DispatchQueue(label: "com.medisave.network-monitor"))
    }
}

/// A monitor whose state tests and previews set by hand.
@MainActor
@Observable
final class FixedNetworkMonitor: NetworkMonitoring {
    var isConnected: Bool

    init(isConnected: Bool = true) {
        self.isConnected = isConnected
    }
}
