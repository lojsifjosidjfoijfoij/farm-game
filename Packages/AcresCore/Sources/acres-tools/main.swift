// Developer tools for Acres.
//
//   swift run acres-tools assets > ../../docs/ASSETS.md
//   swift run acres-tools economy     (a balancing sheet: crops, the market, things to buy)
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
default:
    let message = "usage: acres-tools assets | map-dump | economy\n"
    FileHandle.standardError.write(message.data(using: .utf8)!)
    exit(1)
}
