import Foundation

/// What the market has bought lately. Every item sold makes the next one of
/// the same kind fetch a little less today; the buyers come back over the
/// next few days. Selling a bit of everything pays, and so do orders and your
/// own shop (neither touches the market price).
public struct MarketState: Codable, Equatable, Sendable {
    /// The game day `sold` was last brought up to date (-1: never).
    public var day: Int
    /// Recent sales per item, fading by `Balance.marketRecoveryPerDay` each day.
    public var sold: [String: Double]

    public init(day: Int = -1, sold: [String: Double] = [:]) {
        self.day = day
        self.sold = sold
    }
}

/// The rules of supply and demand at the market. Pure functions over state.
public struct Market: Sendable {
    public let balance: Balance

    public init(balance: Balance) {
        self.balance = balance
    }

    /// How many of an item the market takes before the price has fallen by
    /// half. Cheap, everyday goods have more buyers than costly ones.
    public func depth(_ item: ItemDefinition, in state: GameState) -> Double {
        let base: Double = switch item.category {
        case .crop: 45
        case .fruit: 35
        case .animalProduct: 30
        case .wood: 60
        case .artisan: 18
        case .fish: 25
        case .forage: 25
        case .feed, .seed, .sapling, .machine: 1_000
        }
        return base * Village.perks(state).marketDepth
    }

    /// Today's price factor for the next one sold (1 = fresh market).
    public func factor(_ itemID: String, in state: GameState) -> Double {
        guard let item = ItemCatalog.item(itemID) else { return 1 }
        return factor(sold: recent(itemID, in: state), depth: depth(item, in: state))
    }

    private func factor(sold: Double, depth: Double) -> Double {
        max(balance.marketPriceFloor, 1 / (1 + sold / depth))
    }

    /// Recent sales of an item, as of today (fading days applied).
    public func recent(_ itemID: String, in state: GameState) -> Double {
        let sold = state.market.sold[itemID] ?? 0
        let days = state.market.day < 0 ? 0 : max(0, state.clock.dayIndex - state.market.day)
        return sold * pow(keep(state), Double(days))
    }

    /// The share of recent sales still weighing on the price after a day.
    private func keep(_ state: GameState) -> Double {
        max(0, 1 - balance.marketRecoveryPerDay * Village.perks(state).marketRecovery)
    }

    /// What selling `count` of an item would earn now, one at a time.
    public func quote(_ itemID: String, count: Int, unitPrice: Int, in state: GameState) -> Int {
        guard count > 0, let item = ItemCatalog.item(itemID) else { return 0 }
        let depth = depth(item, in: state)
        var sold = recent(itemID, in: state)
        var total = 0
        for _ in 0..<count {
            total += max(1, Int((Double(unitPrice) * factor(sold: sold, depth: depth)).rounded()))
            sold += 1
        }
        return total
    }

    /// Records a sale: brings every item up to today, then adds this one.
    public func record(_ itemID: String, count: Int, in state: inout GameState) {
        let today = state.clock.dayIndex
        if state.market.day != today {
            let days = state.market.day < 0 ? 0 : max(0, today - state.market.day)
            let fade = pow(keep(state), Double(days))
            state.market.sold = state.market.sold.compactMapValues { value in
                let faded = value * fade
                return faded < 0.5 ? nil : faded
            }
            state.market.day = today
        }
        state.market.sold[itemID, default: 0] += Double(count)
    }
}
