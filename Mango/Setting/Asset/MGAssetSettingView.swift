import SwiftUI

struct MGAssetSettingView: View {
    
    @Environment(\.dataSizeFormatter) private var dataSizeFormatter
    @ObservedObject private var assetViewModel: MGAssetViewModel
    @State private var isFileImporterPresented: Bool = false
    
    init(assetViewModel: MGAssetViewModel) {
        self._assetViewModel = ObservedObject(initialValue: assetViewModel)
    }
    
    var body: some View {
        Form {
            ForEach(assetViewModel.items) { item in
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.url.lastPathComponent)
                        TimelineView(.periodic(from: Date(), by: 1)) { _ in
                            Text(item.date.formatted(.relative(presentation: .numeric)))
                                .lineLimit(1)
                                .foregroundColor(.secondary)
                                .font(.callout)
                                .fontWeight(.light)
                        }
                    }
                    Spacer()
                    Text(dataSizeFormatter.string(from: item.size) ?? "-")
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button("Delete", role: .destructive) {
                        do {
                            try assetViewModel.delete(item: item)
                        } catch {
                            debugPrint(error.localizedDescription)
                        }
                    }
                }
            }
        }
        .navigationTitle(Text("Resource library"))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    isFileImporterPresented.toggle()
                } label: {
                    Image(systemName: "square.and.arrow.down")
                }
            }
        }
        .fileImporter(isPresented: $isFileImporterPresented, allowedContentTypes: [.dat], allowsMultipleSelection: true) { result in
            do {
                try assetViewModel.importLocalFiles(urls: try result.get())
                MGNotification.send(title: "", subtitle: "", body: "Resource imported successfully")
            } catch {
                MGNotification.send(title: "", subtitle: "", body: "Resource import failed, reason: \(error.localizedDescription)")
            }
        }
    }
}
