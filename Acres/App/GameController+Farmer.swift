import Foundation
import AcresCore

/// Something the farmer walks to and does. Jobs are lined up by taps (and
/// drags across the field) and done one after another. Not saved: after a
/// restart the farmer just stands where they were.
struct FarmerJob: Equatable {
    enum Kind: Equatable {
        /// Field work; the kind is re-checked on arrival (the tile may have changed).
        case field(TileCoord, FarmAction.Kind)
        case plantTree(TileCoord, speciesID: String)
        /// Chop, clear or pick: decided on arrival.
        case tree(TileCoord)
        /// A forced chop (the card's "Chop down" for fruit trees).
        case chopTree(TileCoord)
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
        case .field(let tile, _), .plantTree(let tile, _), .tree(let tile), .chopTree(let tile): tile
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
    case hoe, can, hands, axe
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

    /// A tap in the world (tile units): line up the sensible job there, or walk.
    func handleTap(at spot: Vec2) {
        guard welcome == nil, sleep == nil else { return }
        if isDriving {
            driveTo(spot)
            return
        }
        let state = simulation.state
        let tile = TileCoord(containing: spot)
        guard map.isInside(tile) else { return }

        // Fields first (they're what you tap most), then trees, pens, the farmhouse.
        if state.plots[tile] != nil {
            queueFieldJob(at: tile, reportProblems: true)
            return
        }
        if let treeTile = treeTile(at: spot) {
            queueTreeJob(treeTile)
            return
        }
        if let pen = PenCatalog.pen(tappedAt: spot) {
            queuePenJob(pen)
            return
        }
        if Self.farmhouseTapArea.contains(spot) {
            inspect(.farmhouse)
            return
        }
        if queueFieldJob(at: tile, reportProblems: false) { return }
        // Nothing to do there: just walk over (and forget the lined-up jobs).
        let obstacles = Obstacles(map: map, state: state)
        guard !obstacles.isBlocked(tile) else {
            if state.plots[tile] != nil || PropertyCatalog.property(containing: tile) != nil { inspect(.tile(tile)) }
            return
        }
        cancelJobs()
        enqueue(FarmerJob(kind: .walk, spot: spot, marker: spot))
    }

    /// Where tapping counts as tapping the farmhouse (its picture).
    static let farmhouseTapArea = TileRect(minX: 18.8, minY: 35.8, maxX: 23.2, maxY: 40.8)

    /// The truck was tapped: walk over and hop in.
    func tapTruck() {
        guard welcome == nil, sleep == nil, !isDriving else { return }
        cancelJobs()
        let truck = simulation.state.truck.position
        enqueue(FarmerJob(kind: .enterTruck, spot: truck, marker: truck))
    }

    /// The Drive button: same as tapping the truck.
    func startDriving() {
        if simulation.state.farmer.position.distance(to: simulation.state.truck.position) < 1.8 {
            enterTruck()
        } else {
            tapTruck()
        }
    }

    /// Lines up field work on a tile. Returns false if there's nothing to do.
    @discardableResult
    func queueFieldJob(at tile: TileCoord, reportProblems: Bool, kind wanted: FarmAction.Kind? = nil) -> Bool {
        let state = simulation.state
        if let species = resolvedSapling, let plot = state.plots[tile], plot.crop == nil, wanted == nil || wanted == .plant {
            enqueue(FarmerJob(kind: .plantTree(tile, speciesID: species), spot: tile.center, marker: tile.center))
            return true
        }
        guard let action = farming.suggestedAction(at: tile, in: state, seed: resolvedCropSeed, checkReach: false),
              wanted == nil || action.kind == wanted else {
            if reportProblems {
                // Empty soil but nothing to plant: open the seed picker.
                if let plot = state.plots[tile], plot.crop == nil,
                   farming.accessProblem(at: tile, in: state, checkReach: false) == nil, resolvedSeed() == nil {
                    showMessage("No seeds you can plant in \(season.name). Pick another packet.")
                    showsSeedPicker = true
                } else {
                    inspect(.tile(tile))
                }
            }
            return false
        }
        enqueue(FarmerJob(kind: .field(tile, action.kind), spot: tile.center, marker: tile.center))
        return true
    }

    func queueTreeJob(_ tile: TileCoord, chop: Bool = false) {
        let state = simulation.state
        guard chop || forestry.suggestedAction(at: tile, in: state, checkReach: false) != nil else {
            inspect(.tree(tile))
            return
        }
        let spot = forestry.workSpot(for: tile, in: state)
        enqueue(FarmerJob(kind: chop ? .chopTree(tile) : .tree(tile), spot: spot, marker: forestry.position(of: tile)))
    }

    func queuePenJob(_ pen: PenDefinition, repair: Bool = false) {
        guard repair || (ranching.suggestedAction(for: pen, in: simulation.state).map { $0 != .repair } ?? false) else {
            inspect(.pen(pen.id))
            return
        }
        let spot = Ranching.workSpot(pen)
        enqueue(FarmerJob(kind: .pen(pen.id, repair: repair), spot: spot, marker: spot))
    }

    /// Walks home and goes to bed.
    func goToBed() {
        guard sleep == nil else { return }
        if isDriving { park() }
        cancelJobs()
        dismissInspection()
        enqueue(FarmerJob(kind: .sleep, spot: HomeValleyMap.farmhouseDoor, marker: HomeValleyMap.farmhouseDoor))
        Haptics.tap()
    }

    private func enqueue(_ job: FarmerJob) {
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

    /// Starts a drag on the field: returns true if it lines up work (the
    /// drag then keeps lining up the same kind of job).
    func beginPaint(at tile: TileCoord) -> Bool {
        guard welcome == nil, sleep == nil, !isDriving else { return false }
        let state = simulation.state
        if resolvedSapling != nil, state.plots[tile]?.crop == nil, state.plots[tile] != nil {
            paintKind = .plant
            return queueFieldJob(at: tile, reportProblems: false, kind: .plant)
        }
        guard let action = farming.suggestedAction(at: tile, in: state, seed: resolvedCropSeed, checkReach: false) else { return false }
        paintKind = action.kind
        return queueFieldJob(at: tile, reportProblems: false, kind: action.kind)
    }

    func paint(_ tile: TileCoord) {
        guard let kind = paintKind else { return }
        queueFieldJob(at: tile, reportProblems: false, kind: kind)
    }

    func endPaint() {
        paintKind = nil
    }

    var isPainting: Bool { paintKind != nil }

    // MARK: Per frame

    func updateFarmer(dt: TimeInterval) {
        guard sleep == nil else { return }
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
        } else if var path = Pathfinder.path(on: map, woodland: simulation.state.woodland, from: from, to: job.spot) {
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
        case .tree, .chopTree: .axe
        default: .hands
        }
    }

    private func workDuration(_ job: FarmerJob) -> TimeInterval {
        switch job.kind {
        case .field(_, .plow): 0.9
        case .field(_, .plant): 0.5
        case .field(_, .water), .field(_, .harvest): 0.6
        case .plantTree: 1.0
        case .tree, .chopTree: 1.6
        case .pen: 1.1
        default: 0.3
        }
    }

    /// Does the job's work (in the simulation) and shows what happened.
    private func finish(_ job: FarmerJob) {
        let state = simulation.state
        switch job.kind {
        case .field(let tile, let kind):
            if kind == .plant, let species = resolvedSapling, state.plots[tile]?.crop == nil {
                performTree(.plant(speciesID: species), at: tile)
                return
            }
            guard let action = farming.suggestedAction(at: tile, in: state, seed: resolvedCropSeed),
                  action.kind == kind else { return }  // the tile changed meanwhile
            let outcome = perform(action, at: tile, painting: true)
            onFeedback?(.field(outcome, tile: tile))
            if case .failed(.tooTired) = outcome { tooTired() }
        case .plantTree(let tile, let species):
            if case .failed(.tooTired) = performTree(.plant(speciesID: species), at: tile) { tooTired() }
        case .tree(let tile):
            guard let action = forestry.suggestedAction(at: tile, in: state) else { return }
            if case .failed(.tooTired) = performTree(action, at: tile) { tooTired() }
        case .chopTree(let tile):
            if case .failed(.tooTired) = performTree(.chop, at: tile) { tooTired() }
        case .pen(let id, let repair):
            guard let pen = PenCatalog.pen(id) else { return }
            let action = repair ? .repair : ranching.suggestedAction(for: pen, in: state)
            guard let action else { return }
            if case .failed(.tooTired) = performPen(action, pen) { tooTired() }
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
            let date = simulation.state.clock.date(daysPerSeason: balance.daysPerSeason)
            if phase.passedOut {
                showBanner("You fell asleep on your feet! You wake up at home, only half rested.")
            } else {
                showBanner("Good morning! It's \(date.weekday.name). ☀️")
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
