import SwiftUI

struct MGLogEntranceView: View {
        
    @StateObject private var logViewModel = MGLogViewModel()
    
    var body: some View {
        NavigationLink {
            MGLogSettingView(logViewModel: logViewModel)
        } label: {
            Label("log", systemImage: "doc.text.below.ecg")
        }
    }
}
