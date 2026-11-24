import SwiftUI

struct RootView: View {
    @Environment(NyamStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var store = store

        TabView(selection: $store.selectedTab) {
            Tab("Today", systemImage: "rectangle.stack", value: AppTab.today) {
                TodayView()
            }
            Tab("Menu", systemImage: "list.bullet", value: AppTab.menu) {
                MenuView()
            }
        }
        .tint(Theme.orangeText)
        .fullScreenCover(isPresented: $store.showingPairing) {
            PairingView()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                store.refreshDay()
            }
        }
    }
}
