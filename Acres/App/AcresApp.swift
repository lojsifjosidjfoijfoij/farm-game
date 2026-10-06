import SwiftUI
import UIKit

@main
struct AcresApp: App {
    @State private var game = GameController()

    init() {
        HUD.registerFont()
    }

    var body: some Scene {
        WindowGroup {
            RootView(game: game)
                #if targetEnvironment(macCatalyst)
                .onAppear { MacWindow.configure(saving: game) }
                #endif
        }
    }
}

#if targetEnvironment(macCatalyst)
/// The game's window on the Mac: resizable, but never smaller than the HUD
/// needs. Quitting (⌘Q) doesn't always pass through the background on the
/// Mac, so the game also tidies up and saves on the way out.
@MainActor
enum MacWindow {
    private static var savesOnQuit = false

    static func configure(saving game: GameController) {
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            scene.sizeRestrictions?.minimumSize = CGSize(width: 960, height: 600)
        }
        guard !savesOnQuit else { return }
        savesOnQuit = true
        _ = NotificationCenter.default.addObserver(forName: UIApplication.willTerminateNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { game.scenePhaseChanged(to: .background) }
        }
    }
}
#endif
