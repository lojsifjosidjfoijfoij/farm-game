import SwiftUI
import AcresCore

/// Developer tools for testing time, offline progress and saves.
/// Only reachable in Debug builds (the ladybug button).
struct DebugPanelView: View {
    @Bindable var game: GameController
    @State private var confirmsReset = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Time") {
                    Picker("Speed", selection: $game.timeScale) {
                        Text("1×").tag(1.0)
                        Text("10×").tag(10.0)
                        Text("60×").tag(60.0)
                    }
                    .pickerStyle(.segmented)
                    Button("Skip to next morning") { game.debugSkipToNextMorning() }
                    Button("Jump to 20:00 (evening)") { game.debugJump(toHour: 20) }
                    Button("Skip to Monday (bills day)") { game.debugSkipToMonday() }
                    Button("Refill the farmer's energy") { game.debugRefillEnergy() }
                }

                Section {
                    ForEach(Self.absences, id: \.label) { absence in
                        Button(absence.label) {
                            game.showsDebugPanel = false
                            game.debugSimulateAbsence(absence.seconds)
                        }
                    }
                } header: {
                    Text("Pretend I was away")
                } footer: {
                    Text("Runs the real offline catch-up, as if the app had been closed that long.")
                }

                Section("Farm") {
                    Button("+10 of every seed") { game.debugAddSeeds(10) }
                    Button("Water all crops") { game.debugWaterEverything() }
                    Button("Ripen all crops") { game.debugRipenEverything() }
                    Button("Empty storage") { game.debugEmptyStorage() }
                }

                Section("Animals & trees") {
                    Button("Grow up animals, finish products") { game.debugGrowAnimals() }
                    Button("Grow all trees, ripen fruit") { game.debugGrowTrees() }
                    Button("Level up (+1)") { game.debugLevelUp() }
                }

                Section("Truck & Arne") {
                    Button("Fill the tank") { game.debugFillTank() }
                    Button("Load the truck with goods") { game.debugLoadTruckWithGoods() }
                    Button("Send Arne home") { game.skipTutorial() }
                    Button("Arne shows you around again") { game.restartTutorial() }
                    Button("Arne drops by now") { game.debugGuideDropIn() }
                }

                Section("World") {
                    Toggle("Chunk borders", isOn: $game.showsChunkBorders)
                    Toggle("FPS / nodes / draw calls", isOn: $game.showsPerformanceStats)
                    Button("+1,000 coins") { game.debugAddMoney(1000) }
                }

                Section("Save") {
                    Button("Save now") { game.save() }
                    LabeledContent("Revision", value: "\(game.lastSave?.revision ?? 0)")
                    if let saved = game.lastSave?.savedAt {
                        LabeledContent("Last saved", value: saved.formatted(date: .omitted, time: .standard))
                    }
                    Text(game.saveLocationDescription)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                    Button("Reset farm…", role: .destructive) { confirmsReset = true }
                }

                Section("Simulation") {
                    let state = game.simulation.state
                    LabeledContent("World time", value: WelcomeBackView.format(state.worldTime))
                    LabeledContent("Played", value: WelcomeBackView.format(state.stats.playSeconds))
                    LabeledContent("Simulated offline", value: WelcomeBackView.format(state.stats.offlineSeconds))
                    LabeledContent("Returns", value: "\(state.stats.returns)")
                    LabeledContent("Clock", value: String(format: "day %d, %02d:%02d", state.clock.dayIndex, state.clock.hour, state.clock.minute))
                }
            }
            .navigationTitle("Debug")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { game.showsDebugPanel = false }
                }
            }
            .confirmationDialog("Start over with a brand-new farm?", isPresented: $confirmsReset, titleVisibility: .visible) {
                Button("Reset farm", role: .destructive) {
                    game.startNewFarm()
                    game.showsDebugPanel = false
                }
            }
        }
    }

    private struct Absence {
        let label: String
        let seconds: TimeInterval
    }

    private static let absences = [
        Absence(label: "10 minutes", seconds: 10 * 60),
        Absence(label: "2 hours", seconds: 2 * 3600),
        Absence(label: "12 hours", seconds: 12 * 3600),
        Absence(label: "5 days (over the 3-day cap)", seconds: 5 * 24 * 3600),
    ]
}
