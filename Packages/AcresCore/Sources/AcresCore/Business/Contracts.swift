import Foundation

/// A business that orders goods from the farm.
public struct ClientDefinition: Sendable, Hashable, Identifiable {
    public let id: String
    public let name: String
    /// "Restaurant", "Bakery" …
    public let kind: String
    /// Where the truck stops to deliver (tile units).
    public let zone: TileRect
    /// Items it orders.
    public let wants: [String]
    public let opens: Int
    public let closes: Int

    public func isOpen(atHour hour: Int) -> Bool { hour >= opens && hour < closes }
}

public enum ClientCatalog {
    public static let all: [ClientDefinition] = [
        ClientDefinition(id: "rusty_spoon", name: "The Rusty Spoon", kind: "Restaurant", zone: HomeValleyMap.restaurantZone,
                         wants: ["carrot", "potato", "corn", "pumpkin", "egg", "milk", "truffle", "lettuce", "onion", "tomato",
                                 "garlic", "cabbage", "tomato_sauce", "cornmeal", "carrot_juice"], opens: 7, closes: 22),
        ClientDefinition(id: "hansens_bakery", name: "Hansen's Bakery", kind: "Bakery", zone: HomeValleyMap.bakeryZone,
                         wants: ["wheat", "egg", "milk", "apple", "cherry", "strawberry", "blueberry", "sunflower", "flour", "honey"],
                         opens: 5, closes: 17),
        ClientDefinition(id: "lumber_yard", name: "North Woods Lumber", kind: "Lumber yard", zone: HomeValleyMap.lumberYardZone,
                         wants: ["log", "plank"], opens: 7, closes: 18),
        ClientDefinition(id: "valley_deli", name: "Valley Deli", kind: "Delicatessen", zone: HomeValleyMap.deliZone,
                         wants: ["cheese", "goat_cheese", "strawberry_jam", "blueberry_jam", "honey", "apple_juice", "cherry_juice",
                                 "sunflower_oil", "sauerkraut", "pickled_onions", "cloth"], opens: 9, closes: 19),
    ]

    public static func client(_ id: String) -> ClientDefinition? { all.first { $0.id == id } }

    public static func client(at position: Vec2) -> ClientDefinition? { all.first { $0.zone.contains(position) } }
}

/// An order: deliver these goods to a client by the deadline for a reward.
public struct Contract: Codable, Equatable, Sendable, Identifiable {
    public var id: Int
    public var clientID: String
    /// Amounts ordered.
    public var items: [String: Int]
    /// Amounts delivered so far.
    public var delivered: [String: Int]
    public var reward: Int
    public var xp: Int
    /// The last game day to finish it (inclusive).
    public var deadlineDay: Int
    public var offeredDay: Int

    public init(id: Int, clientID: String, items: [String: Int], delivered: [String: Int] = [:], reward: Int, xp: Int,
                deadlineDay: Int, offeredDay: Int) {
        self.id = id
        self.clientID = clientID
        self.items = items
        self.delivered = delivered
        self.reward = reward
        self.xp = xp
        self.deadlineDay = deadlineDay
        self.offeredDay = offeredDay
    }

    public var client: ClientDefinition? { ClientCatalog.client(clientID) }

    public func remaining(_ item: String) -> Int { max(0, (items[item] ?? 0) - (delivered[item] ?? 0)) }

    public var isComplete: Bool { items.keys.allSatisfy { remaining($0) == 0 } }

    /// Items in a stable order, for display.
    public var sortedItems: [String] { items.keys.sorted() }
}

/// Contracts on offer, contracts accepted, and the farm's reputation.
public struct ContractBoard: Codable, Equatable, Sendable {
    public var offers: [Contract]
    public var active: [Contract]
    /// 0…100: reliable farmers get bigger, better-paid orders.
    public var reputation: Int
    public var completed: Int
    public var failed: Int
    public var nextID: Int

    public init(offers: [Contract] = [], active: [Contract] = [], reputation: Int = 10, completed: Int = 0,
                failed: Int = 0, nextID: Int = 1) {
        self.offers = offers
        self.active = active
        self.reputation = reputation
        self.completed = completed
        self.failed = failed
        self.nextID = nextID
    }
}

public enum ContractFailure: Error, Equatable, Sendable {
    case notFound
    case tooManyActive
    case notAtClient
    case truckNotHere
    case closed(opens: Int)
    case nothingToDeliver
}

/// What a delivery did.
public struct DeliveryResult: Equatable, Sendable {
    public var delivered: [String: Int]
    /// Contracts finished by this delivery, with their rewards.
    public var completed: [Contract]
    public var events: [SimEvent]
}

/// The rules of contracts. Pure functions over `GameState`.
public struct Contracts: Sendable {
    public let balance: Balance

    public init(balance: Balance) {
        self.balance = balance
    }

    /// Could the farm produce this item at its current level?
    public static func isObtainable(_ item: String, level: Int) -> Bool {
        if let crop = CropCatalog.crop(item) { return level >= crop.unlockLevel }
        if let species = AnimalCatalog.all.first(where: { $0.productItemID == item }) { return level >= species.unlockLevel }
        if let tree = TreeCatalog.all.first(where: { $0.fruitItemID == item }) { return level >= tree.unlockLevel + 1 }
        if let maker = WorkshopCatalog.maker(of: item) {
            return level >= maker.workshop.unlockLevel && maker.recipe.inputs.keys.allSatisfy { isObtainable($0, level: level) }
        }
        return item == "log"
    }

    /// Fills the board with fresh offers (called each morning).
    public func refreshOffers(_ state: inout GameState) {
        let today = state.clock.dayIndex
        // Offers stay up for two days.
        state.contracts.offers.removeAll { $0.offeredDay < today - 1 }
        var attempts = 0
        while state.contracts.offers.count < balance.contractOffersOnBoard && attempts < 12 {
            attempts += 1
            if let offer = makeOffer(&state) { state.contracts.offers.append(offer) }
        }
    }

    private func makeOffer(_ state: inout GameState) -> Contract? {
        let level = state.progress.level
        let clients = ClientCatalog.all.filter { client in client.wants.contains { Self.isObtainable($0, level: level) } }
        guard !clients.isEmpty else { return nil }
        let client = clients[Int(state.rng.nextUnit() * Double(clients.count)) % clients.count]
        let wanted = client.wants.filter { Self.isObtainable($0, level: level) }
        let itemCount = wanted.count > 1 && state.rng.nextUnit() < 0.4 ? 2 : 1
        var pool = wanted
        var picked: [String] = []
        for _ in 0..<itemCount {
            let index = Int(state.rng.nextUnit() * Double(pool.count)) % pool.count
            picked.append(pool.remove(at: index))
        }
        // Order size grows with level and reputation.
        let reputation = Double(state.contracts.reputation)
        let target = (140 + 45 * Double(level) + 3 * reputation) * (0.75 + 0.5 * state.rng.nextUnit())
        var items: [String: Int] = [:]
        var value = 0
        for item in picked {
            guard let definition = ItemCatalog.item(item) else { continue }
            let unit = Double(definition.value.lowerBound + definition.value.upperBound) / 2
            let amount = max(2, Int((target / Double(picked.count) / unit).rounded()))
            items[item] = amount
            value += Int(unit * Double(amount))
        }
        guard !items.isEmpty else { return nil }
        let bonus = balance.contractBonus + reputation / 250
        let reward = Int((Double(value) * (1 + bonus) / 5).rounded()) * 5
        let today = state.clock.dayIndex
        let days = 2 + Int(state.rng.nextUnit() * 3)  // 2…4 days
        let offer = Contract(id: state.contracts.nextID, clientID: client.id, items: items, reward: reward,
                             xp: max(5, reward / 25), deadlineDay: today + days, offeredDay: today)
        state.contracts.nextID += 1
        return offer
    }

    /// Takes an offer from the board. Its deadline counts from today.
    public func accept(_ id: Int, state: inout GameState) throws(ContractFailure) {
        guard let index = state.contracts.offers.firstIndex(where: { $0.id == id }) else { throw .notFound }
        guard state.contracts.active.count < balance.maxActiveContracts else { throw .tooManyActive }
        var contract = state.contracts.offers.remove(at: index)
        let days = contract.deadlineDay - contract.offeredDay
        contract.deadlineDay = state.clock.dayIndex + days
        state.contracts.active.append(contract)
    }

    public func decline(_ id: Int, state: inout GameState) {
        state.contracts.offers.removeAll { $0.id == id }
    }

    /// Hands over what the truck carries for this client's contracts
    /// (oldest deadline first). Finished contracts pay out at once.
    public func deliver(to clientID: String, state: inout GameState) throws(ContractFailure) -> DeliveryResult {
        guard let client = ClientCatalog.client(clientID) else { throw .notFound }
        guard client.zone.insetBy(-1).contains(state.farmerPosition) else { throw .notAtClient }
        guard client.zone.contains(state.truck.position) else { throw .truckNotHere }
        guard client.isOpen(atHour: state.clock.hour) else { throw .closed(opens: client.opens) }
        var delivered: [String: Int] = [:]
        var completed: [Contract] = []
        var events: [SimEvent] = []
        let order = state.contracts.active.indices
            .filter { state.contracts.active[$0].clientID == clientID }
            .sorted { state.contracts.active[$0].deadlineDay < state.contracts.active[$1].deadlineDay }
        for index in order {
            var contract = state.contracts.active[index]
            for item in contract.sortedItems {
                let amount = min(contract.remaining(item), state.truck.cargo.count(item))
                guard amount > 0 else { continue }
                state.truck.cargo.remove(item, amount)
                contract.delivered[item, default: 0] += amount
                delivered[item, default: 0] += amount
            }
            state.contracts.active[index] = contract
        }
        guard !delivered.isEmpty else { throw .nothingToDeliver }
        for contract in state.contracts.active where contract.isComplete {
            completed.append(contract)
            state.money += contract.reward
            state.finance.earn(contract.reward, LedgerCategory.contracts)
            state.contracts.completed += 1
            state.contracts.reputation = min(100, state.contracts.reputation + balance.reputationPerContract)
            state.goals.add(GoalCounter.contractsCompleted)
            events += Progression.addXP(contract.xp, to: &state, balance: balance)
        }
        state.contracts.active.removeAll { $0.isComplete }
        return DeliveryResult(delivered: delivered, completed: completed, events: events)
    }

    /// Contracts past their deadline fail (called each morning).
    public func expire(_ state: inout GameState) -> [SimEvent] {
        let today = state.clock.dayIndex
        let late = state.contracts.active.filter { $0.deadlineDay < today }
        guard !late.isEmpty else { return [] }
        state.contracts.active.removeAll { $0.deadlineDay < today }
        state.contracts.failed += late.count
        state.contracts.reputation = max(0, state.contracts.reputation - balance.reputationPerFailure * late.count)
        return late.map { .contractFailed(id: $0.id, clientID: $0.clientID) }
    }
}

extension Simulation {
    /// Runs a contract action; failures leave the state unchanged.
    public mutating func contracts<T>(_ body: (Contracts, inout GameState) throws -> T) -> Result<T, ContractFailure> {
        var copy = state
        do {
            let value = try body(Contracts(balance: balance), &copy)
            modify { $0 = copy }
            return .success(value)
        } catch let failure as ContractFailure {
            return .failure(failure)
        } catch {
            preconditionFailure("Contracts only throw ContractFailure: \(error)")
        }
    }
}
