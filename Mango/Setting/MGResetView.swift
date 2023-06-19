import SwiftUI

struct MGResetView: View {
    
    @EnvironmentObject private var packetTunnelManager: MGPacketTunnelManager

    @State private var isPresented: Bool = false
    
    var body: some View {
        HStack {
            Spacer()
            Button("Reset VPN configuration", role: .destructive) {
                isPresented.toggle()
            }
            .disabled(packetTunnelManager.status == nil)
            Spacer()
        }
        .alert("reset", isPresented: $isPresented) {
            Button("Sure", role: .destructive) {
                Task(priority: .high) {
                    try await packetTunnelManager.removeFromPreferences()
                    try await packetTunnelManager.saveToPreferences()
                }
            }
            Button("Cancel", role: .cancel, action: {})
        } message: {
            Text("Are you sure to reset your VPN configuration?")
        }
    }
}
