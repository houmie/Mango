import SwiftUI

struct MGConfigurationView: View {
    
    @EnvironmentObject private var packetTunnelManager: MGPacketTunnelManager
    
    @EnvironmentObject private var configurationListManager: MGConfigurationListManager
    
    let current: Binding<String>
    
    var body: some View {
        Group {
            if let configuration = configurationListManager.configurations.first(where: { $0.id == current.wrappedValue }) {
                LabeledContent("Name", value: configuration.attributes.alias)
                LabeledContent("Type", value: configuration.typeString)
                LabeledContent("Recently updated") {
                    TimelineView(.periodic(from: Date(), by: 1)) { _ in
                        Text(configuration.attributes.leastUpdated.formatted(.relative(presentation: .numeric)))
                            .font(.callout)
                            .fontWeight(.light)
                    }
                }
            } else {
                NoCurrentConfigurationView()
            }
        }
        .onAppear {
            configurationListManager.reload()
        }
    }
    
    @ViewBuilder
    private func NoCurrentConfigurationView() -> some View {
        HStack {
            Spacer()
            VStack(spacing: 20) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.largeTitle)
                Text("No current configuration")
            }
            .foregroundColor(.secondary)
            .padding()
            Spacer()
        }
    }
    
    private var currentConfigurationName: String {
        guard let configuration = configurationListManager.configurations.first(where: { $0.id == current.wrappedValue }) else {
            return configurationListManager.configurations.isEmpty ? "none" : "not selected"
        }
        return configuration.attributes.alias
    }
}
