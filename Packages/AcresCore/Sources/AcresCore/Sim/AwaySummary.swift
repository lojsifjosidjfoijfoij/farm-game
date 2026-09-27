import Foundation

/// The content of the "While you were away" screen, as data (the UI picks
/// icons and wording). Built from the offline report plus the farm right now.
public struct AwaySummary: Equatable, Sendable {
    public enum Line: Equatable, Sendable {
        /// The device clock went backwards; nothing was simulated.
        case clockChanged
        case newSeason(Season)
        case cropsReady(cropID: String, count: Int)
        case cropsGrowing(cropID: String, count: Int, secondsLeft: TimeInterval)
        case thirstyCrops(count: Int)
        /// Products waiting in the pens (eggs, milk, …), by item.
        case productsReady(itemID: String, count: Int)
        /// Young animals that grew up while you were away.
        case grewUp(names: [String])
        /// Grown animals waiting for a meal.
        case hungryAnimals(count: Int)
        /// Fruit trees with fruit to pick.
        case fruitReady(count: Int)
        /// Planted or regrowing trees that reached full size.
        case treesGrown(count: Int)
        case storageFull(used: Int, capacity: Int)
        /// The absence was longer than the catch-up cap.
        case capped(TimeInterval)
        case nothingNew
    }

    public var awayDuration: TimeInterval
    public var lines: [Line]

    public static func make(report: OfflineReport, state: GameState, balance: Balance) -> AwaySummary {
        var lines: [Line] = []
        if report.clockWentBackwards { lines.append(.clockChanged) }
        for event in report.events {
            if case .newSeason(let season, _) = event { lines.append(.newSeason(season)) }
        }

        let status = FarmForecast.status(state, balance: balance)
        for crop in status where crop.ready > 0 {
            lines.append(.cropsReady(cropID: crop.cropID, count: crop.ready))
        }
        for crop in status where crop.growing > 0 {
            lines.append(.cropsGrowing(cropID: crop.cropID, count: crop.growing, secondsLeft: crop.secondsUntilAllReady))
        }
        let thirsty = status.reduce(0) { $0 + $1.thirsty }
        if thirsty > 0 { lines.append(.thirstyCrops(count: thirsty)) }

        // Animals.
        let animals = state.ranch.allAnimals
        var products: [String: Int] = [:]
        for animal in animals where animal.hasProduct {
            if let item = animal.species?.productItemID { products[item, default: 0] += 1 }
        }
        for item in products.keys.sorted() { lines.append(.productsReady(itemID: item, count: products[item]!)) }
        var grownIDs = Set<Int>()
        var treesGrown = 0
        for event in report.events {
            switch event {
            case .animalGrewUp(_, let id): grownIDs.insert(id)
            case .treeGrown: treesGrown += 1
            default: break
            }
        }
        let grownNames = animals.filter { grownIDs.contains($0.id) }.map(\.name)
        if !grownNames.isEmpty { lines.append(.grewUp(names: grownNames)) }
        let hungry = animals.filter(\.isHungry).count
        if hungry > 0 { lines.append(.hungryAnimals(count: hungry)) }

        // Trees.
        let fruit = state.woodland.trees.values.filter(\.hasFruit).count
        if fruit > 0 { lines.append(.fruitReady(count: fruit)) }
        if treesGrown > 0 { lines.append(.treesGrown(count: treesGrown)) }
        let used = state.inventory.storageUsed
        if used >= balance.storageCapacity { lines.append(.storageFull(used: used, capacity: balance.storageCapacity)) }
        if report.wasCapped { lines.append(.capped(balance.offlineCatchUpCap)) }
        if lines.isEmpty { lines.append(.nothingNew) }
        return AwaySummary(awayDuration: report.awayDuration, lines: lines)
    }
}
