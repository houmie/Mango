import SwiftUI

struct MGConfigurationLoadView: View {
    
    @Environment(\.dismiss) private var dismiss
    
    @EnvironmentObject private var configurationListManager: MGConfigurationListManager
    
    @StateObject private var vm = MGConfigurationLoadViewModel()
    
    @State private var isFileImporterPresented: Bool = false
    
    let location: MGConfigurationLocation
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Please enter a configuration name", text: $vm.name)
                } header: {
                    Text("name")
                } footer: {
                    Text("Configuration names can be non-unique, but not recommended")
                }
                Section {
                    HStack(spacing: 4) {
                        TextField(addressPrompt, text: $vm.urlString)
                            .disabled(isAddressTextFieldDisable)
                        if location == .local {
                            Button("browse") {
                                isFileImporterPresented.toggle()
                            }
                            .fixedSize()
                        }
                    }
                } header: {
                    Text(addressTitle)
                }
                Section {
                    Button {
                        Task(priority: .userInitiated) {
                            do {
                                try await vm.process(location: location)
                                await MainActor.run {
                                    configurationListManager.reload()
                                    dismiss()
                                }
                            } catch {
                                await MainActor.run {
                                    MGNotification.send(title:"", subtitle: "", body: error.localizedDescription)
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Text(buttonTitle)
                            Spacer()
                        }
                    }
                    .disabled(isButtonDisbale)
                }
            }
            .navigationTitle(Text(title))
            .navigationBarTitleDisplayMode(.large)
            .interactiveDismissDisabled(vm.isProcessing)
            .fileImporter(isPresented: $isFileImporterPresented, allowedContentTypes: [.json]) { result in
                switch result {
                case .success(let success):
                    vm.urlString = success.path(percentEncoded: false)
                    if vm.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        vm.name = success.deletingPathExtension().lastPathComponent
                    }
                case .failure(let failure):
                    MGNotification.send(title: "", subtitle: "", body: failure.localizedDescription)
                }
            }
            .toolbar {
                if vm.isProcessing {
                    ProgressView()
                }
            }
        }
        .disabled(vm.isProcessing)
    }
    
    private var title: String {
        switch location {
        case .local:
            return "import configuration"
        case .remote:
            return "download configuration"
        }
    }
    
    private var addressTitle: String {
        switch location {
        case .local:
            return "Location"
        case .remote:
            return "address"
        }
    }
    
    private var addressPrompt: String {
        switch location {
        case .local:
            return "Please select a local file"
        case .remote:
            return "Please enter the configuration file URL"
        }
    }
    
    private var isAddressTextFieldDisable: Bool {
        switch location {
        case .local:
            return true
        case .remote:
            return false
        }
    }
    
    private var buttonTitle: String {
        switch location {
        case .local:
            return "import"
        case .remote:
            return "download"
        }
    }
    
    private var isButtonDisbale: Bool {
        guard !vm.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return true
        }
        switch location {
        case .local:
            return vm.urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .remote:
            return URL(string: vm.urlString.trimmingCharacters(in: .whitespacesAndNewlines)) == nil
        }
    }
}
