import SwiftUI
import NetworkExtension

struct MGControlView: View {
    
    @EnvironmentObject private var packetTunnelManager: MGPacketTunnelManager
    
    var body: some View {
        LabeledContent {
            if let status = packetTunnelManager.status {
                switch status {
                case .connected, .disconnected:
                    Button {
                        onTap(status: status)
                    } label: {
                        Text(status.buttonTitle)
                    }
                    .disabled(status == .invalid)
                default:
                    ProgressView()
                }
            } else {
                Button  {
                    Task(priority: .high) {
                        do {
                            try await packetTunnelManager.saveToPreferences()
                        } catch {
                            debugPrint(error.localizedDescription)
                        }
                    }
                } label: {
                    Text("安装")
                }
            }
        } label: {
            Label {
                Text(packetTunnelManager.status.flatMap({ $0.displayString }) ?? "VPN configuration not installed")
            } icon: {
                Image(systemName: "link")
            }
        }
    }
    
    private func onTap(status: NEVPNStatus) {
        Task(priority: .high) {
            do {
                switch status {
                case .connected:
                    packetTunnelManager.stop()
                case .disconnected:
                    try await packetTunnelManager.start()
                default:
                    break
                }
            } catch {
                debugPrint(error.localizedDescription)
            }
        }
    }
}

extension NEVPNStatus {
    
    var buttonTitle: String {
        switch self {
        case .invalid, .disconnected:
            return "Connect"
        case .connected:
            return "Disconnect"
        case .connecting, .reasserting, .disconnecting:
            return ""
        @unknown default:
            return "Unknown"
        }
    }
    
    var displayString: String {
        switch self {
        case .invalid:
            return "Unavailable"
        case .disconnected:
            return "Not connected"
        case .connecting:
            return "Connecting..."
        case .connected:
            return "Connected"
        case .reasserting:
            return "Reconnecting..."
        case .disconnecting:
            return "Disconnecting..."
        @unknown default:
            return "Unknown"
        }
    }
}
