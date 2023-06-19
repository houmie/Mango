import SwiftUI

struct MGSniffingSettingView: View {
    
    @EnvironmentObject  private var packetTunnelManager:    MGPacketTunnelManager
    @ObservedObject     private var sniffingViewModel:      MGSniffingViewModel
    
    init(sniffingViewModel: MGSniffingViewModel) {
        self._sniffingViewModel = ObservedObject(initialValue: sniffingViewModel)
    }
    
    var body: some View {
        Form {
            Section {
                Toggle("State", isOn: $sniffingViewModel.enabled)
            }
            Section {
                HStack {
                    MGToggleButton(title: "HTTP", isOn: Binding(get: {
                        sniffingViewModel.destOverride.contains("http")
                    }, set: { newValue in
                        if newValue {
                            sniffingViewModel.destOverride.append("http")
                        } else {
                            sniffingViewModel.destOverride.removeAll(where: { $0 == "http" })
                        }
                    }))
                    MGToggleButton(title: "TLS", isOn: Binding(get: {
                        sniffingViewModel.destOverride.contains("tls")
                    }, set: { newValue in
                        if newValue {
                            sniffingViewModel.destOverride.append("tls")
                        } else {
                            sniffingViewModel.destOverride.removeAll(where: { $0 == "tls" })
                        }
                    }))
                    MGToggleButton(title: "QUIC", isOn: Binding(get: {
                        sniffingViewModel.destOverride.contains("quic")
                    }, set: { newValue in
                        if newValue {
                            sniffingViewModel.destOverride.append("quic")
                        } else {
                            sniffingViewModel.destOverride.removeAll(where: { $0 == "quic" })
                        }
                    }))
                    MGToggleButton(title: "FAKEDNS", isOn: Binding(get: {
                        sniffingViewModel.destOverride.contains("fakedns")
                    }, set: { newValue in
                        if newValue {
                            sniffingViewModel.destOverride.append("fakedns")
                        } else {
                            sniffingViewModel.destOverride.removeAll(where: { $0 == "fakedns" })
                        }
                    }))
                }
                .padding(.vertical, 4)
            } header: {
                Text("Traffic type")
            } footer: {
                Text("When traffic is of the specified type, resets the destination of the current connection by the destination address included")
            }
            Section {
                ForEach(sniffingViewModel.excludedDomains, id: \.self) { domain in
                    Text(domain)
                        .lineLimit(1)
                }
                .onMove { from, to in
                    sniffingViewModel.excludedDomains.move(fromOffsets: from, toOffset: to)
                }
                .onDelete { offsets in
                    sniffingViewModel.excludedDomains.remove(atOffsets: offsets)
                }
                HStack(spacing: 18) {
                    Image(systemName: "plus.circle.fill")
                        .resizable()
                        .frame(width: 18, height: 18)
                        .foregroundColor(.green)
                        .offset(CGSize(width: 2, height: 0))
                    TextField("Please enter the domain name to be excluded", text: $sniffingViewModel.domain)
                        .onSubmit {
                            sniffingViewModel.submitDomain()
                        }
                        .multilineTextAlignment(.leading)
                }
            } header: {
                Text("Exclude domains")
            } footer: {
                Text("If the traffic sniffing result is in this list, the destination address will not be reset")
            }
            Section {
                Toggle("Use metadata only", isOn: $sniffingViewModel.metadataOnly)
            } footer: {
                Text("Will sniff the destination address using only the connection's metadata")
            }
            Section {
                Toggle("For routing only", isOn: $sniffingViewModel.routeOnly)
            } footer: {
                Text("The domain name obtained by sniffing is only used for routing, and the proxy target address is still IP")
            }
        }
        .onDisappear {
            self.sniffingViewModel.save {
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
        .navigationTitle(Text("Traffic sniffing"))
        .navigationBarTitleDisplayMode(.large)
        .environment(\.editMode, .constant(.active))
    }
}
