import SwiftUI

@main
struct AcresApp: App {
    @State private var game = GameController()

    var body: some Scene {
        WindowGroup {
            RootView(game: game)
        }
    }
}
