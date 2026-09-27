import Foundation

/// What a shop does.
public enum ShopKind: String, Sendable, CaseIterable {
    /// Sells seeds.
    case seedShop
    /// Buys crops from the truck.
    case market
    /// Sells fuel.
    case gasStation
    /// Sells young animals and feed. (Phase 4)
    case livestock
}

/// A place the truck can stop at to trade.
public struct ShopDefinition: Sendable, Hashable, Identifiable {
    public let id: String
    public let name: String
    public let kind: ShopKind
    /// Where the truck must stop (tile units).
    public let zone: TileRect
}

public enum ShopCatalog {
    public static let all: [ShopDefinition] = [
        ShopDefinition(id: "village_gas", name: "Village Gas", kind: .gasStation, zone: HomeValleyMap.gasStationZone),
        ShopDefinition(id: "village_seeds", name: "Seed Shop", kind: .seedShop, zone: HomeValleyMap.seedShopZone),
        ShopDefinition(id: "village_market", name: "Village Market", kind: .market, zone: HomeValleyMap.marketZone),
        ShopDefinition(id: "valley_livestock", name: "Valley Livestock", kind: .livestock, zone: HomeValleyMap.livestockZone),
    ]

    public static func shop(at position: Vec2) -> ShopDefinition? {
        all.first { $0.zone.contains(position) }
    }

    public static func first(_ kind: ShopKind) -> ShopDefinition? {
        all.first { $0.kind == kind }
    }
}

/// Market prices. Each item's price drifts gently from day to day inside its
/// range, so it can pay to sell at the right moment. (Phase 5 adds several
/// markets, supply and demand.)
public enum MarketPricing {
    public static func price(of item: ItemDefinition, day: Int) -> Int {
        price(id: item.id, range: item.value, day: day)
    }

    public static func price(of crop: CropDefinition, day: Int) -> Int {
        price(id: crop.id, range: crop.sellPrice, day: day)
    }

    private static func price(id: String, range: ClosedRange<Int>, day: Int) -> Int {
        let seed = SeededRandom.stableHash(id) ^ (UInt64(bitPattern: Int64(day)) &* 0x9E37_79B9_7F4A_7C15)
        var rng = SeededRandom(seed: seed)
        let t = rng.nextUnit()
        return range.lowerBound + Int((Double(range.upperBound - range.lowerBound) * t).rounded())
    }
}

public enum TradeFailure: Error, Equatable, Sendable {
    case notAtShop(ShopKind)
    case notAtFarm
    case notEnoughMoney
    case locked(level: Int)
    case unknownItem
    case nothingToSell
    case cargoFull
    case storageFull
    case tankFull
    case penNotRepaired(penID: String)
    case penFull(penID: String)
}

/// Buying, selling, fuel and loading the truck. Pure rules over `GameState`.
public struct Trading: Sendable {
    public let balance: Balance

    public init(balance: Balance) {
        self.balance = balance
    }

    public func today(_ state: GameState) -> Int { state.clock.dayIndex }

    /// Today's price for anything the market buys.
    public func price(of itemID: String, in state: GameState) -> Int? {
        guard let item = ItemCatalog.item(itemID), item.category.isSellable else { return nil }
        return MarketPricing.price(of: item, day: today(state))
    }

    private func requireShop(_ kind: ShopKind, _ state: GameState) throws(TradeFailure) {
        guard ShopCatalog.shop(at: state.truck.position)?.kind == kind else { throw .notAtShop(kind) }
    }

    /// Whether the truck is parked on the home farm (where loading happens).
    public func truckIsAtFarm(_ state: GameState) -> Bool {
        PropertyCatalog.homeFarm.area.insetBy(-3).contains(state.truck.position)
    }

    // MARK: Seed shop

    /// Buys seeds; returns the coins spent.
    public func buySeeds(_ cropID: String, count: Int, state: inout GameState) throws(TradeFailure) -> Int {
        try requireShop(.seedShop, state)
        guard let crop = CropCatalog.crop(cropID), count > 0 else { throw .unknownItem }
        guard state.progress.level >= crop.unlockLevel else { throw .locked(level: crop.unlockLevel) }
        let cost = crop.seedCost * count
        guard state.money >= cost else { throw .notEnoughMoney }
        state.money -= cost
        state.inventory.add(crop.seedItemID, count)
        return cost
    }

    /// Buys saplings (seed shop); returns the coins spent.
    public func buySaplings(_ treeID: String, count: Int, state: inout GameState) throws(TradeFailure) -> Int {
        try requireShop(.seedShop, state)
        guard let tree = TreeCatalog.species(treeID), count > 0 else { throw .unknownItem }
        guard state.progress.level >= tree.unlockLevel else { throw .locked(level: tree.unlockLevel) }
        let cost = tree.saplingCost * count
        guard state.money >= cost else { throw .notEnoughMoney }
        state.money -= cost
        state.inventory.add(tree.saplingItemID, count)
        return cost
    }

    // MARK: Livestock market

    /// Buys a young animal, delivered straight to its pen; returns it.
    public func buyAnimal(_ speciesID: String, state: inout GameState) throws(TradeFailure) -> AnimalState {
        try requireShop(.livestock, state)
        guard let species = AnimalCatalog.species(speciesID), let pen = PenCatalog.pen(species.penID) else { throw .unknownItem }
        guard state.progress.level >= species.unlockLevel else { throw .locked(level: species.unlockLevel) }
        let penState = state.ranch[pen.id]
        guard penState.isRepaired else { throw .penNotRepaired(penID: pen.id) }
        guard penState.animals.count < pen.capacity else { throw .penFull(penID: pen.id) }
        guard state.money >= species.price else { throw .notEnoughMoney }
        state.money -= species.price
        return Ranching.addYoungAnimal(species, to: pen.id, in: &state, balance: balance)
    }

    /// Buys sacks of animal feed (into farm storage); returns the coins spent.
    public func buyFeed(count: Int, state: inout GameState) throws(TradeFailure) -> Int {
        try requireShop(.livestock, state)
        guard count > 0 else { throw .unknownItem }
        let cost = balance.feedPrice * count
        guard state.money >= cost else { throw .notEnoughMoney }
        guard state.inventory.storageUsed + count <= balance.storageCapacity else { throw .storageFull }
        state.money -= cost
        state.inventory.add("animal_feed", count)
        return cost
    }

    // MARK: Market

    /// Sells items from the truck bed; returns the coins earned.
    public func sell(_ itemID: String, count: Int, state: inout GameState) throws(TradeFailure) -> Int {
        try requireShop(.market, state)
        guard let unitPrice = price(of: itemID, in: state) else { throw .unknownItem }
        let amount = min(count, state.truck.cargo.count(itemID))
        guard amount > 0 else { throw .nothingToSell }
        state.truck.cargo.remove(itemID, amount)
        let earned = unitPrice * amount
        state.money += earned
        return earned
    }

    /// Sells everything the market buys from the bed; returns the coins earned.
    public func sellAll(state: inout GameState) throws(TradeFailure) -> Int {
        try requireShop(.market, state)
        let items = state.truck.cargo.items.keys.sorted().filter { price(of: $0, in: state) != nil }
        guard !items.isEmpty else { throw .nothingToSell }
        var total = 0
        for item in items {
            total += try sell(item, count: state.truck.cargo.count(item), state: &state)
        }
        return total
    }

    // MARK: Gas station

    /// Fills the tank as far as the wallet allows; returns (fuel added, coins spent).
    public func refuel(state: inout GameState) throws(TradeFailure) -> (fuel: Double, cost: Int) {
        try requireShop(.gasStation, state)
        let missing = balance.driving.fuelCapacity - state.truck.fuel
        guard missing >= 1 else { throw .tankFull }
        let affordable = balance.fuelPrice > 0 ? Double(state.money) / balance.fuelPrice : missing
        let fuel = min(missing, affordable.rounded(.down))
        guard fuel >= 1 else { throw .notEnoughMoney }
        let cost = Int((fuel * balance.fuelPrice).rounded(.up))
        state.money -= cost
        state.truck.fuel += fuel
        return (fuel, cost)
    }

    /// Cost to fill the tank completely.
    public func fullTankCost(_ state: GameState) -> Int {
        Int(((balance.driving.fuelCapacity - state.truck.fuel) * balance.fuelPrice).rounded(.up))
    }

    // MARK: Loading

    /// Moves items from farm storage into the truck bed; returns how many moved.
    public func load(_ itemID: String, count: Int, state: inout GameState) throws(TradeFailure) -> Int {
        guard truckIsAtFarm(state) else { throw .notAtFarm }
        let room = balance.truckCargoCapacity - state.truck.cargoCount
        guard room > 0 else { throw .cargoFull }
        let amount = min(count, room, state.inventory.count(itemID))
        guard amount > 0 else { throw .unknownItem }
        state.inventory.remove(itemID, amount)
        state.truck.cargo.add(itemID, amount)
        return amount
    }

    /// Loads as much sellable stuff as fits, most valuable first; returns how many moved.
    public func loadAll(state: inout GameState) throws(TradeFailure) -> Int {
        guard truckIsAtFarm(state) else { throw .notAtFarm }
        let goods = ItemCatalog.all
            .filter { $0.category.isSellable && state.inventory.count($0.id) > 0 }
            .sorted { $0.value.upperBound != $1.value.upperBound ? $0.value.upperBound > $1.value.upperBound : $0.id < $1.id }
        guard !goods.isEmpty else { throw .unknownItem }
        guard state.truck.cargoCount < balance.truckCargoCapacity else { throw .cargoFull }
        var moved = 0
        for item in goods {
            let room = balance.truckCargoCapacity - state.truck.cargoCount
            if room <= 0 { break }
            moved += try load(item.id, count: room, state: &state)
        }
        return moved
    }

    /// Moves items from the truck back into farm storage.
    public func unload(_ itemID: String, count: Int, state: inout GameState) throws(TradeFailure) -> Int {
        guard truckIsAtFarm(state) else { throw .notAtFarm }
        let room = balance.storageCapacity - state.inventory.storageUsed
        guard room > 0 else { throw .storageFull }
        let amount = min(count, room, state.truck.cargo.count(itemID))
        guard amount > 0 else { throw .unknownItem }
        state.truck.cargo.remove(itemID, amount)
        state.inventory.add(itemID, amount)
        return amount
    }
}
