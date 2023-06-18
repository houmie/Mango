import SwiftUI

struct MGNetworkSettingView: View {
    
    @EnvironmentObject  private var packetTunnelManager: MGPacketTunnelManager
    @ObservedObject private var networkViewModel: MGNetworkViewModel
    
    init(networkViewModel: MGNetworkViewModel) {
        self._networkViewModel = ObservedObject(initialValue: networkViewModel)
    }
    
    var body: some View {
        Form {
            Section {
                LabeledContent("SOCKS5 port") {
                    TextField("8080", value: $networkViewModel.inboundPort, format: .number)
                        .multilineTextAlignment(.trailing)
                }
            } header: {
                Text("Inbound")
            } footer: {
                Text("Custom configuration needs to modify the SOCKS5 inbound port to the set value")
            }
            Section {
                Toggle("Hide VPN icon", isOn: $networkViewModel.hideVPNIcon)
            } header: {
                Text("VPN")
            } footer: {
                Text("Exclude route 0:0:0:0/8 & ::/128")
            }
            Section {
                Toggle("Enable IPv6 routing", isOn: $networkViewModel.ipv6Enabled)
            } header: {
                Text("Tunnel")
            } footer: {
                Text("Enabling IPv6 in an environment that does not support IPv6 may have compatibility issues, so be careful to enable it")
            }
        }
        .navigationTitle(Text("Network settings"))
        .navigationBarTitleDisplayMode(.large)
        .onDisappear {
            self.networkViewModel.save {
                guard let status = packetTunnelManager.status, status == .connected else {
                    return
                }
                packetTunnelManager.stop()
                Task(priority: .userInitiated) {
                    do {
                        try await Task.sleep(for: .milliseconds(500))
                        try await packetTunnelManager.start()
                    } catch {
                        debugPrint(error.localizedDescription)
                    }
                }
            }
        }
    }
}
