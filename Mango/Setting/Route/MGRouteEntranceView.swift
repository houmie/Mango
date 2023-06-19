import SwiftUI

struct MGRouteEntranceView: View {
    
    @StateObject private var routeViewModel = MGRouteViewModel()
    
    var body: some View {
        NavigationLink {
            MGRouteSettingView(routeViewModel: routeViewModel)
        } label: {
            Label("Routing settings", systemImage: "arrow.triangle.branch")
        }
    }
}
