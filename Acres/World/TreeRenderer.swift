import SpriteKit
import AcresCore

/// Draws the trees the player planted or changed (`GameState.woodland`):
/// saplings, young and full-grown trees, stumps and ripe fruit. Untouched
/// wild trees stay with the chunk manager.
@MainActor
final class TreeRenderer {
    private struct Shown: Equatable {
        var asset: String
        var hasFruit: Bool
    }

    private final class TreeNodes {
        let sprite: SKSpriteNode
        let shadow: SKSpriteNode
        var fruit: SKSpriteNode?
        var shown: Shown

        init(sprite: SKSpriteNode, shadow: SKSpriteNode, shown: Shown) {
            self.sprite = sprite
            self.shadow = shadow
            self.shown = shown
        }
    }

    private let assets: AssetCatalog
    private let flatLayer: SKNode
    private let objectLayer: SKNode
    private var nodes: [TileCoord: TreeNodes] = [:]
    /// Mature trees wear the season's leaves.
    var season: Season = .summer

    init(assets: AssetCatalog, flatLayer: SKNode, objectLayer: SKNode) {
        self.assets = assets
        self.flatLayer = flatLayer
        self.objectLayer = objectLayer
    }

    /// Brings sprites up to date. `isVisible` says whether a tile's chunk is loaded.
    func sync(woodland: Woodland, forestry: Forestry, isVisible: (TileCoord) -> Bool) {
        for (tile, tree) in woodland.trees where isVisible(tile) {
            let shown = Shown(asset: Self.assetName(tree, season: season), hasFruit: tree.hasFruit)
            if let existing = nodes[tile] {
                if existing.shown != shown { update(existing, tree: tree, to: shown) }
            } else {
                create(tile, tree, shown, at: forestry.position(of: tile))
            }
        }
        for (tile, treeNodes) in nodes where woodland[tile] == nil || !isVisible(tile) {
            treeNodes.sprite.removeFromParent()
            treeNodes.shadow.removeFromParent()
            nodes[tile] = nil
        }
    }

    func removeAll() {
        for treeNodes in nodes.values {
            treeNodes.sprite.removeFromParent()
            treeNodes.shadow.removeFromParent()
        }
        nodes.removeAll()
    }

    static func assetName(_ tree: TreeState, season: Season = .summer) -> String {
        switch tree.stage {
        case .stump: "tree_stump"
        case .sapling: "tree_\(tree.speciesID)_sapling"
        case .young: "tree_\(tree.speciesID)_young"
        case .mature: AssetManifest.assetName(forObjectKind: "tree_\(tree.speciesID)", season: season) ?? "tree_\(tree.speciesID)_summer"
        }
    }

    // MARK: Private

    private func create(_ tile: TileCoord, _ tree: TreeState, _ shown: Shown, at position: Vec2) {
        let sprite = SKSpriteNode(texture: nil)
        sprite.position = World.point(position)
        sprite.zPosition = World.depth(forY: sprite.position.y)
        objectLayer.addChild(sprite)
        let shadow = SKSpriteNode(texture: assets.texture("fx_shadow_soft"))
        shadow.alpha = 0.3
        shadow.zPosition = 1
        flatLayer.addChild(shadow)
        let treeNodes = TreeNodes(sprite: sprite, shadow: shadow, shown: Shown(asset: "", hasFruit: false))
        nodes[tile] = treeNodes
        update(treeNodes, tree: tree, to: shown, animated: false)
    }

    private func update(_ treeNodes: TreeNodes, tree: TreeState, to shown: Shown, animated: Bool = true) {
        let sprite = treeNodes.sprite
        if treeNodes.shown.asset != shown.asset, let spec = AssetManifest.spec(named: shown.asset) {
            sprite.texture = assets.texture(shown.asset)
            sprite.size = CGSize(width: CGFloat(spec.tilesWide) * World.tileSize, height: CGFloat(spec.tilesHigh) * World.tileSize)
            sprite.anchorPoint = CGPoint(x: 0.5, y: CGFloat(spec.anchorY))
            let width = CGFloat(max(spec.shadowWidth, 0.6)) * World.tileSize
            treeNodes.shadow.size = CGSize(width: width, height: width * 0.42)
            treeNodes.shadow.position = CGPoint(x: sprite.position.x + width * 0.08, y: sprite.position.y - width * 0.03)
            sprite.removeAction(forKey: "sway")
            if tree.stage != .stump {
                let angle: CGFloat = tree.stage == .sapling ? 0.05 : 0.015
                let half = 1.8
                let right = SKAction.rotate(toAngle: -angle, duration: half)
                right.timingMode = .easeInEaseOut
                let left = SKAction.rotate(toAngle: angle, duration: half)
                left.timingMode = .easeInEaseOut
                sprite.run(.repeatForever(.sequence([right, left])), withKey: "sway")
            } else {
                sprite.zRotation = 0
            }
            if animated {
                // "It grew!" pop.
                sprite.setScale(0.85)
                sprite.run(.scale(to: 1, duration: 0.3))
            }
        }
        if shown.hasFruit != treeNodes.shown.hasFruit || treeNodes.shown.asset != shown.asset {
            treeNodes.fruit?.removeFromParent()
            treeNodes.fruit = nil
            let overlay = "tree_\(tree.speciesID)_fruit"
            if shown.hasFruit, AssetManifest.spec(named: overlay) != nil {
                let fruit = SKSpriteNode(texture: assets.texture(overlay))
                fruit.size = sprite.size
                fruit.anchorPoint = sprite.anchorPoint
                fruit.zPosition = 0.5
                if animated {
                    fruit.alpha = 0
                    fruit.run(.fadeIn(withDuration: 0.4))
                }
                sprite.addChild(fruit)
                treeNodes.fruit = fruit
            }
        }
        treeNodes.shown = shown
    }
}

/// Feedback for chopping, clearing and picking.
@MainActor
enum TreeEffects {

    /// The tree tips over and fades while chips fly and the logs pop up.
    static func chopped(at position: Vec2, speciesID: String, logs: Int, in layer: SKNode, assets: AssetCatalog) {
        let base = World.point(position)
        if let spec = AssetManifest.spec(named: "tree_\(speciesID)_summer") {
            let tree = SKSpriteNode(texture: assets.texture("tree_\(speciesID)_summer"))
            tree.size = CGSize(width: CGFloat(spec.tilesWide) * World.tileSize, height: CGFloat(spec.tilesHigh) * World.tileSize)
            tree.anchorPoint = CGPoint(x: 0.5, y: CGFloat(spec.anchorY))
            tree.position = base
            tree.zPosition = 5
            layer.addChild(tree)
            let fall = SKAction.rotate(toAngle: -.pi / 2, duration: 0.55)
            fall.timingMode = .easeIn
            tree.run(.sequence([fall, .group([.fadeOut(withDuration: 0.35), .moveBy(x: 0, y: -6, duration: 0.35)]), .removeFromParent()]))
        }
        for k in 0..<8 {
            let chip = SKSpriteNode(texture: assets.texture("fx_wood_chip"))
            chip.size = CGSize(width: 14, height: 14)
            chip.position = CGPoint(x: base.x, y: base.y + 24)
            chip.zPosition = 20
            layer.addChild(chip)
            let angle = CGFloat(k) / 8 * .pi * 2
            chip.run(.sequence([
                .group([
                    .moveBy(x: cos(angle) * 46, y: sin(angle) * 30 + 20, duration: 0.45),
                    .rotate(byAngle: 4, duration: 0.45),
                    .sequence([.wait(forDuration: 0.25), .fadeOut(withDuration: 0.2)]),
                ]),
                .removeFromParent(),
            ]))
        }
        badge(icon: "item_log", amount: logs, at: CGPoint(x: base.x, y: base.y + 70), delay: 0.4, in: layer, assets: assets)
    }

    static func cleared(at position: Vec2, in layer: SKNode, assets: AssetCatalog) {
        let base = World.point(position)
        for k in 0..<5 {
            let puff = SKSpriteNode(texture: assets.texture("fx_dust_puff"))
            puff.size = CGSize(width: 30, height: 30)
            puff.position = base
            puff.zPosition = 20
            layer.addChild(puff)
            let angle = CGFloat(k) / 5 * .pi * 2
            puff.run(.sequence([
                .group([.moveBy(x: cos(angle) * 26, y: sin(angle) * 16 + 10, duration: 0.5), .scale(to: 1.8, duration: 0.5),
                        .fadeOut(withDuration: 0.5)]),
                .removeFromParent(),
            ]))
        }
    }

    static func picked(at position: Vec2, itemID: String, amount: Int, in layer: SKNode, assets: AssetCatalog) {
        let base = World.point(position)
        badge(icon: "item_\(itemID)", amount: amount, at: CGPoint(x: base.x, y: base.y + World.tileSize * 2.4), delay: 0, in: layer, assets: assets)
    }

    /// "+3 🪵" floating up.
    static func badge(icon: String, amount: Int, at point: CGPoint, delay: TimeInterval, in layer: SKNode, assets: AssetCatalog) {
        let badge = SKNode()
        badge.position = point
        badge.zPosition = 30
        let sprite = SKSpriteNode(texture: assets.texture(icon))
        sprite.size = CGSize(width: 34, height: 34)
        sprite.position = CGPoint(x: 18, y: 10)
        badge.addChild(sprite)
        for (offset, color) in [(CGPoint(x: 1.5, y: -1.5), SKColor(white: 0, alpha: 0.45)), (.zero, SKColor.white)] {
            let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
            label.text = "+\(amount)"
            label.fontSize = 26
            label.fontColor = color
            label.horizontalAlignmentMode = .right
            label.position = offset
            badge.addChild(label)
        }
        badge.alpha = 0
        badge.setScale(0.6)
        layer.addChild(badge)
        badge.run(.sequence([
            .wait(forDuration: delay),
            .group([.fadeIn(withDuration: 0.1), .scale(to: 1, duration: 0.15), .moveBy(x: 0, y: 46, duration: 0.9)]),
            .fadeOut(withDuration: 0.3),
            .removeFromParent(),
        ]))
    }
}
