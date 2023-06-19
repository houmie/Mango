import SwiftUI

struct MGAssetEntranceView: View {
    
    @StateObject private var assetViewModel = MGAssetViewModel()
    
    var body: some View {
        NavigationLink {
            MGAssetSettingView(assetViewModel: assetViewModel)
        } label: {
            LabeledContent {
                Text("\(assetViewModel.items.isEmpty ? "none" : "\(assetViewModel.items.count)")")
            } label: {
                Label {
                    Text("Resource library")
                } icon: {
                    Image(systemName: "cylinder.split.1x2")
                }
            }
            .onAppear {
                assetViewModel.reload()
            }
        }
    }
}
