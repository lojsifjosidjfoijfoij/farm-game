import Foundation
import AcresCore

/// Something the farmer walks to and does. Jobs are lined up by taps (and
/// drags across the field) and done one after another. Not saved: after a
/// restart the farmer just stands where they were.
struct FarmerJob: Equatable {
    enum Kind: Equatable {
        /// Plow, water or harvest; re-checked on arrival (the tile may have changed).
        case field(TileCoord, FarmAction.Kind)
        /// Planting the packet that was in hand when the job was lined up.
        case plantCrop(TileCoord, cropID: String)
        case plantTree(TileCoord, speciesID: String)
        /// The hand on a tree: pick its fruit.
        case tree(TileCoord)
        /// The axe: fell the tree or clear its stump (decided on arrival).
        case chopTree(TileCoord)
        /// Setting up a machine from the pouch (a sprinkler or a workshop).
        case placeMachine(TileCoord, kind: String)
        case pickUpSprinkler(TileCoord)
        /// Walking up to a workshop to open its panel.
        case workshop(TileCoord)
        /// Casting from the shore at a point on the water.
        case fish(Vec2)
        /// Picking up a wild find (by its spot).
        case forage(Int)
        case pen(String, repair: Bool)
        case enterTruck
        case sleep
        case walk
    }

    let kind: Kind
    /// Where the farmer stands to do it.
    let spot: Vec2
    /// Where the "lined up" marker is drawn.
    let marker: Vec2

    var tile: TileCoord? {
        switch kind {
        case .field(let tile, _), .plantCrop(let tile, _), .plantTree(let tile, _), .tree(let tile), .chopTree(let tile),
             .placeMachine(let tile, _), .pickUpSprinkler(let tile), .workshop(let tile): tile
        default: nil
        }
    }
}

/// What the farmer is doing right now (drives the animation).
enum FarmerActivity: Equatable {
    case idle
    case walking
    case working(tool: FarmerTool, progress: Double)
}

enum FarmerTool: String {
    case hoe, can, hands, axe, rod
}

/// Everything the scene needs to draw the farmer this frame.
struct FarmerVisual: Equatable {
    var position: Vec2
    /// Movement or work direction (map units).
    var facing: Vec2
    var activity: FarmerActivity
    var inTruck: Bool
    var isTired: Bool
}

extension GameController {
    /// Longest job line.
    static let maxJobs = 40

    // MARK: Lining up jobs

    /// A tap in the world (tile units). A field tool on the field does only
    /// its own job; everything else (pens, the house, walking) works the same
    /// whatever is in hand.
    func handleTap(at spot: Vec2) {
        guard welcome == nil, sleep == nil else { return }
        if fishing != nil {
            fishingTap()
            return
        }
        if isDriving {
            driveTo(spot)
            return
        }
        let state = simulation.state
        let tile = TileCoord(containing: spot)
        guard map.isInside(tile) else { return }

        if let kind = placingMachine {
            queuePlaceJob(kind, at: tile)
            return
        }
        if state.estate.sprinkler(at: tile) != nil {
            inspect(.sprinkler(tile))
            return
        }
        if let workshopTile = workshopTile(at: spot) {
            queueWorkshopJob(workshopTile)
            return
        }
        if let water = Waters.water(at: spot) {
            if tool == .rod {
                queueFishingJob(at: spot, water: water)
            } else {
                showMessage("Pick the fishing rod to fish here.")
            }
            return
        }
        if let find = forageFind(near: spot) {
            queueForageJob(find)
            return
        }
        if let project = VillageLayout.project(at: spot, in: state) {
            showVillageProject(project)
            return
        }
        // Soil first: a field tool on a field does only its own job.
        if let kind = tool.fieldAction, state.plots[tile] != nil {
            queueToolJob(kind, at: tile, reportProblems: true)
            return
        }
        if let treeTile = treeTile(at: spot) {
            if tool == .axe { queueAxeJob(treeTile) } else { queueTreeJob(treeTile) }
            return
        }
        if let pen = PenCatalog.pen(tappedAt: spot), isPenShown(pen) {
            queuePenJob(pen)
            return
        }
        if Self.farmhouseTapArea.contains(spot) {
            inspect(.farmhouse)
            return
        }
        if state.plots[tile] == nil, fieldInspection(tile) != nil {
            // A field on your land that isn't yours yet: what it costs, and a Buy button.
            inspect(.tile(tile))
            return
        }
        if tool == .hoe, isFieldTarget(tile, for: .plow) {
            queueToolJob(.plow, at: tile, reportProblems: true)
            return
        }
        if let kind = tool.fieldAction, kind != .plow, farming.plowProblem(at: tile, in: state, checkReach: false) == nil {
            // Seeds, can or sickle on bare grass of your land.
            showMessage(kind == .plant ? "Plow it first: pick the hoe." : "Nothing planted here.")
            onFeedback?(.refused(tile))
            return
        }
        if let plot = state.plots[tile] {
            // The bare hand picks ripe crops; anything else shows what's there.
            if plot.crop?.isReady == true {
                queueToolJob(.harvest, at: tile, reportProblems: true)
            } else {
                inspect(.tile(tile))
            }
            return
        }
        // Brush: say what it is (it clears as the farm grows).
        if wildLand.contains(tile) {
            showMessage(Self.overgrownMessage)
            onFeedback?(.refused(tile))
            return
        }
        // Nothing to do there: just walk over (and forget the lined-up jobs).
        let obstacles = Obstacles(map: map, state: state)
        guard !obstacles.isBlocked(tile) else { return }
        cancelJobs()
        enqueueJob(FarmerJob(kind: .walk, spot: spot, marker: spot))
    }

    /// Where a field tool counts as working the field: soil for most tools,
    /// any land of a property for the hoe.
    func isFieldTarget(_ tile: TileCoord, for kind: FarmAction.Kind) -> Bool {
        if simulation.state.plots[tile] != nil { return true }
        return kind == .plow && PropertyCatalog.property(containing: tile) != nil
    }

    /// Where tapping counts as tapping the farmhouse (its picture).
    static let farmhouseTapArea = TileRect(minX: 18.8, minY: 35.8, maxX: 23.2, maxY: 40.8)

    /// The truck was tapped (it's the drive button): hop in, walking over
    /// first if it's further away, or, already in it, get out.
    func tapTruck() {
        guard welcome == nil, sleep == nil else { return }
        if isDriving {
            park()
            return
        }
        cancelJobs()
        let truck = simulation.state.truck.position
        if simulation.state.farmer.position.distance(to: truck) < 1.8 {
            enterTruck()
        } else {
            enqueueJob(FarmerJob(kind: .enterTruck, spot: truck, marker: truck))
        }
    }

    /// Lines up one tool's job on a tile. Returns false if the tool can't
    /// work there (and, when asked, says why).
    @discardableResult
    func queueToolJob(_ kind: FarmAction.Kind, at tile: TileCoord, reportProblems: Bool) -> Bool {
        let state = simulation.state
        if kind == .plant, selectedSeed?.hasPrefix("sapling_") == true {
            guard let species = saplingInHand else {
                if reportProblems { outOfSeeds() }
                return false
            }
            guard let plot = state.plots[tile], plot.crop == nil else {
                if reportProblems { showMessage(state.plots[tile] == nil ? "Plow it first: pick the hoe." : "Something's already growing here.") }
                return false
            }
            enqueueJob(FarmerJob(kind: .plantTree(tile, speciesID: species), spot: tile.center, marker: tile.center))
            return true
        }
        switch farming.toolAction(kind, at: tile, in: state, seed: cropSeedInHand, checkReach: false) {
        case .success(let action):
            let job: FarmerJob.Kind = if case .plant(let cropID) = action { .plantCrop(tile, cropID: cropID) } else { .field(tile, kind) }
            enqueueJob(FarmerJob(kind: job, spot: tile.center, marker: tile.center))
            return true
        case .failure(let failure):
            if reportProblems { explain(failure, kind: kind, at: tile) }
            return false
        }
    }

    /// Why a tool can't work a tile, in words (only for taps, not drags).
    private func explain(_ failure: FarmFailure, kind: FarmAction.Kind, at tile: TileCoord) {
        let state = simulation.state
        let text: String?
        switch failure {
        case .notYourLand: text = "This land isn't yours (yet)."
        case .cannotPlowHere: text = "Can't plow here."
        case .overgrown: text = Self.overgrownMessage
        case .notAField: text = Self.notAFieldMessage
        case .alreadyPlowed: text = state.plots[tile]?.crop == nil ? "Already plowed. Pick the seed bag to plant it." : nil
        case .notPlowed: text = kind == .plant ? "Plow it first: pick the hoe." : "Nothing planted here."
        case .alreadyPlanted: text = "Something's already growing here."
        case .unknownCrop, .noSeeds:
            outOfSeeds()
            text = nil
        case .outOfSeason(let crop, let season):
            text = "\(CropCatalog.crop(crop)?.name ?? crop) can't be planted in \(season.name). Pick another packet."
            showsSeedPicker = true
        case .nothingToWater: text = state.plots[tile]?.crop?.isReady == true ? "It's ripe: harvest it with the sickle." : "Nothing to water here."
        case .alreadyWet: text = "Already watered."
        case .notReady:
            if let plot = state.plots[tile], plot.crop != nil,
               let eta = FarmForecast.secondsUntilReady(plot, now: state.worldTime, balance: balance) {
                text = "Not ripe yet: ready in \(Format.duration(eta))."
            } else {
                text = "Nothing to harvest here."
            }
        case .tooFar, .tooTired, .storageFull: text = nil
        }
        if let text { showMessage(text) }
        onFeedback?(.refused(tile))
    }

    /// The seed bag is empty (or nothing is picked): say so and open the picker.
    func outOfSeeds() {
        let name = selectedSeed.flatMap { CropCatalog.crop($0)?.name.lowercased() ?? TreeCatalog.species(String($0.dropFirst("sapling_".count)))?.name.lowercased() }
        showMessage(name.map { "Out of \($0) seeds. Pick another packet or buy more at the seed shop." }
                    ?? "Pick a seed packet first.")
        showsSeedPicker = true
    }

    /// The hand on a tree: pick ripe fruit (chopping takes the axe).
    func queueTreeJob(_ tile: TileCoord) {
        let state = simulation.state
        guard forestry.suggestedAction(at: tile, in: state, checkReach: false) == .pickFruit else {
            inspect(.tree(tile))
            return
        }
        enqueueJob(FarmerJob(kind: .tree(tile), spot: forestry.workSpot(for: tile, in: state), marker: forestry.position(of: tile)))
    }

    /// The axe on a tree: chop it down, or clear its stump.
    func queueAxeJob(_ tile: TileCoord, force: Bool = false) {
        let state = simulation.state
        guard force || axeAction(at: tile) != nil else {
            if let info = forestry.tree(at: tile, in: state), info.stage == .sapling || info.stage == .young {
                showMessage("Let it grow first.")
            } else if forestry.accessProblem(at: tile, in: state, checkReach: false) == .notYourLand {
                showMessage("This tree isn't on your land.")
            } else {
                inspect(.tree(tile))
            }
            return
        }
        enqueueJob(FarmerJob(kind: .chopTree(tile), spot: forestry.workSpot(for: tile, in: state), marker: forestry.position(of: tile)))
    }

    /// What the axe does to a tree: clear a stump or fell a grown tree.
    func axeAction(at tile: TileCoord, checkReach: Bool = false) -> TreeAction? {
        let state = simulation.state
        guard forestry.accessProblem(at: tile, in: state, checkReach: checkReach) == nil,
              let info = forestry.tree(at: tile, in: state) else { return nil }
        switch info.stage {
        case .stump: return .clearStump
        case .mature: return .chop
        case .sapling, .young: return nil
        }
    }

    func queuePenJob(_ pen: PenDefinition, repair: Bool = false) {
        guard repair || (ranching.suggestedAction(for: pen, in: simulation.state).map { $0 != .repair } ?? false) else {
            inspect(.pen(pen.id))
            return
        }
        let spot = Ranching.workSpot(pen)
        enqueueJob(FarmerJob(kind: .pen(pen.id, repair: repair), spot: spot, marker: spot))
    }

    /// Walks home and goes to bed.
    func goToBed() {
        guard sleep == nil else { return }
        if isDriving { park() }
        cancelJobs()
        dismissInspection()
        enqueueJob(FarmerJob(kind: .sleep, spot: HomeValleyMap.farmhouseDoor, marker: HomeValleyMap.farmhouseDoor))
        Haptics.tap()
    }

    func enqueueJob(_ job: FarmerJob) {
        if let tile = job.tile, jobs.contains(where: { $0.tile == tile }) || currentJob?.tile == tile { return }
        guard jobs.count < Self.maxJobs else {
            showMessage("That's plenty of work lined up!")
            return
        }
        jobs.append(job)
        jobsChanged()
        if job.kind != .walk { Haptics.selection() }
    }

    /// Clears the job line (the current walk stops where it is).
    func cancelJobs() {
        if fishing != nil {
            fishing = nil
            fishingHint = nil
        }
        jobs.removeAll()
        currentJob = nil
        farmerPath = []
        farmerActivity = .idle
        jobsChanged()
    }

    private func jobsChanged() {
        let count = jobs.count + (currentJob == nil || currentJob?.kind == .walk ? 0 : 1)
        if jobCount != count { jobCount = count }
        jobRevision += 1
    }

    /// Markers for lined-up jobs (the scene draws them).
    var jobMarkers: [Vec2] {
        ([currentJob].compactMap { $0 } + jobs).filter { $0.kind != .walk }.map(\.marker)
    }

    // MARK: Drag to line up a row

    /// Starts a drag: with a field tool on the field, the drag lines up that
    /// tool's job on every tile it crosses (and nothing else). Returns false
    /// otherwise (the drag moves the map).
    func beginPaint(at tile: TileCoord) -> Bool {
        guard welcome == nil, sleep == nil, !isDriving, let kind = tool.fieldAction, isFieldTarget(tile, for: kind) else { return false }
        if kind == .plant, cropSeedInHand == nil, saplingInHand == nil {
            outOfSeeds()
            return false
        }
        paintKind = kind
        queueToolJob(kind, at: tile, reportProblems: false)
        return true
    }

    func paint(_ tile: TileCoord) {
        guard let kind = paintKind else { return }
        queueToolJob(kind, at: tile, reportProblems: false)
    }

    func endPaint() {
        paintKind = nil
    }

    var isPainting: Bool { paintKind != nil }

    // MARK: Per frame

    func updateFarmer(dt: TimeInterval) {
        guard sleep == nil else { return }
        if let session = fishing {
            if farmerActivity != session.farmerActivity { farmerActivity = session.farmerActivity }
            return
        }
        let state = simulation.state
        if state.farmer.inTruck {
            if farmerActivity != .idle { farmerActivity = .idle }
            return
        }
        switch farmerActivity {
        case .working(let tool, let progress):
            let duration = currentJob.map(workDuration) ?? 0.5
            let next = progress + dt / duration
            if next >= 1 {
                farmerActivity = .idle
                if let job = currentJob {
                    currentJob = nil
                    finish(job)
                }
                jobsChanged()
            } else {
                farmerActivity = .working(tool: tool, progress: next)
            }
        case .walking:
            walk(dt: dt)
        case .idle:
            startNextJob()
        }
    }

    private func startNextJob() {
        guard !jobs.isEmpty else { return }
        let job = jobs.removeFirst()
        currentJob = job
        let from = simulation.state.farmer.position
        if from.distance(to: job.spot) < 0.15 {
            arrive()
        } else if from.distance(to: job.spot) < 2.5 {
            farmerPath = [job.spot]
            farmerActivity = .walking
        } else if var path = Pathfinder.path(on: map, woodland: simulation.state.woodland, built: builtTiles, wild: wildLand,
                                                  from: from, to: job.spot) {
            if let last = path.indices.last { path[last] = job.spot }
            farmerPath = path
            farmerActivity = .walking
        } else {
            showMessage("Your farmer can't get there.")
            currentJob = nil
        }
        jobsChanged()
    }

    private func walk(dt: TimeInterval) {
        guard !farmerPath.isEmpty else {
            arrive()
            return
        }
        let tired = simulation.state.farmer.energy <= 0
        var budget = balance.walkSpeed * (tired ? 0.55 : 1) * dt
        var position = simulation.state.farmer.position
        while budget > 0, let target = farmerPath.first {
            let delta = target - position
            let distance = delta.length
            if distance <= budget {
                position = target
                budget -= distance
                farmerPath.removeFirst()
            } else {
                position = position + delta * (budget / distance)
                budget = 0
            }
            if distance > 0.01 { farmerFacing = delta }
        }
        let moved = position
        simulation.modify { $0.farmer.position = moved }
        if farmerPath.isEmpty { arrive() }
    }

    private func arrive() {
        farmerPath = []
        guard let job = currentJob else {
            farmerActivity = .idle
            return
        }
        // Face the work.
        let target = job.tile?.center ?? job.marker
        let toward = target - simulation.state.farmer.position
        if toward.length > 0.05 { farmerFacing = toward }
        switch job.kind {
        case .walk:
            currentJob = nil
            farmerActivity = .idle
        case .enterTruck:
            currentJob = nil
            farmerActivity = .idle
            enterTruck()
        case .sleep:
            currentJob = nil
            farmerActivity = .idle
            beginSleep(passedOut: false)
        default:
            farmerActivity = .working(tool: tool(for: job), progress: 0)
        }
        jobsChanged()
    }

    private func tool(for job: FarmerJob) -> FarmerTool {
        switch job.kind {
        case .field(_, .plow): .hoe
        case .field(_, .water): .can
        case .chopTree: .axe
        case .fish: .rod
        default: .hands
        }
    }

    private func workDuration(_ job: FarmerJob) -> TimeInterval {
        switch job.kind {
        case .field(_, .plow): 0.9
        case .field(_, .plant), .plantCrop: 0.5
        case .field(_, .water), .field(_, .harvest): 0.6
        case .plantTree: 1.0
        case .chopTree: 1.6
        case .tree: 0.9
        case .placeMachine, .pickUpSprinkler: 1.0
        case .workshop: 0.35
        case .fish: 0.25
        case .forage: 0.6
        case .pen: 1.1
        default: 0.3
        }
    }

    /// Does the job's work (in the simulation) and shows what happened.
    private func finish(_ job: FarmerJob) {
        let state = simulation.state
        switch job.kind {
        case .field(let tile, let kind):
            // Re-checked on arrival: the tile may have changed meanwhile.
            guard case .success(let action) = farming.toolAction(kind, at: tile, in: state, seed: nil) else { return }
            let outcome = perform(action, at: tile, painting: true)
            onFeedback?(.field(outcome, tile: tile))
            if case .failed(.tooTired) = outcome { tooTired() }
        case .plantCrop(let tile, let cropID):
            switch farming.toolAction(.plant, at: tile, in: state, seed: cropID) {
            case .success(let action):
                let outcome = perform(action, at: tile, painting: true)
                onFeedback?(.field(outcome, tile: tile))
                if case .failed(.tooTired) = outcome { tooTired() }
            case .failure(.noSeeds), .failure(.outOfSeason):
                // The packet ran out: stop planting rather than switch seeds.
                jobs.removeAll { if case .plantCrop = $0.kind { true } else { false } }
                jobsChanged()
                outOfSeeds()
            case .failure:
                break
            }
        case .plantTree(let tile, let species):
            if case .failed(.tooTired) = performTree(.plant(speciesID: species), at: tile) { tooTired() }
        case .tree(let tile):
            guard forestry.suggestedAction(at: tile, in: state) == .pickFruit else { return }
            if case .failed(.tooTired) = performTree(.pickFruit, at: tile) { tooTired() }
        case .chopTree(let tile):
            guard let action = axeAction(at: tile, checkReach: true) else { return }
            if case .failed(.tooTired) = performTree(action, at: tile) { tooTired() }
        case .pen(let id, let repair):
            guard let pen = PenCatalog.pen(id) else { return }
            let action = repair ? .repair : ranching.suggestedAction(for: pen, in: state)
            guard let action else { return }
            if case .failed(.tooTired) = performPen(action, pen) { tooTired() }
        case .placeMachine(let tile, let kind):
            finishPlacing(kind, at: tile)
        case .pickUpSprinkler(let tile):
            finishPickingUp(at: tile)
        case .workshop(let tile):
            arrivedAtWorkshop(tile)
        case .fish(let target):
            startFishing(at: target)
        case .forage(let id):
            finishForaging(id)
        case .enterTruck, .sleep, .walk:
            break
        }
    }

    private func tooTired() {
        cancelJobs()
        showBanner("Your farmer is exhausted. Time for bed! 🛏")
        Haptics.warning()
    }

    /// Mirrors the farmer's state for the HUD (energy) and the scene.
    func refreshFarmer() {
        let energy = simulation.state.farmer.energy / balance.energyMax
        if abs(energy - energyFraction) >= 0.005 || (energy == 0 && energyFraction != 0) { energyFraction = energy }
    }

    var farmerVisual: FarmerVisual {
        let state = simulation.state
        return FarmerVisual(position: state.farmer.position, facing: farmerFacing, activity: farmerActivity,
                            inTruck: state.farmer.inTruck, isTired: state.farmer.energy <= 0)
    }

    // MARK: Sleep

    /// Fades out, sleeps through the night (the world keeps running), fades in.
    func beginSleep(passedOut: Bool) {
        guard sleep == nil else { return }
        if isDriving { park() }
        cancelJobs()
        dismissInspection()
        showsSeedPicker = false
        sleep = SleepPhase(passedOut: passedOut, elapsed: 0)
    }

    func updateSleep(dt: TimeInterval) {
        guard var phase = sleep else { return }
        let before = phase.elapsed
        phase.elapsed += dt
        // Sleep in the dark, halfway through the fade.
        if before < SleepPhase.duration / 2 && phase.elapsed >= SleepPhase.duration / 2 {
            let report = simulation.sleep(passedOut: phase.passedOut)
            handle(report.events, quiet: true)
            farmerFacing = Vec2(0, -1)
            phase.report = report
            refreshDisplay()
            refreshInventory()
            refreshFarmer()
            farmRevision += 1
            onWorldReset?()
            save()
        }
        if phase.elapsed >= SleepPhase.duration {
            sleep = nil
            advanceTutorial(.slept)
            let date = simulation.state.clock.date(daysPerSeason: balance.daysPerSeason)
            if phase.passedOut {
                showBanner("You fell asleep on your feet! You wake up at home, only half rested.")
            } else {
                showBanner("Good morning! It's \(date.weekday.name). \(weather == .rain ? "🌧" : "☀️") \(todayNews)")
            }
            if !morningNews.isEmpty {
                showBanner(([banner ?? ""] + morningNews).joined(separator: "\n"))
                morningNews = []
            }
            Haptics.success()
        } else {
            sleep = phase
        }
    }
}

/// The going-to-sleep fade.
struct SleepPhase: Equatable {
    static let duration: TimeInterval = 2.6
    var passedOut: Bool
    var elapsed: TimeInterval
    var report: SleepReport?

    /// 0 (clear) … 1 (dark) … 0.
    var darkness: Double {
        let t = elapsed / Self.duration
        return t < 0.35 ? t / 0.35 : (t < 0.65 ? 1 : max(0, (1 - t) / 0.35))
    }
}
