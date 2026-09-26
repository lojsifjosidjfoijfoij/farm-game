import SpriteKit
import UIKit
import AcresCore

/// The world view. Renders the simulation owned by `GameController`; it never
/// changes game rules itself. Input here is camera movement and taps.
@MainActor
final class GameScene: SKScene, UIGestureRecognizerDelegate {
    private let game: GameController
    private let assets = AssetCatalog.shared

    private let groundLayer = SKNode()
    private let flatLayer = SKNode()
    private let objectLayer = SKNode()
    private let cameraNode = SKCameraNode()
    /// Full-screen color multiplied over the world: the day/night grade.
    private let gradeOverlay = SKSpriteNode(color: .white, size: CGSize(width: 16, height: 16))

    private var cameraController: CameraController?
    private var chunks: ChunkManager?
    private var truckNode: SKNode?
    private var truckShadow: SKNode?
    private var gestures: [UIGestureRecognizer] = []
    private var lastUpdateTime: TimeInterval?
    private var lastLightingHour: Double = -1
    private var presentationTimer: TimeInterval = 0

    var showsChunkBorders = false {
        didSet { chunks?.showsBorders = showsChunkBorders }
    }

    init(game: GameController) {
        self.game = game
        super.init(size: CGSize(width: 390, height: 844))
        scaleMode = .resizeFill
        // Grass-colored backdrop, in case anything peeks past the loaded chunks.
        backgroundColor = SKColor(red: 0.45, green: 0.57, blue: 0.32, alpha: 1)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Setup

    override func didMove(to view: SKView) {
        if cameraController == nil {
            buildWorld()
        }
        installGestures(on: view)
    }

    override func willMove(from view: SKView) {
        for gesture in gestures { view.removeGestureRecognizer(gesture) }
        gestures.removeAll()
    }

    private func buildWorld() {
        let map = game.map
        flatLayer.zPosition = ZLayer.flat
        addChild(groundLayer)
        addChild(flatLayer)
        addChild(objectLayer)

        camera = cameraNode
        addChild(cameraNode)
        gradeOverlay.blendMode = .multiply
        gradeOverlay.zPosition = ZLayer.lightingOverlay
        cameraNode.addChild(gradeOverlay)
        resizeOverlay()

        // Warm the texture cache so the first frames don't hitch.
        assets.preload(["terrain_grass", "terrain_dirt", "terrain_gravel", "terrain_asphalt", "terrain_variation",
                        "fx_shadow_soft", "fx_smoke_puff", "fx_tile_highlight"])

        chunks = ChunkManager(
            map: map, terrain: TerrainRenderer(assets: assets), factory: WorldObjectFactory(assets: assets),
            groundLayer: groundLayer, flatLayer: flatLayer, objectLayer: objectLayer)
        chunks?.showsBorders = showsChunkBorders

        let bounds = World.rect(map.bounds)
        let camera = CameraController(camera: cameraNode, worldBounds: bounds, center: World.point(HomeValleyMap.farmCenter))
        camera.viewSize = size
        if let saved = game.presentation.cameraZoom {
            camera.setZoom(CGFloat(saved))
        }
        let start = game.presentation.cameraCenter ?? HomeValleyMap.farmCenter
        camera.focus(on: World.point(start), animated: false)
        cameraController = camera

        placeTruck()
        game.onWorldReset = { [weak self] in self?.worldWasReset() }
        chunks?.update(visibleRect: camera.visibleRect)
        updateLighting(force: true)
    }

    private func placeTruck() {
        truckNode?.removeFromParent()
        truckShadow?.removeFromParent()
        let nodes = WorldObjectFactory(assets: assets).makeTruck(game.simulation.state.truck)
        objectLayer.addChild(nodes.main)
        truckNode = nodes.main
        if let shadow = nodes.shadow {
            flatLayer.addChild(shadow)
            truckShadow = shadow
        }
    }

    /// Called after a reset or a big time jump: rebuild what depends on state.
    private func worldWasReset() {
        placeTruck()
        if game.presentation.cameraCenter == nil {
            cameraController?.focus(on: World.point(HomeValleyMap.farmCenter), animated: true)
        }
        updateLighting(force: true)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        cameraController?.viewSize = size
        resizeOverlay()
    }

    private func resizeOverlay() {
        // Generously oversized: camera children may be scaled with the camera.
        gradeOverlay.size = CGSize(width: size.width * 4, height: size.height * 4)
    }

    // MARK: Frame loop

    override func update(_ currentTime: TimeInterval) {
        // Clamp: after a pause (app switch, debugger) don't jump the world forward here;
        // offline time is handled by GameController's catch-up instead.
        let dt = lastUpdateTime.map { min(max(currentTime - $0, 0), 0.1) } ?? 0
        lastUpdateTime = currentTime

        game.update(dt: dt)
        guard let camera = cameraController else { return }
        camera.update(dt: dt)
        chunks?.update(visibleRect: camera.visibleRect)
        updateLighting(force: false)

        // Remember where the player was looking (saved with the game).
        presentationTimer += dt
        if presentationTimer > 1 {
            presentationTimer = 0
            game.presentation.cameraCenter = World.tiles(camera.center)
            game.presentation.cameraZoom = Double(camera.zoom)
        }
    }

    private func updateLighting(force: Bool) {
        let hour = game.simulation.state.clock.hourOfDay
        // ~40 in-game seconds between updates is plenty for a slow sky.
        guard force || abs(hour - lastLightingHour) > 0.01 else { return }
        lastLightingHour = hour
        let light = DayNightCurve.lighting(atHour: hour)
        gradeOverlay.color = SKColor(red: CGFloat(light.tint.r), green: CGFloat(light.tint.g), blue: CGFloat(light.tint.b), alpha: 1)
        chunks?.setLightIntensity(CGFloat(light.nightLights))
    }

    // MARK: Input

    private func installGestures(on view: SKView) {
        guard gestures.isEmpty else { return }
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.maximumNumberOfTouches = 2
        pan.delegate = self
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        pinch.delegate = self
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tap.delegate = self
        gestures = [pan, pinch, tap]
        for gesture in gestures { view.addGestureRecognizer(gesture) }
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Pan and pinch together: two fingers can move and zoom at once.
        !(gestureRecognizer is UITapGestureRecognizer || otherGestureRecognizer is UITapGestureRecognizer)
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let view = gesture.view, let camera = cameraController else { return }
        switch gesture.state {
        case .began:
            camera.beginDrag()
        case .changed:
            camera.drag(byScreenDelta: gesture.translation(in: view))
            gesture.setTranslation(.zero, in: view)
        case .ended, .cancelled, .failed:
            camera.endDrag(screenVelocity: gesture.velocity(in: view))
        default:
            break
        }
    }

    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        guard let view = gesture.view, let camera = cameraController else { return }
        if gesture.state == .changed, gesture.scale > 0 {
            camera.zoom(by: 1 / gesture.scale, around: gesture.location(in: view))
            gesture.scale = 1
        }
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let view = gesture.view, let camera = cameraController else { return }
        let point = camera.worldPoint(fromScreen: gesture.location(in: view))

        // Tap the truck: the camera glides to it.
        if let truck = truckNode, truck.calculateAccumulatedFrame().contains(point) {
            camera.focus(on: truck.position, animated: true)
            Haptics.tap()
            return
        }
        // Otherwise highlight the tapped tile (fields and actions arrive in Phase 2).
        let tile = TileCoord(containing: World.tiles(point))
        guard game.map.isInside(tile) else { return }
        showTileHighlight(tile)
        Haptics.selection()
    }

    private func showTileHighlight(_ tile: TileCoord) {
        let node = SKSpriteNode(texture: assets.texture("fx_tile_highlight"))
        node.size = CGSize(width: World.tileSize, height: World.tileSize)
        node.position = World.point(tile.center)
        node.zPosition = 5
        node.alpha = 0
        node.setScale(0.85)
        flatLayer.addChild(node)
        node.run(.sequence([
            .group([.fadeAlpha(to: 1, duration: 0.08), .scale(to: 1, duration: 0.12)]),
            .wait(forDuration: 0.35),
            .fadeOut(withDuration: 0.4),
            .removeFromParent(),
        ]))
    }
}
