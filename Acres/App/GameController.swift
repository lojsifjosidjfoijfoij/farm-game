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

/// Owns the running game: the simulation, saving/loading, offline catch-up and
/// the values the HUD displays. The SpriteKit scene calls `update(dt:)` every
/// frame; SwiftUI observes the display properties.
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
    var welcomeReport: OfflineReport?
    var alert: GameAlert?

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
    private let saveSystem: SaveSystem?
    @ObservationIgnored private(set) var lastSave: SaveFile?
    @ObservationIgnored private var savingEnabled = true
    @ObservationIgnored private var autosaveTimer: TimeInterval = 0
    @ObservationIgnored private var suspendedAt: Date?
    @ObservationIgnored private var bannerTimeLeft: TimeInterval = 0
    @ObservationIgnored private var lastTimeBucket = -1
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("jmm")  // 12 h or 24 h per the user's locale
        return formatter
    }()

    var balance: Balance { simulation.balance }

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
        refreshDisplay()
        if let report {
            if report.isWorthShowing(balance: simulation.balance) { welcomeReport = report }
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
        // The world politely waits while the welcome-back card is open.
        guard welcomeReport == nil else { return }

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
            save()
        case .active:
            guard let since = suspendedAt else { return }
            suspendedAt = nil
            catchUp(lastSeen: since, now: Date())
        default:
            break
        }
    }

    func dismissWelcome() {
        welcomeReport = nil
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
        let report = OfflineCatchUp.run(&simulation, lastSeen: lastSeen, now: now)
        handle(report.events, quiet: true)
        refreshDisplay()
        if report.isWorthShowing(balance: simulation.balance) {
            welcomeReport = report
        }
        onWorldReset?()
        save()
    }

    private func handle(_ events: [SimEvent], quiet: Bool = false) {
        for event in events {
            switch event {
            case .newSeason(let newSeason, _):
                showBanner("\(newSeason.name) has arrived")
            case .newDay(let date):
                // A season change gets the (more exciting) season banner instead.
                if !events.contains(where: Self.isSeasonChange) {
                    showBanner("Good morning! \(date.season.name) \(date.dayOfSeason)")
                }
            }
        }
        if !quiet && !events.isEmpty { Haptics.thump() }
    }

    private static func isSeasonChange(_ event: SimEvent) -> Bool {
        if case .newSeason = event { return true }
        return false
    }

    private func showBanner(_ text: String) {
        banner = text
        bannerTimeLeft = 4
    }

    // MARK: Display

    private func refreshDisplay() {
        let state = simulation.state
        let date = state.clock.date(daysPerSeason: simulation.balance.daysPerSeason)
        if money != state.money { money = state.money }
        if level != state.progress.level { level = state.progress.level }
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

    func debugResetFarm() {
        if savingEnabled { try? saveSystem?.store.deleteAll() }
        simulation = Simulation(state: .newGame(seed: UInt64.random(in: 1...UInt64.max)))
        presentation = PresentationState()
        lastSave = nil
        welcomeReport = nil
        timeScale = 1
        lastTimeBucket = -1
        refreshDisplay()
        onWorldReset?()
        save()
    }
}
