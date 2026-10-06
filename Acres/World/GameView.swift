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
        let view = GameSKView(frame: .zero)
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

/// The SpriteKit view, which also takes the keyboard (an iPad with a keyboard,
/// or the Mac): it hands key presses to the scene first and passes on the
/// ones the game doesn't use.
final class GameSKView: SKView {
    override var canBecomeFirstResponder: Bool { true }

    private var gameScene: GameScene? { scene as? GameScene }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil { becomeFirstResponder() }
    }

    override func resignFirstResponder() -> Bool {
        gameScene?.keyboardLost()  // no key stays "held" while a sheet has the keyboard
        return super.resignFirstResponder()
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        let unused = presses.filter { !(gameScene?.handlePress($0, down: true) ?? false) }
        if !unused.isEmpty { super.pressesBegan(unused, with: event) }
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        let unused = presses.filter { !(gameScene?.handlePress($0, down: false) ?? false) }
        if !unused.isEmpty { super.pressesEnded(unused, with: event) }
    }

    override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        gameScene?.keyboardLost()
        super.pressesCancelled(presses, with: event)
    }
}
