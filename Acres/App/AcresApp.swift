import SwiftUI

@main
struct AcresApp: App {
    @State private var game = GameController()

    init() {
        HUD.registerFont()
    }

    var body: some Scene {
        WindowGroup {
            RootView(game: game)
        }
    }
}
