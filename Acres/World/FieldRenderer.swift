import SpriteKit
import AcresCore

/// Keeps soil and crop sprites in step with `GameState.plots`.
///
/// It only rebuilds a plot's sprites when something visible changes (wet/dry
/// soil, crop, growth stage, which sides border the meadow), and only for
/// plots in loaded chunks. Each plot picks one of three soil pictures from
/// its position, so a field isn't one repeated tile, and grass creeps over
/// the soil on every side that has no plot next to it.
@MainActor
final class FieldRenderer {
    private struct Shown: Equatable {
        var wet: Bool
        var cropID: String?
        var stage: Int
        /// Sides with no plot next to them (north, east, south, west).
        var edges: Edges = []
    }

    struct Edges: OptionSet, Equatable {
        let rawValue: UInt8
        static let north = Edges(rawValue: 1)
        static let east = Edges(rawValue: 2)
        static let south = Edges(rawValue: 4)
        static let west = Edges(rawValue: 8)
    }

    private final class PlotNodes {
        let soil: SKSpriteNode
        var crop: SKSpriteNode?
        var edgeNodes: [SKSpriteNode] = []
        var shown: Shown

        init(soil: SKSpriteNode, shown: Shown) {
            self.soil = soil
            self.shown = shown
        }
    }

    private let assets: AssetCatalog
    private let flatLayer: SKNode
    private let objectLayer: SKNode
    private var nodes: [TileCoord: PlotNodes] = [:]

    init(assets: AssetCatalog, flatLayer: SKNode, objectLayer: SKNode) {
        self.assets = assets
        self.flatLayer = flatLayer
        self.objectLayer = objectLayer
    }

    /// Brings sprites up to date. `isVisible` says whether a tile's chunk is loaded.
    func sync(plots: FarmPlots, now: TimeInterval, isVisible: (TileCoord) -> Bool) {
        for (tile, plot) in plots.byTile where isVisible(tile) {
            var edges: Edges = []
            if plots[TileCoord(tile.x, tile.y + 1)] == nil { edges.insert(.north) }
            if plots[TileCoord(tile.x + 1, tile.y)] == nil { edges.insert(.east) }
            if plots[TileCoord(tile.x, tile.y - 1)] == nil { edges.insert(.south) }
            if plots[TileCoord(tile.x - 1, tile.y)] == nil { edges.insert(.west) }
            let shown = Shown(wet: plot.isWet(at: now), cropID: plot.crop?.cropID, stage: plot.crop?.stage ?? 0, edges: edges)
            if let existing = nodes[tile] {
                if existing.shown != shown { update(existing, tile: tile, to: shown) }
            } else {
                create(tile, shown)
            }
        }
        for (tile, plotNodes) in nodes where plots[tile] == nil || !isVisible(tile) {
            plotNodes.soil.removeFromParent()
            plotNodes.crop?.removeFromParent()
            nodes[tile] = nil
        }
    }

    func removeAll() {
        for plotNodes in nodes.values {
            plotNodes.soil.removeFromParent()
            plotNodes.crop?.removeFromParent()
        }
        nodes.removeAll()
    }

    func cropNode(at tile: TileCoord) -> SKSpriteNode? { nodes[tile]?.crop }

    // MARK: Private

    private func create(_ tile: TileCoord, _ shown: Shown) {
        let soil = SKSpriteNode(texture: assets.texture(soilName(wet: shown.wet, tile: tile)))
        soil.size = CGSize(width: World.tileSize, height: World.tileSize)
        soil.position = World.point(tile.center)
        soil.zPosition = 0.5  // above the ground, below contact shadows
        flatLayer.addChild(soil)
        let plotNodes = PlotNodes(soil: soil, shown: Shown(wet: shown.wet, cropID: nil, stage: 0, edges: []))
        nodes[tile] = plotNodes
        update(plotNodes, tile: tile, to: shown)
    }

    private func update(_ plotNodes: PlotNodes, tile: TileCoord, to shown: Shown) {
        let old = plotNodes.shown
        if old.wet != shown.wet {
            plotNodes.soil.texture = assets.texture(soilName(wet: shown.wet, tile: tile))
        }
        if old.edges != shown.edges {
            setEdges(plotNodes, shown.edges)
        }
        if old.cropID != shown.cropID || old.stage != shown.stage || plotNodes.crop == nil {
            if let cropID = shown.cropID {
                let name = "crop_\(cropID)_stage\(shown.stage)"
                let sprite = plotNodes.crop ?? makeCropSprite(tile: tile)
                sprite.texture = assets.texture(name)
                if let spec = AssetManifest.spec(named: name) {
                    sprite.size = CGSize(width: CGFloat(spec.tilesWide) * World.tileSize, height: CGFloat(spec.tilesHigh) * World.tileSize)
                    sprite.anchorPoint = CGPoint(x: 0.5, y: CGFloat(spec.anchorY))
                }
                if plotNodes.crop != nil && old.stage != shown.stage {
                    // A little "grew!" pop when the stage changes.
                    sprite.setScale(0.92)
                    sprite.run(.scale(to: 1, duration: 0.25))
                }
                plotNodes.crop = sprite
                setReadyDecoration(sprite, ready: shown.stage == CropDefinition.stageCount - 1)
            } else if let sprite = plotNodes.crop {
                sprite.removeFromParent()
                plotNodes.crop = nil
            }
        }
        plotNodes.shown = shown
    }

    private func makeCropSprite(tile: TileCoord) -> SKSpriteNode {
        let sprite = SKSpriteNode(texture: nil)
        // Plants stand in the middle of their soil tile.
        sprite.position = World.point(tile.center)
        sprite.zPosition = World.depth(forY: sprite.position.y)
        objectLayer.addChild(sprite)
        return sprite
    }

    /// Ripe crops twinkle now and then so they're easy to spot.
    private func setReadyDecoration(_ sprite: SKSpriteNode, ready: Bool) {
        let key = "sparkle"
        sprite.childNode(withName: key)?.removeFromParent()
        guard ready else { return }
        let sparkle = SKSpriteNode(texture: assets.texture("fx_sparkle"))
        sparkle.name = key
        sparkle.size = CGSize(width: World.tileSize * 0.3, height: World.tileSize * 0.3)
        let seed = abs(Int(sprite.position.x * 3 + sprite.position.y * 7))
        sparkle.position = CGPoint(x: CGFloat(seed % 30) - 15, y: sprite.size.height * 0.55 + CGFloat(seed % 11))
        sparkle.alpha = 0
        sparkle.zPosition = 1
        sprite.addChild(sparkle)
        let twinkle = SKAction.sequence([
            .wait(forDuration: 1.5 + Double(seed % 25) / 10),
            .group([.fadeIn(withDuration: 0.25), .rotate(byAngle: .pi / 2, duration: 0.5)]),
            .fadeOut(withDuration: 0.35),
        ])
        sparkle.run(.repeatForever(twinkle))
    }

    /// One of three pictures of the soil, picked by position (so it stays the
    /// same when the plot gets watered).
    private func soilName(wet: Bool, tile: TileCoord) -> String {
        let variant = ["", "_2", "_3"][abs(tile.x * 7 + tile.y * 13) % 3]
        return (wet ? "field_soil_watered" : "field_soil_plowed") + variant
    }

    /// Grass over the soil's border on each side that meets the meadow.
    private func setEdges(_ plotNodes: PlotNodes, _ edges: Edges) {
        for node in plotNodes.edgeNodes { node.removeFromParent() }
        plotNodes.edgeNodes = []
        let sides: [(Edges, String)] = [(.north, "field_edge_n"), (.east, "field_edge_e"),
                                        (.south, "field_edge_s"), (.west, "field_edge_w")]
        for (side, name) in sides where edges.contains(side) {
            let node = SKSpriteNode(texture: assets.texture(name))
            node.size = plotNodes.soil.size
            node.zPosition = 0.01
            plotNodes.soil.addChild(node)
            plotNodes.edgeNodes.append(node)
        }
    }
}

/// Short, satisfying feedback animations for farming actions.
@MainActor
enum FieldEffects {

    static func plowed(at tile: TileCoord, in layer: SKNode, assets: AssetCatalog) {
        let center = World.point(tile.center)
        for k in 0..<4 {
            let puff = SKSpriteNode(texture: assets.texture("fx_dust_puff"))
            puff.size = CGSize(width: 26, height: 26)
            puff.position = center
            puff.zPosition = 20
            puff.alpha = 0.9
            layer.addChild(puff)
            let angle = CGFloat(k) * .pi / 2 + 0.4
            puff.run(.sequence([
                .group([
                    .moveBy(x: cos(angle) * 22, y: sin(angle) * 14 + 8, duration: 0.45),
                    .scale(to: 1.8, duration: 0.45),
                    .fadeOut(withDuration: 0.45),
                ]),
                .removeFromParent(),
            ]))
        }
    }

    static func planted(at tile: TileCoord, in layer: SKNode, assets: AssetCatalog) {
        let puff = SKSpriteNode(texture: assets.texture("fx_dust_puff"))
        puff.size = CGSize(width: 30, height: 20)
        puff.position = World.point(tile.center)
        puff.zPosition = 20
        layer.addChild(puff)
        puff.run(.sequence([.group([.scale(to: 1.6, duration: 0.35), .fadeOut(withDuration: 0.35)]), .removeFromParent()]))
    }

    static func watered(at tile: TileCoord, in layer: SKNode, assets: AssetCatalog) {
        let drops = SKSpriteNode(texture: assets.texture("fx_water_drops"))
        drops.size = CGSize(width: World.tileSize * 0.7, height: World.tileSize * 0.7)
        drops.position = CGPoint(x: World.point(tile.center).x, y: World.point(tile.center).y + 40)
        drops.zPosition = 20
        drops.alpha = 0
        layer.addChild(drops)
        drops.run(.sequence([
            .fadeIn(withDuration: 0.08),
            .group([.moveBy(x: 0, y: -34, duration: 0.4), .sequence([.wait(forDuration: 0.2), .fadeOut(withDuration: 0.2)])]),
            .removeFromParent(),
        ]))
    }

    static func harvested(at tile: TileCoord, itemIcon: String, amount: Int, in layer: SKNode, assets: AssetCatalog) {
        let center = World.point(tile.center)
        let pop = SKSpriteNode(texture: assets.texture("fx_harvest_pop"))
        pop.size = CGSize(width: World.tileSize * 0.6, height: World.tileSize * 0.6)
        pop.position = CGPoint(x: center.x, y: center.y + 20)
        pop.zPosition = 20
        layer.addChild(pop)
        pop.run(.sequence([.group([.scale(to: 2, duration: 0.4), .fadeOut(withDuration: 0.4)]), .removeFromParent()]))

        // "+3 🥕" floating up.
        let badge = SKNode()
        badge.position = CGPoint(x: center.x, y: center.y + 60)
        badge.zPosition = 30
        let icon = SKSpriteNode(texture: assets.texture(itemIcon))
        icon.size = CGSize(width: 34, height: 34)
        icon.position = CGPoint(x: 18, y: 10)
        badge.addChild(icon)
        for (offset, color) in [(CGPoint(x: 1.5, y: -1.5), SKColor(white: 0, alpha: 0.45)), (.zero, SKColor.white)] {
            let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
            label.text = "+\(amount)"
            label.fontSize = 26
            label.fontColor = color
            label.horizontalAlignmentMode = .right
            label.position = CGPoint(x: offset.x, y: offset.y)
            badge.addChild(label)
        }
        layer.addChild(badge)
        badge.setScale(0.6)
        badge.run(.sequence([
            .group([.scale(to: 1, duration: 0.15), .moveBy(x: 0, y: 46, duration: 0.9)]),
            .fadeOut(withDuration: 0.3),
            .removeFromParent(),
        ]))
    }

    /// Soft red flash on a tile where an action wasn't possible.
    static func refused(at tile: TileCoord, in layer: SKNode, assets: AssetCatalog) {
        let node = SKSpriteNode(texture: assets.texture("fx_tile_highlight"))
        node.size = CGSize(width: World.tileSize, height: World.tileSize)
        node.position = World.point(tile.center)
        node.color = SKColor(red: 0.95, green: 0.35, blue: 0.3, alpha: 1)
        node.colorBlendFactor = 0.8
        node.zPosition = 5
        layer.addChild(node)
        node.run(.sequence([.fadeOut(withDuration: 0.5), .removeFromParent()]))
    }
}
