import SpriteKit
import AcresCore

/// Streams the world in and out around the camera, one chunk
/// (16 × 16 tiles) at a time, so the map can grow very large while only the
/// nearby part exists as nodes.
@MainActor
final class ChunkManager {
    private final class LoadedChunk {
        let ground: SKSpriteNode
        var nodes: [SKNode] = []
        var lights: [SKNode] = []
        var border: SKNode?

        init(ground: SKSpriteNode) {
            self.ground = ground
        }
    }

    private let map: WorldMap
    private let terrain: TerrainRenderer
    private let factory: WorldObjectFactory
    private let groundLayer: SKNode
    private let flatLayer: SKNode
    private let objectLayer: SKNode
    private var loaded: [ChunkCoord: LoadedChunk] = [:]
    private var lightIntensity: CGFloat = 0
    /// Season used to pick object art. (Seasonal art arrives in Phase 7.)
    private let season: Season = .summer

    /// Chunks within this margin (in chunks) outside the screen are loaded early…
    private let loadMargin: CGFloat = 0.5
    /// …and only unloaded once they are this far away (hysteresis avoids thrashing).
    private let unloadMargin: CGFloat = 1.25
    /// Off-screen chunks created per frame, to spread the cost while panning.
    private let preloadBudgetPerFrame = 1

    var showsBorders = false {
        didSet {
            guard showsBorders != oldValue else { return }
            for (coord, chunk) in loaded { updateBorder(chunk, coord) }
        }
    }

    var loadedCount: Int { loaded.count }

    init(map: WorldMap, terrain: TerrainRenderer, factory: WorldObjectFactory,
         groundLayer: SKNode, flatLayer: SKNode, objectLayer: SKNode) {
        self.map = map
        self.terrain = terrain
        self.factory = factory
        self.groundLayer = groundLayer
        self.flatLayer = flatLayer
        self.objectLayer = objectLayer
    }

    /// Call every frame with the camera's visible rectangle (world points).
    func update(visibleRect: CGRect) {
        let visible = Set(map.chunks(overlapping: World.tileRect(visibleRect)))
        let margin = World.chunkSize * loadMargin
        let wanted = map.chunks(overlapping: World.tileRect(visibleRect.insetBy(dx: -margin, dy: -margin)))

        // On-screen chunks must exist now; nearby off-screen ones trickle in.
        var budget = preloadBudgetPerFrame
        for coord in wanted where loaded[coord] == nil {
            if visible.contains(coord) {
                load(coord)
            } else if budget > 0 {
                load(coord)
                budget -= 1
            }
        }

        let keepMargin = World.chunkSize * unloadMargin
        let keep = Set(map.chunks(overlapping: World.tileRect(visibleRect.insetBy(dx: -keepMargin, dy: -keepMargin))))
        for coord in Array(loaded.keys) where !keep.contains(coord) {
            unload(coord)
        }
    }

    /// 0 (day) … 1 (night): fades windows and lamps.
    func setLightIntensity(_ value: CGFloat) {
        guard abs(value - lightIntensity) > 0.004 else { return }
        lightIntensity = value
        for chunk in loaded.values {
            for light in chunk.lights { light.alpha = value }
        }
    }

    /// Drops every chunk (e.g. after a reset); they reload on the next update.
    func unloadAll() {
        for coord in Array(loaded.keys) { unload(coord) }
    }

    // MARK: Loading

    private func load(_ coord: ChunkCoord) {
        let ground = terrain.makeGroundNode(for: coord, in: map)
        groundLayer.addChild(ground)
        let chunk = LoadedChunk(ground: ground)

        for object in map.objects(in: coord) {
            guard let nodes = factory.makeNodes(for: object, season: season) else { continue }
            (nodes.isFlat ? flatLayer : objectLayer).addChild(nodes.main)
            chunk.nodes.append(nodes.main)
            if let shadow = nodes.shadow {
                flatLayer.addChild(shadow)
                chunk.nodes.append(shadow)
            }
            for light in nodes.lights { light.alpha = lightIntensity }
            chunk.lights += nodes.lights
        }
        loaded[coord] = chunk
        updateBorder(chunk, coord)
    }

    private func unload(_ coord: ChunkCoord) {
        guard let chunk = loaded.removeValue(forKey: coord) else { return }
        chunk.ground.removeFromParent()
        for node in chunk.nodes { node.removeFromParent() }
        chunk.border?.removeFromParent()
    }

    private func updateBorder(_ chunk: LoadedChunk, _ coord: ChunkCoord) {
        chunk.border?.removeFromParent()
        chunk.border = nil
        guard showsBorders else { return }
        let rect = World.rect(map.rect(of: coord))
        let border = SKShapeNode(rect: rect.insetBy(dx: 2, dy: 2))
        border.strokeColor = SKColor(red: 1, green: 0.3, blue: 0.9, alpha: 0.9)
        border.lineWidth = 3
        border.zPosition = ZLayer.debug
        let label = SKLabelNode(text: "\(coord.x),\(coord.y)")
        label.fontName = "Menlo-Bold"
        label.fontSize = 36
        label.fontColor = border.strokeColor
        label.position = CGPoint(x: rect.minX + 70, y: rect.maxY - 50)
        border.addChild(label)
        groundLayer.addChild(border)
        chunk.border = border
    }
}
