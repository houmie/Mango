import SwiftUI

struct MGContentView: View {
    
    @StateObject private var packetTunnelManager        = MGPacketTunnelManager()
    @StateObject private var configurationListManager   = MGConfigurationListManager()
    
    @AppStorage(MGConfiguration.currentStoreKey, store: .shared) private var current: String = ""
    
    var body: some View {
        TabView {
            MGHomeView(current: $current)
                .tabItem {
                    Text("Dashboard")
                    Image(systemName: "text.and.command.macwindow")
                }
            MGConfigurationListView(current: $current)
                .tabItem {
                    Text("Configuration")
                    Image(systemName: "doc")
                }
            MGSettingsView()
                .tabItem {
                    Text("Settings")
                    Image(systemName: "gearshape")
                }
        }
        .environmentObject(packetTunnelManager)
        .environmentObject(configurationListManager)
    }
}

struct Previews_MGContentView_Previews: PreviewProvider {
    static var previews: some View {
        MGContentView()
    }
}
