import Foundation

/// The corner shop in the village the farmer can rent (Phase 7).
public struct StoreDefinition: Sendable, Hashable, Identifiable {
    public let id: String
    public let name: String
    /// Where the truck stops to stock the shelves (tile units).
    public let zone: TileRect
    /// Where customers go in (tile units).
    public let door: Vec2
    public let opens: Int
    public let closes: Int

    public func isOpen(atHour hour: Int) -> Bool { hour >= opens && hour < closes }

    public static let corner = StoreDefinition(id: "corner_shop", name: "Corner Shop", zone: HomeValleyMap.storeZone,
                                               door: HomeValleyMap.storeDoor, opens: 9, closes: 18)
}

/// One shelf in the shop: one kind of goods, how many, and at what price.
public struct Shelf: Codable, Equatable, Sendable {
    /// What's on it. Kept when it sells out, so a restock keeps the price.
    public var itemID: String?
    public var stock: Int
    /// The price as a multiple of the item's usual value.
    public var priceFactor: Double
    /// Demand built up toward the next sale (steady and deterministic, no dice).
    public var progress: Double

    public init(itemID: String? = nil, stock: Int = 0, priceFactor: Double = 1, progress: Double = 0) {
        self.itemID = itemID
        self.stock = stock
        self.priceFactor = priceFactor
        self.progress = progress
    }
}

/// The takings of one day.
public struct StoreDay: Codable, Equatable, Sendable {
    public var day: Int
    public var coins: Int
    public var items: Int
    /// Items sold, by item.
    public var sales: [String: Int]

    public init(day: Int, coins: Int = 0, items: Int = 0, sales: [String: Int] = [:]) {
        self.day = day
        self.coins = coins
        self.items = items
        self.sales = sales
    }
}

/// The farmer's shop: rented or not, the shelves and the takings.
public struct StoreState: Codable, Equatable, Sendable {
    public var isRented: Bool
    public var shelves: [Shelf]
    public var today: StoreDay
    /// Everything the shop ever took in.
    public var totalCoins: Int

    public init(isRented: Bool = false, shelves: [Shelf] = [], today: StoreDay = StoreDay(day: 0), totalCoins: Int = 0) {
        self.isRented = isRented
        self.shelves = shelves
        self.today = today
        self.totalCoins = totalCoins
    }

    public var totalStock: Int { shelves.map(\.stock).reduce(0, +) }
}

public enum StoreFailure: Error, Equatable, Sendable {
    case notAtStore
    case truckNotHere
    case notRented
    case alreadyRented
    case locked(level: Int)
    case notEnoughMoney
    case notSellable
    case nothingToStock
    case shelvesFull
    case cargoFull
    case shelvesNotEmpty
    case unknownShelf
}

/// The rules of running the shop. Pure functions over `GameState`.
public struct Storekeeping: Sendable {
    public let balance: Balance
    public let store: StoreDefinition

    public init(balance: Balance, store: StoreDefinition = .corner) {
        self.balance = balance
        self.store = store
    }

    public func isAtStore(_ state: GameState) -> Bool { store.zone.insetBy(-1).contains(state.farmerPosition) }

    public func truckIsHere(_ state: GameState) -> Bool { store.zone.contains(state.truck.position) }

    // MARK: Renting

    /// The first payment: rent for the days until Monday's bills take over.
    public func firstRent(_ state: GameState) -> Int {
        let days = 7 - state.clock.dayIndex % 7
        return Int((Double(balance.storeRentPerWeek) * Double(days) / 7).rounded(.up))
    }

    /// Signs the lease; returns the first payment.
    public func rent(state: inout GameState) throws(StoreFailure) -> Int {
        guard isAtStore(state) else { throw .notAtStore }
        guard !state.store.isRented else { throw .alreadyRented }
        guard state.progress.level >= balance.storeUnlockLevel else { throw .locked(level: balance.storeUnlockLevel) }
        let cost = firstRent(state)
        guard state.money >= cost else { throw .notEnoughMoney }
        state.money -= cost
        state.finance.spend(cost, LedgerCategory.rent)
        state.store.isRented = true
        state.store.shelves = (0..<balance.storeShelves).map { _ in Shelf() }
        state.goals.add(GoalCounter.shopRented)
        return cost
    }

    /// Gives the shop back (the shelves must be empty). Rent already paid isn't refunded.
    public func endLease(state: inout GameState) throws(StoreFailure) {
        guard isAtStore(state) else { throw .notAtStore }
        guard state.store.isRented else { throw .notRented }
        guard state.store.totalStock == 0 else { throw .shelvesNotEmpty }
        state.store.isRented = false
        state.store.shelves = []
    }

    // MARK: Shelves

    /// Puts goods from the truck on the shelves (shelves with that item first,
    /// then empty ones); returns how many went up.
    public func stock(_ itemID: String, count: Int = .max, state: inout GameState) throws(StoreFailure) -> Int {
        try requireShelves(state)
        guard let item = ItemCatalog.item(itemID), item.category.isSellable else { throw .notSellable }
        let available = min(count, state.truck.cargo.count(itemID))
        guard available > 0 else { throw .nothingToStock }
        let moved = place(itemID, amount: available, on: &state.store.shelves)
        guard moved > 0 else { throw .shelvesFull }
        state.truck.cargo.remove(itemID, moved)
        return moved
    }

    /// Stocks everything sellable on the truck, most valuable first.
    public func stockAll(state: inout GameState) throws(StoreFailure) -> Int {
        try requireShelves(state)
        let items = state.truck.cargo.items.keys
            .compactMap { ItemCatalog.item($0) }
            .filter { $0.category.isSellable && state.truck.cargo.count($0.id) > 0 }
            .sorted { ($0.value.lowerBound + $0.value.upperBound, $1.id) > ($1.value.lowerBound + $1.value.upperBound, $0.id) }
        guard !items.isEmpty else { throw .nothingToStock }
        var total = 0
        for item in items {
            let moved = place(item.id, amount: state.truck.cargo.count(item.id), on: &state.store.shelves)
            state.truck.cargo.remove(item.id, moved)
            total += moved
        }
        guard total > 0 else { throw .shelvesFull }
        return total
    }

    /// Takes a shelf's goods back into the truck; returns how many.
    public func takeBack(shelf index: Int, state: inout GameState) throws(StoreFailure) -> Int {
        try requireShelves(state)
        guard state.store.shelves.indices.contains(index) else { throw .unknownShelf }
        let shelf = state.store.shelves[index]
        guard let itemID = shelf.itemID, shelf.stock > 0 else { throw .nothingToStock }
        let room = state.truckCapacity(balance) - state.truck.cargoCount
        let amount = min(shelf.stock, room)
        guard amount > 0 else { throw .cargoFull }
        state.store.shelves[index].stock -= amount
        state.truck.cargo.add(itemID, amount)
        return amount
    }

    /// Sets a shelf's price (a multiple of the usual value, in steps of 5%).
    public func setPrice(shelf index: Int, factor: Double, state: inout GameState) throws(StoreFailure) {
        guard isAtStore(state) else { throw .notAtStore }
        guard state.store.isRented else { throw .notRented }
        guard state.store.shelves.indices.contains(index) else { throw .unknownShelf }
        let range = balance.storePriceFactorRange
        let stepped = (factor * 20).rounded() / 20
        state.store.shelves[index].priceFactor = min(range.upperBound, max(range.lowerBound, stepped))
    }

    private func requireShelves(_ state: GameState) throws(StoreFailure) {
        guard isAtStore(state) else { throw .notAtStore }
        guard state.store.isRented else { throw .notRented }
        guard truckIsHere(state) else { throw .truckNotHere }
    }

    private func place(_ itemID: String, amount: Int, on shelves: inout [Shelf]) -> Int {
        let capacity = balance.storeShelfCapacity
        var left = amount
        for index in shelves.indices where left > 0 && shelves[index].itemID == itemID && shelves[index].stock < capacity {
            let put = min(left, capacity - shelves[index].stock)
            shelves[index].stock += put
            left -= put
        }
        // Then empty shelves, ones that never held anything first.
        let empty = shelves.indices.filter { shelves[$0].stock == 0 }
            .sorted { (shelves[$0].itemID == nil ? 0 : 1, $0) < (shelves[$1].itemID == nil ? 0 : 1, $1) }
        for index in empty where left > 0 {
            if shelves[index].itemID != itemID { shelves[index] = Shelf(itemID: itemID) }
            let put = min(left, capacity)
            shelves[index].stock = put
            left -= put
        }
        return amount - left
    }

    // MARK: Prices and customers

    /// The price of one item at a price factor.
    public func unitPrice(_ itemID: String, factor: Double = 1) -> Int {
        guard let item = ItemCatalog.item(itemID) else { return 0 }
        let usual = Double(item.value.lowerBound + item.value.upperBound) / 2
        return max(1, Int((usual * factor).rounded()))
    }

    /// Variety draws a crowd.
    public func traffic(_ store: StoreState) -> Double {
        let kinds = Set(store.shelves.filter { $0.stock > 0 }.compactMap(\.itemID)).count
        return min(balance.storeTrafficMax, 1 + balance.storeTrafficPerItem * Double(max(0, kinds - 1)))
    }

    /// Items one shelf sells per open hour.
    public func salesPerHour(_ shelf: Shelf, in store: StoreState) -> Double {
        guard shelf.stock > 0, let id = shelf.itemID, let item = ItemCatalog.item(id) else { return 0 }
        let priceEffect = exp(-balance.storePriceSensitivity * (shelf.priceFactor - 1))
        return balance.storeDemand(item.category) * priceEffect * traffic(store)
    }

    /// Opening hours per day.
    public var openHours: Double { Double(store.closes - store.opens) }

    /// Customers buy for `hours` of opening time. Returns an event for each
    /// shelf that sold out.
    public func runSales(_ state: inout GameState, hours: Double) -> [SimEvent] {
        guard state.store.isRented, hours > 0 else { return [] }
        let snapshot = state.store
        var events: [SimEvent] = []
        for index in state.store.shelves.indices {
            var shelf = state.store.shelves[index]
            let rate = salesPerHour(shelf, in: snapshot)
            guard rate > 0, let itemID = shelf.itemID else { continue }
            shelf.progress += rate * hours
            let sold = min(shelf.stock, Int((shelf.progress + 1e-9).rounded(.down)))
            if sold > 0 {
                shelf.progress = max(0, shelf.progress - Double(sold))
                shelf.stock -= sold
                let coins = unitPrice(itemID, factor: shelf.priceFactor) * sold
                state.money += coins
                state.finance.earn(coins, LedgerCategory.shopSales)
                state.goals.add(GoalCounter.coinsFromShop, coins)
                state.store.today.coins += coins
                state.store.today.items += sold
                state.store.today.sales[itemID, default: 0] += sold
                state.store.totalCoins += coins
                if shelf.stock == 0 {
                    shelf.progress = 0
                    events.append(.shelfSoldOut(itemID: itemID))
                }
            }
            state.store.shelves[index] = shelf
        }
        return events
    }
}

/// Customers come in while the shop is open and the calendar runs (playing
/// or sleeping; the shop is shut while the game is closed).
public struct StoreSystem: SimulationSystem {
    public init() {}

    public func step(_ state: inout GameState, _ context: inout StepContext) {
        guard context.mode == .live else { return }
        let today = state.clock.dayIndex
        if state.store.today.day != today { state.store.today = StoreDay(day: today) }
        guard state.store.isRented else { return }
        // The clock has already moved on this step: look back over the span it covered.
        let end = state.clock.totalMinutes
        let start = end - context.dt * context.balance.gameMinutesPerRealSecond
        let minutes = Self.openMinutes(from: start, to: end, opens: StoreDefinition.corner.opens, closes: StoreDefinition.corner.closes)
        guard minutes > 0 else { return }
        context.events += Storekeeping(balance: context.balance).runSales(&state, hours: minutes / 60)
    }

    /// Opening minutes between two clock readings (in total game minutes).
    static func openMinutes(from start: Double, to end: Double, store: StoreDefinition) -> Double {
        openMinutes(from: start, to: end, opens: store.opens, closes: store.closes)
    }

    /// Minutes between two clock readings that fall between two wall-clock
    /// hours of a game day (both after 06:00).
    static func openMinutes(from start: Double, to end: Double, opens openHour: Int, closes closeHour: Int) -> Double {
        guard end > start else { return 0 }
        let opens = (Double(openHour) - GameClock.dayStartHour) * 60
        let closes = (Double(closeHour) - GameClock.dayStartHour) * 60
        let first = Int((start / GameClock.minutesPerDay).rounded(.down))
        let last = Int((end / GameClock.minutesPerDay).rounded(.down))
        var total = 0.0
        for day in first...last {
            let base = Double(day) * GameClock.minutesPerDay
            total += max(0, min(end, base + closes) - max(start, base + opens))
        }
        return total
    }
}

extension Simulation {
    /// Runs a shop action; failures leave the state unchanged.
    public mutating func store<T>(_ body: (Storekeeping, inout GameState) throws -> T) -> Result<T, StoreFailure> {
        var copy = state
        do {
            let value = try body(Storekeeping(balance: balance), &copy)
            modify { $0 = copy }
            return .success(value)
        } catch let failure as StoreFailure {
            return .failure(failure)
        } catch {
            preconditionFailure("Storekeeping only throws StoreFailure: \(error)")
        }
    }
}
