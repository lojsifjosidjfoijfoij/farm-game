import SpriteKit
import SwiftUI

/// Hosts the SpriteKit world inside SwiftUI.
///
/// A thin UIViewRepresentable (rather than SwiftUI's `SpriteView`) so we can
/// attach gesture recognizers and toggle debug overlays directly.
struct GameView: UIViewRepresentable {
    let game: GameController
    var showsStats: Bool
    var showsChunkBorders: Bool

    func makeUIView(context: Context) -> SKView {
        let view = SKView(frame: .zero)
        view.ignoresSiblingOrder = true      // sort purely by zPosition: enables batching
        view.shouldCullNonVisibleNodes = true
        view.preferredFramesPerSecond = 60   // steady 60 on ProMotion too (battery)
        view.isMultipleTouchEnabled = true
        view.presentScene(GameScene(game: game))
        return view
    }

    func updateUIView(_ view: SKView, context: Context) {
        view.showsFPS = showsStats
        view.showsNodeCount = showsStats
        view.showsDrawCount = showsStats
        (view.scene as? GameScene)?.showsChunkBorders = showsChunkBorders
    }
}
