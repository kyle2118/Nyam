import SwiftUI
import FirebaseCore

@main
struct NyamApp: App {
    @State private var store: NyamStore

    init() {
        // Reads GoogleService-Info.plist. Must run before anything uses Firebase.
        FirebaseApp.configure()
        _store = State(initialValue: NyamStore())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .preferredColorScheme(.light)
        }
    }
}
