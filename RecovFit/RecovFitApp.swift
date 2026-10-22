import SwiftUI

@main
struct RecovFitApp: App {
    @StateObject private var session = SessionManager()
    @State private var path = NavigationPath()

    var body: some Scene {
        WindowGroup {
            RootView(path: $path)   // ✅ session provides IDs internally
                .environmentObject(session)
        }
    }
}
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            
