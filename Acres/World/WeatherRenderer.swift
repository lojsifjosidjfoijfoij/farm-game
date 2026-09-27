import SpriteKit
import AcresCore

/// Rain streaks and drifting snowflakes over the part of the world on
/// screen. Particles live in world space and are recycled as they leave
/// the view, so there's a steady few dozen however far the camera travels.
@MainActor
final class WeatherRenderer {
    private let layer: SKNode
    private let assets: AssetCatalog
    private var drops: [(node: SKSpriteNode, velocity: CGVector, phase: CGFloat)] = []
    private var kind: Weather = .sunny
    private var rng = SeededRandom(seed: 0x5EA7)
    private var time: CGFloat = 0

    init(layer: SKNode, assets: AssetCatalog) {
        self.layer = layer
        self.assets = assets
    }

    func update(weather: Weather, visible rect: CGRect, dt: TimeInterval) {
        if weather != kind {
            kind = weather
            for drop in drops { drop.node.run(.sequence([.fadeOut(withDuration: 0.6), .removeFromParent()])) }
            drops = []
            let count = switch weather {
            case .rain: 120
            case .snow: 90
            case .sunny, .cloudy: 0
            }
            for _ in 0..<count { drops.append(make(in: rect, anywhere: true)) }
        }
        guard !drops.isEmpty else { return }
        time += CGFloat(dt)
        let area = rect.insetBy(dx: -80, dy: -80)
        for index in drops.indices {
            let drop = drops[index]
            var position = drop.node.position
            position.x += drop.velocity.dx * CGFloat(dt)
            position.y += drop.velocity.dy * CGFloat(dt)
            if kind == .snow {
                position.x += sin(time * 1.3 + drop.phase) * 18 * CGFloat(dt)
            }
            if !area.contains(position) {
                // Back in at the top (or anywhere, if the camera jumped away).
                let far = position.y > area.maxY + 400 || position.x < area.minX - 400 || position.x > area.maxX + 400
                position = spawnPoint(in: rect, anywhere: far)
            }
            drop.node.position = position
        }
    }

    private func make(in rect: CGRect, anywhere: Bool) -> (node: SKSpriteNode, velocity: CGVector, phase: CGFloat) {
        let node: SKSpriteNode
        let velocity: CGVector
        if kind == .rain {
            node = SKSpriteNode(color: SKColor(red: 0.85, green: 0.9, blue: 1, alpha: 0.4), size: CGSize(width: 2, height: 24))
            node.zRotation = 0.12
            velocity = CGVector(dx: -110, dy: -900 - CGFloat(rng.nextUnit()) * 250)
        } else {
            node = SKSpriteNode(texture: assets.texture("fx_shadow_soft"))
            let size = 6 + CGFloat(rng.nextUnit()) * 6
            node.size = CGSize(width: size, height: size)
            node.color = .white
            node.colorBlendFactor = 1
            node.alpha = 0.85
            velocity = CGVector(dx: -12, dy: -60 - CGFloat(rng.nextUnit()) * 40)
        }
        node.zPosition = 60
        node.position = spawnPoint(in: rect, anywhere: anywhere)
        layer.addChild(node)
        return (node, velocity, CGFloat(rng.nextUnit()) * 6.28)
    }

    private func spawnPoint(in rect: CGRect, anywhere: Bool) -> CGPoint {
        let x = rect.minX - 60 + CGFloat(rng.nextUnit()) * (rect.width + 160)
        let y = anywhere ? rect.minY + CGFloat(rng.nextUnit()) * rect.height : rect.maxY + CGFloat(rng.nextUnit()) * 60
        return CGPoint(x: x, y: y)
    }
}
