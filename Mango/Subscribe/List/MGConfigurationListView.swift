import SwiftUI
import CodeScanner

extension MGConfiguration {
    
    var typeString: String {
        if let pt = self.attributes.source.scheme.flatMap(MGConfiguration.ProtocolType.init(rawValue:)) {
            return pt.description
        } else {
            if self.attributes.source.isFileURL {
                return "Local"
            } else {
                return "Remotely"
            }
        }
    }
}

fileprivate extension MGConfiguration {
    
    var isUserCreated: Bool {
        self.attributes.source.scheme.flatMap(MGConfiguration.ProtocolType.init(rawValue:)) != nil
    }
    
    var isLocal: Bool {
        self.attributes.source.isFileURL || self.isUserCreated
    }
}

private struct MGConfigurationEditModel: Identifiable {
    
    let id: UUID
    let name: String
    let type: MGConfiguration.ProtocolType
    let model: MGConfiguration.Model
    
    init(configuration: MGConfiguration) throws {
        guard let id = UUID(uuidString: configuration.id) else {
            throw NSError.newError("Failed to get unique ID")
        }
        guard let type = configuration.attributes.source.scheme.flatMap(MGConfiguration.ProtocolType.init(rawValue:)) else {
            throw NSError.newError("Unsupported type")
        }
        self.id = id
        self.name = configuration.attributes.alias
        self.type = type
        let fileURL = MGConstant.configDirectory.appending(component: "\(configuration.id)/config.json")
        let data = try Data(contentsOf: fileURL)
        self.model = try JSONDecoder().decode(MGConfiguration.Model.self, from: data)
    }
    
    init(urlString: String) throws {
        let components = try MGConfiguration.URLComponents(urlString: urlString)
        self.id = UUID()
        self.name = components.descriptive
        self.type = components.protocolType
        self.model = try MGConfiguration.Model(components: components)
    }
}

struct MGConfigurationListView: View {
    
    @Environment(\.dismiss) private var dismiss
    
    @EnvironmentObject private var packetTunnelManager: MGPacketTunnelManager
    @EnvironmentObject private var configurationListManager: MGConfigurationListManager
        
    @State private var isRenameAlertPresented = false
    @State private var configurationName: String = ""
    
    @State private var editModel: MGConfigurationEditModel?
    
    @State private var location: MGConfigurationLocation?
    
    @State private var isConfirmationDialogPresented = false
    @State private var protocolType: MGConfiguration.ProtocolType?
    
    @State private var isCodeScannerPresented: Bool = false
    @State private var scanResult: Swift.Result<ScanResult, ScanError>?
    
    let current: Binding<String>
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        isConfirmationDialogPresented.toggle()
                    } label: {
                        Label("Create", systemImage: "square.and.pencil")
                    }
                    Button {
                        isCodeScannerPresented.toggle()
                    } label: {
                        Label("Scan QR code", systemImage: "qrcode.viewfinder")
                    }
                    .confirmationDialog("", isPresented: $isConfirmationDialogPresented) {
                        ForEach(MGConfiguration.ProtocolType.allCases) { value in
                            Button(value.description) {
                                protocolType = value
                            }
                        }
                    }
                    .fullScreenCover(item: $protocolType, onDismiss: { configurationListManager.reload() }) { protocolType in
                        MGCreateOrUpdateConfigurationView(
                            vm: MGCreateOrUpdateConfigurationViewModel(id: UUID(), descriptive: "", protocolType: protocolType, configurationModel: nil)
                        )
                    }
                } header: {
                    Text("Create configuration")
                }
                Section {
                    Button {
                        location = .remote
                    } label: {
                        Label("Download from URL", systemImage: "square.and.arrow.down.on.square")
                    }
                    Button {
                        location = .local
                    } label: {
                        Label("Import from folder", systemImage: "tray.and.arrow.down")
                    }
                } header: {
                    Text("Import custom configuration")
                } footer: {
                    Text("Custom configuration inbound only supports SOCKS5, the listening address is [::1], and the port is \(MGNetworkModel.current.inboundPort) (can be modified in settings), does not support username and password authentication")
                }
                Section {
                    if configurationListManager.configurations.isEmpty {
                        NoConfigurationView()
                    } else {
                        ForEach(configurationListManager.configurations) { configuration in
                            ConfigurationItemView(configuration: configuration)
                                .listRowBackground(current.wrappedValue == configuration.id ? Color.accentColor : nil)
                        }
                    }
                } header: {
                    Text("Configuration list")
                }
            }
            .navigationTitle(Text("Configuration management"))
            .navigationBarTitleDisplayMode(.large)
            .sheet(item: $location) { location in
                MGConfigurationLoadView(location: location)
            }
            .fullScreenCover(item: $editModel, onDismiss: { configurationListManager.reload() }) { em in
                MGCreateOrUpdateConfigurationView(
                    vm: MGCreateOrUpdateConfigurationViewModel(id: em.id, descriptive: em.name, protocolType: em.type, configurationModel: em.model)
                )
            }
            .fullScreenCover(isPresented: $isCodeScannerPresented) {
                guard let res = self.scanResult else {
                    return
                }
                self.scanResult = nil
                self.handleScanResult(res)
            } content: {
                MGQRCodeScannerView(result: $scanResult)
            }
        }
    }
    
    private func handleScanResult(_ result: Swift.Result<ScanResult, ScanError>) {
        switch result {
        case .success(let success):
            do {
                self.editModel = try MGConfigurationEditModel(urlString: success.string)
            } catch {
                MGNotification.send(title: "", subtitle: "", body: error.localizedDescription)
            }
        case .failure(let failure):
            let message: String
            switch failure {
            case .badInput:
                message = "Input error"
            case .badOutput:
                message = "Output error"
            case .permissionDenied:
                message = "Permission error"
            case .initError(let error):
                message = error.localizedDescription
            }
            MGNotification.send(title: "", subtitle: "", body: message)
        }
    }
    
    @ViewBuilder
    private func ConfigurationItemView(configuration: MGConfiguration) -> some View {
        Button {
            guard current.wrappedValue != configuration.id else {
                return
            }
            current.wrappedValue = configuration.id
        } label: {
            HStack(alignment: .center, spacing: 4) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(configuration.attributes.alias)
                        .foregroundColor(current.wrappedValue == configuration.id ? .white : .primary)
                        .fontWeight(.medium)
                    Text(configuration.typeString)
                        .foregroundColor(current.wrappedValue == configuration.id ? .white : .primary)
                        .font(.caption)
                        .fontWeight(.light)
                }
                Spacer()
                if configurationListManager.downloadingConfigurationIDs.contains(configuration.id) {
                    ProgressView()
                } else {
                    TimelineView(.periodic(from: Date(), by: 1)) { _ in
                        Text(configuration.attributes.leastUpdated.formatted(.relative(presentation: .numeric)))
                            .foregroundColor(current.wrappedValue == configuration.id ? .white : .primary)
                            .font(.callout)
                            .fontWeight(.light)
                    }
                }
            }
            .lineLimit(1)
        }
        .contextMenu {
            RenameOrEditButton(configuration: configuration)
            UpdateButton(configuration: configuration)
            Divider()
            DeleteButton(configuration: configuration)
        }
    }
    
    @ViewBuilder
    private func NoConfigurationView() -> some View {
        HStack {
            Spacer()
            VStack(spacing: 20) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.largeTitle)
                Text("No configuration yet")
            }
            .foregroundColor(.secondary)
            .padding()
            Spacer()
        }
    }
    
    @ViewBuilder
    private func RenameOrEditButton(configuration: MGConfiguration) -> some View {
        Button {
            if configuration.isUserCreated {
                do {
                    self.editModel = try MGConfigurationEditModel(configuration: configuration)
                } catch {
                    MGNotification.send(title: "", subtitle: "", body: "Failed to load file, reason: \(error.localizedDescription)")
                }
            } else {
                self.configurationName = configuration.attributes.alias
                self.isRenameAlertPresented.toggle()
            }
        } label: {
            Label(configuration.isUserCreated ? "edit" : "double naming", systemImage: "square.and.pencil")
        }
        .alert("double naming", isPresented: $isRenameAlertPresented) {
            TextField("Please enter a configuration name", text: $configurationName)
            Button("Sure") {
                let name = configurationName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !(name == configuration.attributes.alias || name.isEmpty) else {
                    return
                }
                do {
                    try configurationListManager.rename(configuration: configuration, name: name)
                } catch {
                    MGNotification.send(title: "", subtitle: "", body: "Rename failed, reason: \(error.localizedDescription)")
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }
    
    @ViewBuilder
    private func UpdateButton(configuration: MGConfiguration) -> some View {
        Button {
            Task(priority: .userInitiated) {
                do {
                    try await configurationListManager.update(configuration: configuration)
                    MGNotification.send(title: "", subtitle: "", body: "\"\(configuration.attributes.alias)\" update completed")
                    if configuration.id == current.wrappedValue {
                        guard let status = packetTunnelManager.status, status == .connected else {
                            return
                        }
                        packetTunnelManager.stop()
                        do {
                            try await packetTunnelManager.start()
                        } catch {
                            debugPrint(error.localizedDescription)
                        }
                    }
                } catch {
                    MGNotification.send(title: "", subtitle: "", body: "\"\(configuration.attributes.alias)\" Update failed, reason: \(error.localizedDescription)")
                }
            }
        } label: {
            Label("Renew", systemImage: "arrow.triangle.2.circlepath")
        }
        .disabled(configurationListManager.downloadingConfigurationIDs.contains(configuration.id) || configuration.isLocal)
    }
    
    @ViewBuilder
    private func DeleteButton(configuration: MGConfiguration) -> some View {
        Button(role: .destructive) {
            do {
                try configurationListManager.delete(configuration: configuration)
                MGNotification.send(title: "", subtitle: "", body: "\"\(configuration.attributes.alias)\" successfully deleted")
                if configuration.id == current.wrappedValue {
                    current.wrappedValue = ""
                    packetTunnelManager.stop()
                }
            } catch {
                MGNotification.send(title: "", subtitle: "", body: "\"\(configuration.attributes.alias)\" Delete failed, reason: \(error.localizedDescription)")
            }
        } label: {
            Label("delete", systemImage: "trash")
        }
        .disabled(configurationListManager.downloadingConfigurationIDs.contains(configuration.id))
    }
}
