import SwiftUI

struct MGLogSettingView: View {
    
    @EnvironmentObject  private var packetTunnelManager: MGPacketTunnelManager
    @ObservedObject private var logViewModel: MGLogViewModel
    
    init(logViewModel: MGLogViewModel) {
        self._logViewModel = ObservedObject(initialValue: logViewModel)
    }
    
    var body: some View {
        Form {
            Section {
                Picker(selection: $logViewModel.errorLogSeverity) {
                    ForEach(MGLogModel.Severity.allCases) { severity in
                        Text(severity.displayTitle)
                    }
                } label: {
                    Text("error log")
                }
            }
            Section {
                Toggle("access log", isOn: $logViewModel.accessLogEnabled)
                Toggle("DNS query log", isOn: $logViewModel.dnsLogEnabled)
            }
        }
        .navigationTitle(Text("log"))
        .navigationBarTitleDisplayMode(.large)
        .onDisappear {
            self.logViewModel.save {
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

extension MGLogModel.Severity {
    
    var displayTitle: String {
        switch self {
        case .none:
            return "closure"
        case .error:
            return "Error"
        case .warning:
            return "Warning"
        case .info:
            return "Info"
        case .debug:
            return "Debug"
        }
    }
}
