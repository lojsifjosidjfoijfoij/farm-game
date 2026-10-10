// Developer tools for Acres.
//
//   swift run acres-tools assets > ../../docs/ASSETS.md
//   swift run acres-tools economy     (a balancing sheet: crops, the market, things to buy)
//   swift run -c release acres-tools autoplay <folder> [seed]
//                                     (a computer player plays a new farm to the finale and saves
//                                      it along the way: early, mid, end_day, end_village, end_night)
//
// Keep generated docs in sync with the manifest (a unit test checks this).

import AcresCore
import Foundation

let arguments = CommandLine.arguments.dropFirst()

switch arguments.first {
case "assets":
    print(AssetDocs.markdown(), terminator: "")
case "map-dump":
    // Debug: terrain rows (north first) followed by object lines, for previews.
    let map = HomeValleyMap.map
    let symbols: [Terrain: Character] = [.grass: ".", .dirt: "d", .gravel: "g", .asphalt: "a"]
    for y in stride(from: map.height - 1, through: 0, by: -1) {
        print(String((0..<map.width).map { symbols[map.terrain(at: TileCoord($0, y))]! }))
    }
    for object in map.objects {
        print("OBJ \(object.kind) \(object.position.x) \(object.position.y)")
    }
case "economy":
    // Balancing sheet: what a tile earns, how the market takes a load, what there is to spend on.
    let balance = Balance.standard
    print("Crops: coins per tile per watered day (after seeds; regrowing crops once grown)")
    print("crop          level  per day")
    for crop in CropCatalog.all.sorted(by: { ($0.unlockLevel, $0.id) < ($1.unlockLevel, $1.id) }) {
        let price = Double(crop.sellPrice.lowerBound + crop.sellPrice.upperBound) / 2
        let yield = Double(crop.yield.lowerBound + crop.yield.upperBound) / 2
        let perDay = crop.regrowSeconds.map { price * yield / ($0 / GameTime.day) }
            ?? (price * yield - Double(crop.seedCost)) / (crop.growthSeconds / GameTime.day)
        let name = crop.id.padding(toLength: 13, withPad: " ", startingAt: 0)
        print("\(name) \(String(crop.unlockLevel).padding(toLength: 6, withPad: " ", startingAt: 0)) \(Int(perDay.rounded()))")
    }
    print("\nThe market: share of the usual price for one load of a single crop, on a fresh market")
    let fresh = GameState.newGame(seed: 1)
    let market = Market(balance: balance)
    for coins in [300, 600, 1_500, 4_000, 10_000, 25_000] {
        let units = coins / 12
        let earned = market.quote("wheat", count: units, unitPrice: 12, in: fresh)
        print("  \(coins) coins' worth: \(Int((Double(earned) / Double(units * 12) * 100).rounded()))%")
    }
    print("\nThings to buy (coins)")
    let land = PropertyCatalog.forSale.compactMap(\.price).reduce(0, +)
    let fields = FieldCatalog.all.map(\.price).reduce(0, +)
    let buildings = balance.storageUpgradeCosts.reduce(0, +) + balance.truckBedUpgradeCosts.reduce(0, +)
    let workshops = WorkshopCatalog.all.map(\.price).reduce(0, +)
    let pens = PenCatalog.all.map(\.repairCost).reduce(0, +)
    let village = Village.all.map(\.coins).reduce(0, +)
    for (name, total) in [("land", land), ("fields", fields), ("storage and truck", buildings), ("workshops (one each)", workshops),
                          ("pens", pens), ("village projects", village)] {
        print("  \(name.padding(toLength: 22, withPad: " ", startingAt: 0)) \(total)")
    }
case "autoplay":
    let folder = URL(fileURLWithPath: arguments.dropFirst().first ?? "autoplay", isDirectory: true)
    let seed = arguments.dropFirst(2).first.flatMap { UInt64($0) } ?? 2026
    var player = AutoPlayer(seed: seed)
    let started = Date()

    /// Saves the farm as the app would, into `<folder>/<name>/farm.json`.
    func save(_ player: AutoPlayer, as name: String, camera: Vec2) {
        let directory = folder.appendingPathComponent(name, isDirectory: true)
        try? FileManager.default.removeItem(at: directory)
        let system = SaveSystem(store: FileSaveStore(directory: directory), deviceID: "autoplay")
        let file = system.makeFile(state: player.sim.state, presentation: PresentationState(cameraCenter: camera, cameraZoom: nil),
                                   previous: nil, now: Date())
        do {
            try system.write(file)
        } catch {
            FileHandle.standardError.write("Couldn't save \(name): \(error)\n".data(using: .utf8)!)
            exit(1)
        }
        // Read it back the way the app will.
        guard case .loaded(let loaded, false) = system.load(), loaded.state == player.sim.state else {
            FileHandle.standardError.write("The \(name) save doesn't load back.\n".data(using: .utf8)!)
            exit(1)
        }
        let state = player.sim.state
        print("Saved \(name): day \(player.day + 1), \(String(format: "%02d:%02d", state.clock.hour, state.clock.minute)), "
            + "level \(state.progress.level), rank \(state.rank.rank), net worth \(player.netWorth), \(state.money) coins")
    }
    let farm = Vec2(34, 36)

    // A few days in: the first fields up and growing.
    player.play(maxDays: 3) { _ in false }
    player.homeMorning()
    player.wait(until: 11)
    player.stroll(to: Vec2(31, 30.4))
    save(player, as: "early", camera: farm)
    player.afternoon(); player.evening(); player.sleep()

    // A thriving farm.
    player.play(maxDays: 600) { $0.sim.state.rank.rank >= 3 }
    player.homeMorning()
    player.wait(until: 13)
    player.stroll(to: Vec2(33, 30.4))
    save(player, as: "mid", camera: farm)
    player.afternoon(); player.evening(); player.sleep()

    // The Valley's Finest Farm.
    player.play(maxDays: 1_500) { $0.sim.state.rank.rank >= FarmRanks.finale.id }
    guard player.sim.state.rank.rank >= FarmRanks.finale.id else {
        print("Didn't reach the finale in \(player.day) days (net worth \(player.netWorth)).")
        player.diary.suffix(40).forEach { print($0) }
        exit(1)
    }
    let finaleDay = player.day
    print("The Valley's Finest Farm on day \(finaleDay) (net worth \(player.netWorth)).")
    // Farming goes on: until the village has everything the farm can help build.
    player.play(maxDays: finaleDay + 120) { $0.sim.state.village.finished.count >= Village.all.count }
    print("Village: \(player.sim.state.village.finished.count) of \(Village.all.count) projects done by day \(player.day + 1).")
    player.homeMorning()
    player.wait(until: 13)
    player.stroll(to: Vec2(33, 30.4))
    save(player, as: "end_day", camera: farm)
    player.visit(HomeValleyMap.seedShopZone)
    save(player, as: "end_village", camera: Vec2(92, 26))
    player.afternoon()
    player.evening(until: 21)
    player.stroll(to: Vec2(23, 34.6))
    save(player, as: "end_night", camera: Vec2(27, 36))

    print("\nThe farm now:")
    player.report.forEach { print($0) }
    print("\nThe farm's story:")
    player.diary.forEach { print($0) }
    print(String(format: "\n(played in %.1f s)", Date().timeIntervalSince(started)))
default:
    let message = "usage: acres-tools assets | map-dump | economy | autoplay <folder> [seed]\n"
    FileHandle.standardError.write(message.data(using: .utf8)!)
    exit(1)
}
