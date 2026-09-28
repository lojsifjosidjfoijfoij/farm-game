import Foundation
import AcresCore

/// The fishing minigame, step by step: the cast, a wait, the bite (tap!),
/// then the catch bar (tap when the marker is in the green).
struct FishingSession: Equatable {
    enum Phase: Equatable {
        case casting
        case waiting
        case bite
        case reeling
        case landed(String)
        case escaped
    }

    var phase: Phase = .casting
    /// Where the bobber floats (tile units).
    let target: Vec2
    let bite: FishBite
    /// Seconds in the current phase.
    var clock: TimeInterval = 0
    /// How long until the fish bites.
    let wait: TimeInterval
    /// The catch bar: the marker bounces between 0 and 1.
    var marker: Double = 0
    var direction: Double = 1
    let zoneCenter: Double
    let zoneWidth: Double
    /// Bar lengths per second.
    let speed: Double

    static let castTime: TimeInterval = 0.5
    static let resultTime: TimeInterval = 1.4

    init(target: Vec2, bite: FishBite) {
        self.target = target
        self.bite = bite
        let difficulty = bite.fish?.difficulty ?? 0.3
        wait = Double.random(in: 1.6...4.8)
        zoneWidth = 0.34 - 0.22 * difficulty
        zoneCenter = Double.random(in: 0.25...0.75)
        speed = 0.8 + 1.5 * difficulty
    }

    /// How long the bite waits for a tap.
    var biteWindow: TimeInterval { 1.1 - 0.45 * (bite.fish?.difficulty ?? 0.3) }

    var isInZone: Bool { abs(marker - zoneCenter) <= zoneWidth / 2 }

    var farmerActivity: FarmerActivity {
        switch phase {
        case .casting: .working(tool: .rod, progress: 0.6)
        case .waiting, .escaped: .working(tool: .rod, progress: 0)
        case .bite, .reeling, .landed: .working(tool: .rod, progress: 0.6)
        }
    }
}

extension GameController {
    var fishingRules: Fishing { Fishing(balance: balance) }
    var foragingRules: Foraging { Foraging(balance: balance) }

    // MARK: Fishing

    /// Walks to the nearest free spot on the shore, then casts at the tap.
    func queueFishingJob(at target: Vec2, water: WaterBody) {
        let obstacles = Obstacles(map: map, state: simulation.state)
        let shore = water.shoreSpots.filter { !obstacles.isBlocked(TileCoord(containing: $0)) }
        guard let spot = shore.min(by: { $0.distance(to: target) < $1.distance(to: target) }) else {
            showMessage("There's no way down to the water here.")
            return
        }
        cancelJobs()
        dismissInspection()
        enqueueJob(FarmerJob(kind: .fish(target), spot: spot, marker: target))
    }

    /// The farmer reached the shore: cast.
    func startFishing(at target: Vec2) {
        switch simulation.outdoors({ fishing, _, state in try fishing.cast(at: target, state: &state) }) {
        case .success(let bite):
            fishing = FishingSession(target: target, bite: bite)
            fishingHint = "Waiting for a bite… (tap to reel in)"
            Sound.play(.water, volume: 0.5)
            refreshFarmer()
        case .failure(let failure):
            Haptics.warning()
            if failure == .tooTired {
                showBanner("Your farmer is too tired to fish. Time for bed! 🛏")
            } else {
                showMessage(message(for: failure))
            }
        }
    }

    /// Moves the minigame on (called every frame while fishing).
    func updateFishing(dt: TimeInterval) {
        guard var session = fishing else { return }
        session.clock += dt
        switch session.phase {
        case .casting:
            if session.clock >= FishingSession.castTime { session.phase = .waiting; session.clock = 0 }
        case .waiting:
            if session.clock >= session.wait {
                session.phase = .bite
                session.clock = 0
                fishingHint = "A bite! Tap!"
                Haptics.success()
                Sound.play(.water)
            }
        case .bite:
            if session.clock >= session.biteWindow {
                session.phase = .escaped
                session.clock = 0
                fishingHint = "Too slow. It got away!"
                Haptics.warning()
            }
        case .reeling:
            session.marker += session.direction * session.speed * dt
            if session.marker >= 1 { session.marker = 2 - session.marker; session.direction = -1 }
            if session.marker <= 0 { session.marker = -session.marker; session.direction = 1 }
        case .landed, .escaped:
            if session.clock >= FishingSession.resultTime {
                fishing = nil
                fishingHint = nil
                farmerActivity = .idle
                return
            }
        }
        fishing = session
    }

    /// Any tap while fishing lands here.
    func fishingTap() {
        guard var session = fishing else { return }
        switch session.phase {
        case .casting, .waiting:
            fishing = nil
            fishingHint = nil
            farmerActivity = .idle
            showMessage("Reeled in.")
            return
        case .bite:
            session.phase = .reeling
            session.clock = 0
            session.marker = 0
            fishingHint = "Tap when the marker is in the green!"
            Haptics.tap()
        case .reeling:
            if session.isInZone {
                land(&session)
            } else {
                session.phase = .escaped
                session.clock = 0
                fishingHint = "Missed! It got away."
                Haptics.warning()
            }
        case .landed, .escaped:
            session.clock = FishingSession.resultTime
        }
        fishing = session
    }

    private func land(_ session: inout FishingSession) {
        let bite = session.bite
        switch simulation.outdoors({ fishing, _, state in try fishing.land(bite, state: &state) }) {
        case .success(let caught):
            session.phase = .landed(caught.item)
            session.clock = 0
            let fish = bite.fish
            let name = fish?.name ?? caught.item
            fishingHint = caught.isNew ? "New! \(name) · +\(caught.xp) XP" : "\(name)! +\(caught.xp) XP"
            Haptics.success()
            Sound.play(.harvest)
            if fish?.isLegendary == true {
                showBanner("A legendary \(name.lowercased())! 🏆 Worth a small fortune.")
            }
            onFeedback?(.caught(caught.item, at: session.target))
            handle(caught.events)
            afterOutdoors()
        case .failure(let failure):
            session.phase = .escaped
            session.clock = 0
            fishingHint = message(for: failure)
            Haptics.warning()
        }
    }

    // MARK: Foraging

    /// Today's wild finds (the renderer draws these).
    var forageFinds: [ForageSpawn] { foragingRules.today(simulation.state) }

    /// A find close to a tap (they're small, so taps are forgiving).
    func forageFind(near spot: Vec2) -> ForageSpawn? {
        forageFinds.filter { $0.position.distance(to: spot) < 0.8 }.min { $0.position.distance(to: spot) < $1.position.distance(to: spot) }
    }

    func queueForageJob(_ find: ForageSpawn) {
        if jobs.contains(where: { $0.kind == .forage(find.id) }) || currentJob?.kind == .forage(find.id) { return }
        let spot = find.position + Vec2(0.45, -0.3)
        enqueueJob(FarmerJob(kind: .forage(find.id), spot: spot, marker: find.position))
    }

    func finishForaging(_ id: Int) {
        switch simulation.outdoors({ _, foraging, state in try foraging.pick(id, state: &state) }) {
        case .success(let found):
            let name = ItemCatalog.item(found.item)?.name ?? found.item
            showMessage("+1 \(name.lowercased()) · +\(found.xp) XP")
            Haptics.success()
            Sound.play(.harvest, volume: 0.7)
            onFeedback?(.foraged(found.item, id: id))
            handle(found.events)
            afterOutdoors()
        case .failure(.nothingHere):
            break  // someone got there first (or the day changed)
        case .failure(let failure):
            Haptics.warning()
            showMessage(message(for: failure))
        }
    }

    // MARK: Helpers

    private func afterOutdoors() {
        refreshInventory()
        refreshDisplay()
        refreshFarmer()
        save()
    }

    func message(for failure: OutdoorFailure) -> String {
        switch failure {
        case .notWater: "Cast into the water."
        case .tooFar: "Walk closer to the water."
        case .tooTired: "Your farmer is too tired."
        case .storageFull: "Storage is full. Sell or deliver something first."
        case .nothingHere: "Nothing there anymore."
        case .inTruck: "Get out of the truck first."
        case .locked(let level): "You'll get a fishing rod at level \(level)."
        }
    }
}
