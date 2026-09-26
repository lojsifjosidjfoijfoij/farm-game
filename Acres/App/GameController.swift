import Foundation
import Observation
import SwiftUI
import AcresCore

/// A message shown in a system alert (save problems and the like).
struct GameAlert: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
}

/// What the info card shows after a long-press (or a tap with nothing to do).
struct TileInspection: Equatable {
    let tile: TileCoord
    let title: String
    let detail: String
    /// Asset name of an item icon, if the tile has a crop.
    let icon: String?
    /// SF Symbol shown when there is no icon.
    let symbol: String
}

/// A seed choice for the seed picker.
struct SeedOption: Identifiable, Equatable {
    let crop: CropDefinition
    let count: Int
    let inSeason: Bool
    var id: String { crop.id }
}

/// What a tap did, so the scene can give the right feedback.
enum TapResult: Equatable {
    case performed(FarmOutcome)
    case inspected
    case nothing
}

/// Owns the running game: the simulation, saving/loading, offline catch-up,
/// farming input and the values the HUD displays. The SpriteKit scene calls
/// `update(dt:)` every frame; SwiftUI observes the display properties.
///
/// Display properties are only assigned when they actually change, so SwiftUI
/// re-renders the HUD a few times a minute, not 60 times a second.
@MainActor
@Observable
final class GameController {

    // MARK: HUD state (observed)

    private(set) var money = 0
    private(set) var level = 1
    private(set) var levelProgress = 0.0
    private(set) var season: Season = .spring
    private(set) var dayOfSeason = 1
    private(set) var year = 1
    private(set) var timeText = ""
    private(set) var dayPhase: DayPhase = .morning
    /// A short message that fades after a few seconds ("Summer has arrived").
    private(set) var banner: String?
    /// Non-nil while the "While you were away" card is showing. The world waits.
    var welcome: AwaySummary?
    var alert: GameAlert?

    // MARK: Farm state (observed)

    private(set) var inventoryItems: [String: Int] = [:]
    private(set) var storageUsed = 0
    private(set) var selectedSeed: String?
    private(set) var inspection: TileInspection?
    var showsSeedPicker = false
    var showsInventory = false
    private(set) var remindersEnabled: Bool
    private(set) var hapticsEnabled: Bool

    // MARK: Debug (observed)

    var timeScale = 1.0
    var showsChunkBorders = false
    var showsPerformanceStats = false
    var showsDebugPanel = false

    // MARK: Model (not observed)

    @ObservationIgnored private(set) var simulation: Simulation
    let map: WorldMap = HomeValleyMap.map
    /// Camera position etc., written by the scene, stored in the save.
    @ObservationIgnored var presentation: PresentationState
    /// Lets the scene rebuild state-dependent visuals after resets and big time jumps.
    @ObservationIgnored var onWorldReset: (@MainActor () -> Void)?
    /// Bumped whenever farmland changes through an action, so the scene redraws at once.
    @ObservationIgnored private(set) var farmRevision = 0
    private let saveSystem: SaveSystem?
    private let reminders = HarvestReminders()
    @ObservationIgnored private(set) var lastSave: SaveFile?
    @ObservationIgnored private var savingEnabled = true
    @ObservationIgnored private var autosaveTimer: TimeInterval = 0
    @ObservationIgnored private var suspendedAt: Date?
    @ObservationIgnored private var bannerTimeLeft: TimeInterval = 0
    @ObservationIgnored private var inspectionTimeLeft: TimeInterval = 0
    @ObservationIgnored private var lastTimeBucket = -1
    @ObservationIgnored private var paintKind: FarmAction.Kind?
    @ObservationIgnored private var paintSeed: String?
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("jmm")  // 12 h or 24 h per the user's locale
        return formatter
    }()

    var balance: Balance { simulation.balance }
    var farming: Farming { Farming(map: map, balance: simulation.balance) }
    var storageCapacity: Int { simulation.balance.storageCapacity }

    // MARK: Lifecycle

    init() {
        let now = Date()
        let saveSystem: SaveSystem?
        do {
            let store = FileSaveStore(directory: try FileSaveStore.defaultDirectory())
            saveSystem = SaveSystem(store: store, deviceID: Self.deviceID())
        } catch {
            saveSystem = nil
        }
        self.saveSystem = saveSystem
        remindersEnabled = Settings.bool(Settings.remindersKey, default: true)
        let haptics = Settings.bool(Settings.hapticsKey, default: true)
        hapticsEnabled = haptics
        Haptics.isEnabled = haptics

        var report: OfflineReport?
        var pendingAlert: GameAlert?
        var canSave = saveSystem != nil

        switch saveSystem?.load() ?? .noSave {
        case .noSave:
            simulation = Simulation(state: .newGame(seed: UInt64.random(in: 1...UInt64.max)))
            presentation = PresentationState()

        case .loaded(let file, let fromBackup):
            var sim = Simulation(state: file.state)
            report = OfflineCatchUp.run(&sim, lastSeen: file.savedAt, now: now)
            simulation = sim
            presentation = file.presentation
            lastSave = file
            if fromBackup {
                pendingAlert = GameAlert(
                    title: "Farm restored",
                    message: "Your latest save couldn't be read, so the previous one was loaded. You may have lost a few seconds of progress.")
            }

        case .failed(let error):
            simulation = Simulation(state: .newGame(seed: UInt64.random(in: 1...UInt64.max)))
            presentation = PresentationState()
            switch error {
            case .newerVersion:
                // Never touch a save from the future: the player just needs to update.
                canSave = false
                pendingAlert = GameAlert(
                    title: "Update needed",
                    message: "Your farm was saved by a newer version of Acres. Please update the app. Your save is safe and has not been changed.")
            case .corrupt:
                try? saveSystem?.store.quarantine()
                pendingAlert = GameAlert(
                    title: "New farm started",
                    message: "Your save file was damaged and couldn't be loaded, so a fresh farm was started. The damaged file was kept aside.")
            case .missingMigration, .io:
                canSave = false
                pendingAlert = GameAlert(
                    title: "Couldn't load your farm",
                    message: "Something went wrong reading your save (\(error)). Saving is paused so nothing is overwritten.")
            }
        }

        savingEnabled = canSave
        alert = pendingAlert
        selectedSeed = presentation.selectedSeed
        refreshDisplay()
        refreshInventory()
        _ = resolvedSeed()  // so the seed button shows a packet from the start
        if let report {
            showWelcomeIfWorthIt(report)
            save()  // don't re-simulate the same absence after a crash
        }
    }

    /// Called by the scene once per frame.
    func update(dt: TimeInterval) {
        guard suspendedAt == nil, dt > 0 else { return }

        if bannerTimeLeft > 0 {
            bannerTimeLeft -= dt
            if bannerTimeLeft <= 0 { banner = nil }
        }
        if inspectionTimeLeft > 0 {
            inspectionTimeLeft -= dt
            if inspectionTimeLeft <= 0 { inspection = nil }
        }
        // The world politely waits while the welcome-back card is open.
        guard welcome == nil else { return }

        let events = simulation.advance(by: dt * timeScale, mode: .live)
        if !events.isEmpty { handle(events) }
        refreshDisplay()

        autosaveTimer += dt
        if autosaveTimer >= simulation.balance.autosaveInterval {
            autosaveTimer = 0
            save()
        }
    }

    func scenePhaseChanged(to phase: ScenePhase) {
        switch phase {
        case .background:
            guard suspendedAt == nil else { return }
            suspendedAt = Date()
            endPaint()
            save()
            scheduleHarvestReminder()
        case .active:
            reminders.cancelAll()
            guard let since = suspendedAt else { return }
            suspendedAt = nil
            catchUp(lastSeen: since, now: Date())
        default:
            break
        }
    }

    func dismissWelcome() {
        welcome = nil
    }

    // MARK: Farming input

    /// A tap on a tile: does the one sensible thing (plow, plant, water,
    /// harvest), or shows what's going on there.
    func tap(_ tile: TileCoord) -> TapResult {
        guard welcome == nil else { return .nothing }
        let state = simulation.state
        let farming = self.farming

        // Empty soil but nothing to plant: open the seed picker instead.
        if let plot = state.plots[tile], plot.crop == nil,
           farming.accessProblem(at: tile, in: state) == nil, resolvedSeed() == nil {
            showMessage("No seeds you can plant in \(season.name). Pick another packet.")
            showsSeedPicker = true
            return .inspected
        }

        guard let action = farming.suggestedAction(at: tile, in: state, seed: resolvedSeed()) else {
            if state.plots[tile] != nil || PropertyCatalog.property(containing: tile) != nil {
                inspect(tile)
                return .inspected
            }
            return .nothing
        }
        return .performed(perform(action, at: tile, painting: false))
    }

    /// Starts drag-painting at a tile. Returns nil if there is nothing to paint
    /// there (the drag then moves the camera), otherwise the first outcome.
    func beginPaint(at tile: TileCoord) -> FarmOutcome? {
        guard welcome == nil,
              let action = farming.suggestedAction(at: tile, in: simulation.state, seed: resolvedSeed()) else { return nil }
        paintKind = action.kind
        if case .plant(let cropID) = action { paintSeed = cropID } else { paintSeed = nil }
        return perform(action, at: tile, painting: true)
    }

    /// Continues a paint stroke: applies the same kind of action where it fits.
    func paint(_ tile: TileCoord) -> FarmOutcome? {
        guard let kind = paintKind,
              let action = farming.suggestedAction(at: tile, in: simulation.state, seed: paintSeed),
              action.kind == kind else { return nil }
        return perform(action, at: tile, painting: true)
    }

    func endPaint() {
        paintKind = nil
        paintSeed = nil
    }

    var isPainting: Bool { paintKind != nil }

    func select(seed cropID: String) {
        selectedSeed = cropID
        presentation.selectedSeed = cropID
        showsSeedPicker = false
        Haptics.selection()
    }

    /// Seeds in the pouch, in catalog order (out-of-season ones included, dimmed).
    var seedOptions: [SeedOption] {
        CropCatalog.all.compactMap { crop in
            let count = inventoryItems[crop.seedItemID] ?? 0
            guard count > 0 else { return nil }
            return SeedOption(crop: crop, count: count, inSeason: crop.canBePlanted(in: season))
        }
    }

    /// Long-press (or tap with nothing to do): show what's on the tile.
    func inspect(_ tile: TileCoord) {
        inspection = makeInspection(tile)
        inspectionTimeLeft = 4
        Haptics.selection()
    }

    func dismissInspection() {
        inspection = nil
    }

    private func perform(_ action: FarmAction, at tile: TileCoord, painting: Bool) -> FarmOutcome {
        let result = simulation.perform(action, at: tile, on: map)
        switch result.outcome {
        case .failed(let failure):
            // While painting, most refusals are just tiles the stroke passes over.
            if !painting || failure == .storageFull {
                if let text = message(for: failure) { showMessage(text) }
            }
        case .planted:
            reminders.requestPermissionIfNeeded(enabled: remindersEnabled)
            fallthrough
        default:
            farmRevision += 1
            if painting { Haptics.selection() } else { Haptics.tap() }
        }
        if !result.events.isEmpty { handle(result.events) }
        refreshInventory()
        refreshDisplay()
        return result.outcome
    }

    /// The seed to plant: the selected one if possible, else the first plantable.
    private func resolvedSeed() -> String? {
        let plantable = farming.plantableSeeds(in: simulation.state)
        if let selected = selectedSeed, plantable.contains(where: { $0.id == selected }) { return selected }
        guard let first = plantable.first else { return nil }
        selectedSeed = first.id
        presentation.selectedSeed = first.id
        return first.id
    }

    private func message(for failure: FarmFailure) -> String? {
        switch failure {
        case .notYourLand: return "This land isn't yours (yet)."
        case .truckNotHere: return "Park your truck here to work this land."
        case .cannotPlowHere: return "Can't plow here."
        case .noSeeds(let crop): return "No \(CropCatalog.crop(crop)?.name.lowercased() ?? crop) seeds left."
        case .outOfSeason(let crop, let season):
            let name = CropCatalog.crop(crop)?.name ?? crop
            return "\(name) can't be planted in \(season.name)."
        case .storageFull: return "Storage is full (\(storageUsed)/\(storageCapacity)). Sell or make room first."
        case .alreadyPlowed, .notPlowed, .alreadyPlanted, .unknownCrop, .nothingToWater, .alreadyWet, .notReady:
            return nil
        }
    }

    private func makeInspection(_ tile: TileCoord) -> TileInspection {
        let state = simulation.state
        let farming = self.farming
        if let plot = state.plots[tile] {
            if let crop = plot.crop, let def = crop.definition {
                let detail: String
                if crop.isReady {
                    detail = "Ready to harvest! Tap to pick."
                } else {
                    let eta = FarmForecast.secondsUntilReady(plot, now: state.worldTime, balance: balance) ?? 0
                    let water = plot.isWet(at: state.worldTime) ? "Watered" : "Thirsty: water it to grow twice as fast"
                    detail = "Ready in \(Format.duration(eta)) · \(water)"
                }
                return TileInspection(tile: tile, title: def.name, detail: detail, icon: "item_\(def.id)", symbol: "leaf.fill")
            }
            let seedName = resolvedSeed().flatMap { CropCatalog.crop($0)?.name.lowercased() }
            return TileInspection(tile: tile, title: "Plowed soil",
                                  detail: seedName.map { "Tap to plant \($0)." } ?? "No seeds to plant this season.",
                                  icon: nil, symbol: "square.grid.3x3.fill")
        }
        switch farming.plowProblem(at: tile, in: state) {
        case nil:
            return TileInspection(tile: tile, title: "Your land", detail: "Tap to plow. Drag to plow a whole row.", icon: nil, symbol: "square.dashed")
        case .notYourLand?:
            return TileInspection(tile: tile, title: "Not your land", detail: "Land can be bought later on.", icon: nil, symbol: "signpost.right.fill")
        case .truckNotHere?:
            return TileInspection(tile: tile, title: "Your land", detail: "Park your truck here to work it.", icon: nil, symbol: "truck.pickup.side.fill")
        default:
            return TileInspection(tile: tile, title: "Your land", detail: "Something's in the way.", icon: nil, symbol: "xmark.circle")
        }
    }

    // MARK: Settings

    func setReminders(_ enabled: Bool) {
        remindersEnabled = enabled
        Settings.set(enabled, for: Settings.remindersKey)
        if enabled { reminders.requestPermissionIfNeeded(enabled: true, force: true) } else { reminders.cancelAll() }
    }

    func setHaptics(_ enabled: Bool) {
        hapticsEnabled = enabled
        Haptics.isEnabled = enabled
        Settings.set(enabled, for: Settings.hapticsKey)
    }

    private func scheduleHarvestReminder() {
        guard remindersEnabled,
              let eta = FarmForecast.secondsUntilAllReady(simulation.state, balance: balance),
              eta > 60, eta < 24 * 3600 else { return }
        let crops = Set(simulation.state.plots.byTile.values.compactMap { $0.crop?.cropID })
        let body: String
        if crops.count == 1, let only = crops.first, let def = CropCatalog.crop(only) {
            body = "Your \(def.plural) are ready to harvest. 🌾"
        } else {
            body = "Your crops are ready to harvest. 🌾"
        }
        reminders.schedule(after: eta, title: "The fields are ready", body: body)
    }

    // MARK: Saving

    func save() {
        guard savingEnabled, let saveSystem else { return }
        let file = saveSystem.makeFile(state: simulation.state, presentation: presentation, previous: lastSave, now: Date())
        do {
            try saveSystem.write(file)
            lastSave = file
        } catch {
            print("⚠️ Save failed: \(error)")
        }
    }

    var saveLocationDescription: String {
        if let store = saveSystem?.store as? FileSaveStore { return store.mainURL.path }
        return "unavailable"
    }

    // MARK: Time

    private func catchUp(lastSeen: Date, now: Date) {
        endPaint()
        let report = OfflineCatchUp.run(&simulation, lastSeen: lastSeen, now: now)
        handle(report.events, quiet: true)
        refreshDisplay()
        refreshInventory()
        showWelcomeIfWorthIt(report)
        farmRevision += 1
        onWorldReset?()
        save()
    }

    private func showWelcomeIfWorthIt(_ report: OfflineReport) {
        guard report.isWorthShowing(balance: balance) else { return }
        welcome = AwaySummary.make(report: report, state: simulation.state, balance: balance)
    }

    private func handle(_ events: [SimEvent], quiet: Bool = false) {
        var hasLevelUp = false
        for event in events {
            switch event {
            case .newSeason(let newSeason, _):
                showBanner("\(newSeason.name) has arrived")
            case .newDay(let date):
                // A season change gets the (more exciting) season banner instead.
                if !events.contains(where: Self.isSeasonChange) {
                    showBanner("Good morning! \(date.season.name) \(date.dayOfSeason)")
                }
            case .levelUp(let newLevel):
                showBanner("Level \(newLevel)! 🎉")
                hasLevelUp = true
            case .cropReady:
                break  // ripe crops twinkle in the field; no need to interrupt
            }
        }
        guard !quiet else { return }
        if hasLevelUp {
            Haptics.success()
        } else if events.contains(where: { if case .newDay = $0 { true } else { false } }) {
            Haptics.thump()
        }
    }

    private static func isSeasonChange(_ event: SimEvent) -> Bool {
        if case .newSeason = event { return true }
        return false
    }

    private func showBanner(_ text: String) {
        banner = text
        bannerTimeLeft = 4
    }

    /// Short feedback message (reuses the banner, but doesn't repeat itself).
    private func showMessage(_ text: String) {
        if banner == text {
            bannerTimeLeft = max(bannerTimeLeft, 2.5)
            return
        }
        banner = text
        bannerTimeLeft = 2.5
    }

    // MARK: Display

    private func refreshDisplay() {
        let state = simulation.state
        let date = state.clock.date(daysPerSeason: simulation.balance.daysPerSeason)
        if money != state.money { money = state.money }
        if level != state.progress.level { level = state.progress.level }
        let fraction = Progression.levelFraction(state.progress, balance: balance)
        if levelProgress != fraction { levelProgress = fraction }
        if season != date.season { season = date.season }
        if dayOfSeason != date.dayOfSeason { dayOfSeason = date.dayOfSeason }
        if year != date.year { year = date.year }
        if dayPhase != state.clock.phase { dayPhase = state.clock.phase }

        // The HUD clock ticks in 10-minute steps, like a farmer's watch.
        let bucket = Int(state.clock.totalMinutes / 10)
        if bucket != lastTimeBucket {
            lastTimeBucket = bucket
            let minute = state.clock.minute / 10 * 10
            var components = DateComponents()
            components.year = 2001
            components.month = 1
            components.day = 1
            components.hour = state.clock.hour
            components.minute = minute
            if let dateValue = Calendar.current.date(from: components) {
                timeText = timeFormatter.string(from: dateValue)
            } else {
                timeText = String(format: "%02d:%02d", state.clock.hour, minute)
            }
        }
    }

    private func refreshInventory() {
        let items = simulation.state.inventory.items
        if inventoryItems != items { inventoryItems = items }
        let used = simulation.state.inventory.storageUsed
        if storageUsed != used { storageUsed = used }
    }

    private static func deviceID() -> String {
        let key = "acres.deviceID"
        if let existing = UserDefaults.standard.string(forKey: key) { return existing }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: key)
        return id
    }

    // MARK: Debug tools

    func debugSimulateAbsence(_ seconds: TimeInterval) {
        catchUp(lastSeen: Date().addingTimeInterval(-seconds), now: Date())
    }

    func debugSkipToNextMorning() {
        handle(simulation.startNextMorning())
        refreshDisplay()
    }

    func debugAddMoney(_ amount: Int) {
        simulation.modify { $0.money += amount }
        refreshDisplay()
    }

    func debugAddSeeds(_ amount: Int) {
        simulation.modify { state in
            for crop in CropCatalog.all { state.inventory.add(crop.seedItemID, amount) }
        }
        refreshInventory()
    }

    func debugWaterEverything() {
        // Read balance first: `simulation` is exclusively borrowed inside `modify`.
        let duration = balance.soilWetDuration
        simulation.modify { state in
            let until = state.worldTime + duration
            state.plots.updateEach { $0.wetUntil = until }
        }
        farmRevision += 1
    }

    func debugRipenEverything() {
        simulation.modify { state in
            state.plots.updateEach { plot in
                guard var crop = plot.crop, let def = crop.definition else { return }
                crop.growth = def.growthSeconds
                plot.crop = crop
            }
        }
        farmRevision += 1
    }

    func debugEmptyStorage() {
        simulation.modify { state in
            for (id, count) in state.inventory.items where ItemCatalog.item(id)?.category.usesStorage ?? true {
                state.inventory.remove(id, count)
            }
        }
        refreshInventory()
    }

    func debugResetFarm() {
        if savingEnabled { try? saveSystem?.store.deleteAll() }
        simulation = Simulation(state: .newGame(seed: UInt64.random(in: 1...UInt64.max)))
        presentation = PresentationState()
        selectedSeed = nil
        lastSave = nil
        welcome = nil
        timeScale = 1
        lastTimeBucket = -1
        endPaint()
        refreshDisplay()
        refreshInventory()
        farmRevision += 1
        onWorldReset?()
        save()
    }
}

/// Short human durations: "45s", "3m 20s", "1h 05m".
enum Format {
    static func duration(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite else { return "a long while" }
        let total = max(0, Int(seconds.rounded(.up)))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        if h > 0 { return "\(h)h \(String(format: "%02d", m))m" }
        if m > 0 { return "\(m)m \(String(format: "%02d", s))s" }
        return "\(s)s"
    }
}

/// Device-level preferences (not part of the save: they follow the phone).
enum Settings {
    static let remindersKey = "acres.harvestReminders"
    static let hapticsKey = "acres.haptics"

    static func bool(_ key: String, default value: Bool) -> Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? value
    }

    static func set(_ value: Bool, for key: String) {
        UserDefaults.standard.set(value, forKey: key)
    }
}
