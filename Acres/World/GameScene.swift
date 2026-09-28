import SpriteKit
import UIKit
import AcresCore

/// The world view. Renders the simulation owned by `GameController`; it never
/// changes game rules itself. Input: camera movement, taps, long-presses and
/// drag-painting over fields.
@MainActor
final class GameScene: SKScene, UIGestureRecognizerDelegate {
    private let game: GameController
    private let assets = AssetCatalog.shared

    private let groundLayer = SKNode()
    private let flatLayer = SKNode()
    private let objectLayer = SKNode()
    /// Particles and floating labels, above standing objects.
    private let effectsLayer = SKNode()
    private let cameraNode = SKCameraNode()
    /// Full-screen color multiplied over the world: the day/night grade.
    private let gradeOverlay = SKSpriteNode(color: .white, size: CGSize(width: 16, height: 16))

    private var cameraController: CameraController?
    private var chunks: ChunkManager?
    private var fields: FieldRenderer?
    private var trees: TreeRenderer?
    private var ranch: RanchRenderer?
    private var farmer: FarmerRenderer?
    private var store: StoreRenderer?
    private var estate: EstateRenderer?
    private var terrain: TerrainRenderer?
    private var weather: WeatherRenderer?
    private var lastWeather: Weather?
    private var shownJobRevision = -1
    private var truck: TruckRenderer?
    /// Pulsing ring on the tile the tutorial points at.
    private let tutorialRing = SKSpriteNode(texture: nil)
    /// Bouncing arrow above the current goal (e.g. the market).
    private let goalMarker = SKSpriteNode(texture: nil)
    /// Where tap-to-drive is heading.
    private let destinationMarker = SKSpriteNode(texture: nil)
    private var gestures: [UIGestureRecognizer] = []
    private var lastUpdateTime: TimeInterval?
    private var lastLightingHour: Double = -1
    private var presentationTimer: TimeInterval = 0
    private var fieldSyncTimer: TimeInterval = 0
    private var syncedFarmRevision = -1

    /// What a one-finger drag is doing: moving the camera or painting actions.
    private enum DragMode { case none, camera, paint }
    private var dragMode = DragMode.none
    private var lastPaintTile: TileCoord?

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
        effectsLayer.zPosition = ZLayer.effects
        addChild(groundLayer)
        addChild(flatLayer)
        addChild(objectLayer)
        addChild(effectsLayer)

        camera = cameraNode
        addChild(cameraNode)
        gradeOverlay.blendMode = .multiply
        gradeOverlay.zPosition = ZLayer.lightingOverlay
        cameraNode.addChild(gradeOverlay)
        resizeOverlay()

        // Warm the texture cache so the first frames don't hitch.
        assets.preload(["terrain_grass", "terrain_dirt", "terrain_gravel", "terrain_asphalt", "terrain_variation",
                        "fx_shadow_soft", "fx_smoke_puff", "fx_tile_highlight", "field_soil_plowed", "field_soil_watered"])

        let terrainRenderer = TerrainRenderer(assets: assets)
        terrain = terrainRenderer
        let chunkManager = ChunkManager(
            map: map, terrain: terrainRenderer, factory: WorldObjectFactory(assets: assets),
            groundLayer: groundLayer, flatLayer: flatLayer, objectLayer: objectLayer)
        chunkManager.showsBorders = showsChunkBorders
        chunkManager.isTileCleared = { [weak self] tile in
            guard let state = self?.game.simulation.state else { return false }
            // No weeds on fields, under the farm's buildings or at sprinklers.
            return state.plots[tile] != nil || state.estate.isOccupied(tile)
                || (state.estate.storageLevel > 0 && EstateLayout.blockedTiles(state.estate).contains(tile))
        }
        chunkManager.isMapTreeHidden = { [weak self] tile in
            self?.game.simulation.state.woodland.hiddenMapTrees.contains(tile) ?? false
        }
        chunks = chunkManager
        fields = FieldRenderer(assets: assets, flatLayer: flatLayer, objectLayer: objectLayer)
        trees = TreeRenderer(assets: assets, flatLayer: flatLayer, objectLayer: objectLayer)
        ranch = RanchRenderer(assets: assets, flatLayer: flatLayer, objectLayer: objectLayer, effectsLayer: effectsLayer)

        let bounds = World.rect(map.bounds)
        let camera = CameraController(camera: cameraNode, worldBounds: bounds, center: World.point(HomeValleyMap.farmCenter))
        camera.viewSize = size
        if let saved = game.presentation.cameraZoom {
            camera.setZoom(CGFloat(saved))
        }
        let start = game.presentation.cameraCenter ?? HomeValleyMap.farmCenter
        camera.focus(on: World.point(start), animated: false)
        cameraController = camera

        truck = TruckRenderer(assets: assets, objectLayer: objectLayer, flatLayer: flatLayer, effectsLayer: effectsLayer)
        farmer = FarmerRenderer(assets: assets, objectLayer: objectLayer, flatLayer: flatLayer, effectsLayer: effectsLayer)
        store = StoreRenderer(assets: assets, objectLayer: objectLayer, flatLayer: flatLayer)
        estate = EstateRenderer(assets: assets, objectLayer: objectLayer, flatLayer: flatLayer, effectsLayer: effectsLayer)
        estate?.sync(game: game, force: true)
        weather = WeatherRenderer(layer: effectsLayer, assets: assets)
        updateSeason()
        setUpMarkers()
        game.onWorldReset = { [weak self] in self?.worldWasReset() }
        game.onFeedback = { [weak self] feedback in self?.play(feedback) }
        chunkManager.update(visibleRect: camera.visibleRect)
        syncFields()
        updateTruck()
        updateLighting(force: true)
    }

    private func setUpMarkers() {
        tutorialRing.texture = assets.texture("fx_tile_highlight")
        tutorialRing.size = CGSize(width: World.tileSize, height: World.tileSize)
        tutorialRing.color = SKColor(red: 1, green: 0.85, blue: 0.35, alpha: 1)
        tutorialRing.colorBlendFactor = 0.7
        tutorialRing.zPosition = 6
        tutorialRing.isHidden = true
        flatLayer.addChild(tutorialRing)
        tutorialRing.run(.repeatForever(.sequence([
            .group([.scale(to: 1.15, duration: 0.5), .fadeAlpha(to: 0.6, duration: 0.5)]),
            .group([.scale(to: 1, duration: 0.5), .fadeAlpha(to: 1, duration: 0.5)]),
        ])))

        goalMarker.texture = assets.texture("fx_guide_arrow")
        goalMarker.size = CGSize(width: World.tileSize * 1.2, height: World.tileSize * 1.2)
        goalMarker.zRotation = -.pi / 2  // point down at the goal
        goalMarker.zPosition = 20
        goalMarker.isHidden = true
        effectsLayer.addChild(goalMarker)
        goalMarker.run(.repeatForever(.sequence([
            .moveBy(x: 0, y: 18, duration: 0.45),
            .moveBy(x: 0, y: -18, duration: 0.45),
        ])))

        destinationMarker.texture = assets.texture("fx_tile_highlight")
        destinationMarker.size = CGSize(width: World.tileSize * 1.3, height: World.tileSize * 1.3)
        destinationMarker.color = SKColor(red: 0.45, green: 0.75, blue: 1, alpha: 1)
        destinationMarker.colorBlendFactor = 0.7
        destinationMarker.zPosition = 6
        destinationMarker.isHidden = true
        flatLayer.addChild(destinationMarker)
    }

    /// Called after a reset or a big time jump: rebuild what depends on state.
    private func worldWasReset() {
        updateTruck()
        dragMode = .none
        // Weeds may need to come back (after a reset), so reload the chunks.
        chunks?.unloadAll()
        fields?.removeAll()
        trees?.removeAll()
        ranch?.removeAll()
        estate?.sync(game: game, force: true)
        if let camera = cameraController {
            if game.presentation.cameraCenter == nil {
                camera.focus(on: World.point(HomeValleyMap.farmCenter), animated: true)
            }
            chunks?.update(visibleRect: camera.visibleRect)
        }
        syncFields()
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
        updateTruck()
        farmer?.update(game.farmerVisual, dt: dt)
        if game.jobRevision != shownJobRevision {
            shownJobRevision = game.jobRevision
            farmer?.showMarkers(game.jobMarkers)
        }
        if game.isDriving && !game.cameraFollowPaused {
            // Trail the truck, looking a little ahead of where it's going.
            let velocity = game.motion.velocity
            let lookAhead = Vec2(game.truckState.position.x + velocity.x * 0.35, game.truckState.position.y + velocity.y * 0.35)
            camera.follow(World.point(lookAhead))
        } else if camera.isFollowing {
            camera.follow(nil)
        }
        camera.update(dt: dt)
        chunks?.update(visibleRect: camera.visibleRect)
        ranch?.update(dt: dt)
        store?.update(store: game.storeState, hour: game.hour, dt: dt)
        estate?.update(game: game, dt: dt)
        updateSeason()
        weather?.update(weather: game.weather, visible: camera.visibleRect, dt: dt)
        updateLighting(force: false)

        // Crops change slowly: re-check a few times a second, or at once after an action.
        fieldSyncTimer += dt
        if fieldSyncTimer > 0.25 || game.farmRevision != syncedFarmRevision {
            syncFields()
        }

        // Remember where the player was looking (saved with the game).
        presentationTimer += dt
        if presentationTimer > 1 {
            presentationTimer = 0
            game.presentation.cameraCenter = World.tiles(camera.center)
            game.presentation.cameraZoom = Double(camera.zoom)
        }
    }

    private func syncFields() {
        fieldSyncTimer = 0
        syncedFarmRevision = game.farmRevision
        guard let chunks else { return }
        let state = game.simulation.state
        fields?.sync(plots: state.plots, now: state.worldTime) { tile in
            chunks.isLoaded(WorldMap.chunk(containing: tile.center))
        }
        trees?.sync(woodland: state.woodland, forestry: game.forestry) { tile in
            chunks.isLoaded(WorldMap.chunk(containing: tile.center))
        }
        ranch?.sync(ranch: state.ranch, now: state.worldTime, inventory: state.inventory)
        estate?.sync(game: game)
        updateMarkers()
    }

    private func updateTruck() {
        truck?.update(truck: game.truckState, speed: game.motion.speed, surface: game.truckSurface,
                      cargoFraction: game.cargoFraction, guideTarget: game.isDriving ? game.guideTarget : nil)
        if let destination = game.destination {
            destinationMarker.position = World.point(destination)
            destinationMarker.isHidden = false
        } else {
            destinationMarker.isHidden = true
        }
    }

    /// Tutorial highlights (refreshed with the fields, a few times a second).
    private func updateMarkers() {
        if let tile = game.tutorialTargetTile, !game.isDriving {
            tutorialRing.position = World.point(tile.center)
            tutorialRing.isHidden = false
        } else {
            tutorialRing.isHidden = true
        }
        if let goal = game.guideTarget {
            let point = World.point(goal)
            if goalMarker.isHidden || abs(goalMarker.position.x - point.x) > 1 {
                goalMarker.position = CGPoint(x: point.x, y: point.y + World.tileSize * 1.6)
            }
            goalMarker.isHidden = false
        } else {
            goalMarker.isHidden = true
        }
    }

    /// Seasons change the leaves and the grass; snow lies in winter.
    private func updateSeason() {
        let season = game.season
        let snow = season == .winter ? (game.weather == .snow ? 0.7 : 0.3) : 0
        terrain?.setSeason(season, snowCover: snow)
        if chunks?.season != season {
            chunks?.season = season
            trees?.season = season
            estate?.sync(game: game, force: true)
            syncFields()
        }
        if lastWeather != game.weather {
            lastWeather = game.weather
            updateLighting(force: true)
        }
    }

    private func updateLighting(force: Bool) {
        let hour = game.simulation.state.clock.hourOfDay
        // ~40 in-game seconds between updates is plenty for a slow sky.
        guard force || abs(hour - lastLightingHour) > 0.01 else { return }
        lastLightingHour = hour
        let light = DayNightCurve.lighting(atHour: hour)
        // Grey skies dim and cool the light a little.
        let sky: (r: Double, g: Double, b: Double) = switch game.weather {
        case .sunny: (1, 1, 1)
        case .cloudy: (0.9, 0.92, 0.95)
        case .rain: (0.76, 0.8, 0.88)
        case .snow: (0.93, 0.95, 1)
        }
        gradeOverlay.color = SKColor(red: CGFloat(light.tint.r * sky.r), green: CGFloat(light.tint.g * sky.g),
                                     blue: CGFloat(light.tint.b * sky.b), alpha: 1)
        chunks?.setLightIntensity(CGFloat(light.nightLights))
        ranch?.nightLevel = CGFloat(light.nightLights)
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
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.minimumPressDuration = 0.4
        longPress.delegate = self
        gestures = [pan, pinch, tap, longPress]
        for gesture in gestures { view.addGestureRecognizer(gesture) }
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Only pan + pinch run together: two fingers can move and zoom at once.
        let pair: (UIGestureRecognizer) -> Bool = { $0 is UIPanGestureRecognizer || $0 is UIPinchGestureRecognizer }
        return pair(gestureRecognizer) && pair(otherGestureRecognizer)
    }

    private func tile(atScreen point: CGPoint) -> TileCoord? {
        guard let camera = cameraController else { return nil }
        return TileCoord(containing: World.tiles(camera.worldPoint(fromScreen: point)))
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let view = gesture.view, let camera = cameraController else { return }
        switch gesture.state {
        case .began:
            let location = gesture.location(in: view)
            let moved = gesture.translation(in: view)
            let start = CGPoint(x: location.x - moved.x, y: location.y - moved.y)
            if game.isDriving {
                // Driving: a drag looks around (the camera stops following
                // until the next tap-to-drive).
                game.cameraFollowPaused = true
                camera.follow(nil)
                dragMode = .camera
                camera.beginDrag()
                return
            }
            // One finger starting on farmland lines up a row of jobs; anything else moves the camera.
            if gesture.numberOfTouches == 1, let startTile = tile(atScreen: start), game.beginPaint(at: startTile) {
                dragMode = .paint
                lastPaintTile = startTile
                paint(to: location)
            } else {
                dragMode = .camera
                camera.beginDrag()
            }
        case .changed:
            switch dragMode {
            case .paint:
                paint(to: gesture.location(in: view))
            case .camera:
                camera.drag(byScreenDelta: gesture.translation(in: view))
                gesture.setTranslation(.zero, in: view)
            case .none:
                break
            }
        case .ended, .cancelled, .failed:
            switch dragMode {
            case .paint: game.endPaint()
            case .camera: camera.endDrag(screenVelocity: gesture.velocity(in: view))
            case .none: break
            }
            dragMode = .none
            lastPaintTile = nil
        default:
            break
        }
    }

    /// Applies the paint action to every tile between the last one and the finger.
    private func paint(to screenPoint: CGPoint) {
        guard let target = tile(atScreen: screenPoint), let last = lastPaintTile, target != last else { return }
        for tile in Self.tiles(from: last, to: target) {
            game.paint(tile)
        }
        lastPaintTile = target
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

        if game.isDriving {
            // Tap to drive there.
            game.driveTo(World.tiles(point))
            showTapRipple(at: point, color: SKColor(red: 0.45, green: 0.75, blue: 1, alpha: 1))
            return
        }
        // Tap the truck to walk over and hop in.
        if let body = truck?.body, body.calculateAccumulatedFrame().contains(point) {
            game.tapTruck()
            return
        }
        let spot = World.tiles(point)
        guard game.map.isInside(TileCoord(containing: spot)) else { return }
        game.handleTap(at: spot)
        showTapRipple(at: point, color: .white)
    }

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began, let view = gesture.view, let camera = cameraController else { return }
        let spot = World.tiles(camera.worldPoint(fromScreen: gesture.location(in: view)))
        let tile = TileCoord(containing: spot)
        guard game.map.isInside(tile) else { return }
        if game.simulation.state.plots[tile] == nil {
            if let treeTile = game.treeTile(at: spot) {
                game.inspect(.tree(treeTile))
                return
            }
            if let pen = PenCatalog.pen(tappedAt: spot) {
                game.inspect(.pen(pen.id))
                return
            }
        }
        game.inspect(.tile(tile))
        showTileHighlight(tile)
    }

    // MARK: Feedback

    private func showFeedback(_ outcome: FarmOutcome, at tile: TileCoord, painting: Bool) {
        switch outcome {
        case .plowed: Sound.play(.plow, volume: 0.8)
        case .planted: Sound.play(.plant, volume: 0.7)
        case .watered: Sound.play(.water, volume: 0.6)
        case .harvested: Sound.play(.harvest)
        case .failed: break
        }
        switch outcome {
        case .plowed:
            chunks?.clearDecor(at: tile)
            FieldEffects.plowed(at: tile, in: effectsLayer, assets: assets)
        case .planted:
            FieldEffects.planted(at: tile, in: effectsLayer, assets: assets)
        case .watered:
            FieldEffects.watered(at: tile, in: effectsLayer, assets: assets)
        case .harvested(let cropID, let amount, _):
            FieldEffects.harvested(at: tile, itemIcon: "item_\(cropID)", amount: amount, in: effectsLayer, assets: assets)
        case .failed(let failure):
            if !painting || failure == .storageFull {
                FieldEffects.refused(at: tile, in: flatLayer, assets: assets)
            }
        }
        if outcome.succeeded { syncFields() }
    }

    /// A soft ring where the finger landed.
    private func showTapRipple(at point: CGPoint, color: SKColor) {
        let ring = SKSpriteNode(texture: assets.texture("fx_tile_highlight"))
        ring.size = CGSize(width: World.tileSize * 0.7, height: World.tileSize * 0.7)
        ring.position = point
        ring.color = color
        ring.colorBlendFactor = 0.5
        ring.zPosition = 5
        flatLayer.addChild(ring)
        ring.run(.sequence([.group([.scale(to: 1.5, duration: 0.35), .fadeOut(withDuration: 0.35)]), .removeFromParent()]))
    }

    /// Animations for pen, tree and field work.
    private func play(_ feedback: WorldFeedback) {
        switch feedback {
        case .field(let outcome, let tile):
            showFeedback(outcome, at: tile, painting: true)
        case .pen(let outcome, let penID):
            syncFields()
            switch outcome {
            case .collected: Sound.play(penID == "coop" ? .chicken : .harvest)
            case .fed: Sound.play(.plant, volume: 0.6)
            case .watered: Sound.play(.water, volume: 0.6)
            case .repaired: Sound.play(.chop)
            case .failed: break
            }
            switch outcome {
            case .collected(let items, _): ranch?.collected(in: penID, items: items)
            case .fed: ranch?.hearts(in: penID)
            case .watered: ranch?.watered(penID)
            case .repaired: ranch?.repaired(penID)
            case .failed: break
            }
        case .refused(let tile):
            FieldEffects.refused(at: tile, in: flatLayer, assets: assets)
        case .sprinkler(let tile):
            estate?.sync(game: game, force: true)
            estate?.spray(at: tile)
        case .workshop(let tile, let collected):
            estate?.sync(game: game, force: collected == nil)
            estate?.workshopFeedback(at: tile, collected: collected)
        case .tree(let outcome, let tile, let position):
            switch outcome {
            case .chopped(let speciesID, let logs, _):
                Sound.play(.treeFall)
                chunks?.hideMapTree(at: tile)
                TreeEffects.chopped(at: position, speciesID: speciesID, logs: logs, in: effectsLayer, assets: assets)
            case .stumpCleared:
                Sound.play(.chop)
                chunks?.hideMapTree(at: tile)
                TreeEffects.cleared(at: position, in: effectsLayer, assets: assets)
            case .picked(let itemID, let amount, _):
                Sound.play(.harvest)
                TreeEffects.picked(at: position, itemID: itemID, amount: amount, in: effectsLayer, assets: assets)
            case .planted:
                FieldEffects.planted(at: tile, in: effectsLayer, assets: assets)
            case .failed:
                FieldEffects.refused(at: tile, in: flatLayer, assets: assets)
            }
            syncFields()
        }
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

    /// Tiles on the line from `a` to `b` (excluding `a`), so fast strokes don't skip tiles.
    static func tiles(from a: TileCoord, to b: TileCoord) -> [TileCoord] {
        var result: [TileCoord] = []
        var x = a.x, y = a.y
        let dx = abs(b.x - a.x), dy = -abs(b.y - a.y)
        let sx = a.x < b.x ? 1 : -1, sy = a.y < b.y ? 1 : -1
        var error = dx + dy
        while x != b.x || y != b.y {
            let e2 = 2 * error
            if e2 >= dy { error += dy; x += sx }
            if e2 <= dx { error += dx; y += sy }
            result.append(TileCoord(x, y))
        }
        return result
    }
}
