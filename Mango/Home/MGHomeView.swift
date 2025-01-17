import SwiftUI

struct MGHomeView: View {
    
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var packetTunnelManager: MGPacketTunnelManager
    
    let current: Binding<String>
    
    var body: some View {
        NavigationStack {
            Group {
                if packetTunnelManager.isProcessing {
                    ZStack {
                        LoadingBackgroundColor()
                        ProgressView()
                            .controlSize(.large)
                    }
                    .ignoresSafeArea()
                } else {
                    Form {
                        Section {
                            MGControlView()
                            MGConnectedDurationView()
                        } header: {
                            Text("State")
                        }
                        Section {
                            MGConfigurationView(current: current)
                        } header: {
                            Text("Current configuration")
                        }
                    }
                    .environmentObject(packetTunnelManager)
                }
            }
            .navigationTitle(Text("Dashboard"))
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    private func LoadingBackgroundColor() -> Color {
        switch colorScheme {
        case .light:
            return Color(uiColor: .systemGroupedBackground)
        default:
            return Color.clear
        }
    }
}
