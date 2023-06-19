import SwiftUI

struct MGSniffingEntranceView: View {
        
    @StateObject private var sniffingViewModel = MGSniffingViewModel()
    
    var body: some View {
        NavigationLink {
            MGSniffingSettingView(sniffingViewModel: sniffingViewModel)
        } label: {
            LabeledContent {
                Text(sniffingViewModel.enabled ? "Open" : "Closure")
            } label: {
                Label("traffic sniffing", systemImage: "magnifyingglass")
            }
        }
    }
}
