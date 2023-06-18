import SwiftUI

struct MGSettingsView: View {
            
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    MGNetworkEntranceView()
                } header: {
                    Text("System")
                }
                Section {
                    MGLogEntranceView()
                    MGSniffingEntranceView()
                    MGRouteEntranceView()
//                    MGDNSEntranceView()
                    MGAssetEntranceView()
                } header: {
                    Text("Kernel")
                }
                Section {
                    LabeledContent {
                        Text(Bundle.appVersion)
                            .monospacedDigit()
                    } label: {
                        Label("Application", systemImage: "app")
                    }
                    LabeledContent {
                        Text("1.8.0")
                            .monospacedDigit()
                    } label: {
                        Label("Kernel", systemImage: "app.fill")
                    }
                } header: {
                    Text("Version")
                }
                Section {
                    MGResetView()
                }
            }
            .navigationTitle(Text("Settings"))
            .navigationBarTitleDisplayMode(.large)
        }
    }
}
