import Foundation

/// What the market has bought lately. Every item sold makes the next one of
/// the same kind fetch a little less today; the buyers come back over the
/// next day or two. A small farm hardly notices. A farm that brings a mountain
/// of one thing does, so a bit of everything pays, and so do orders and your
/// own shop (neither touches the market price).
public struct MarketState: Codable, Equatable, Sendable {
    /// The game day `sold` was last brought up to date (-1: never).
    public var day: Int
    /// Recent sales per item, in coins at the usual price, fading each day
    /// (`Balance.marketRecoveryPerDay`).
    public var sold: [String: Double]

    public init(day: Int = -1, sold: [String: Double] = [:]) {
        self.day = day
        self.sold = sold
    }
}

/// The rules of supply and demand at the market. Pure functions over state.
///
/// Each item has a depth: the coins' worth (at its usual price) the market
/// takes before the price has fallen by half. The price factor for the next
/// one is `1 / (1 + recent / depth)`, never below `Balance.marketPriceFloor`.
/// Measured in coins, so a cartload of pumpkins weighs as much as a mountain
/// of wheat worth the same.
public struct Market: Sendable {
    public let balance: Balance

    public init(balance: Balance) {
        self.balance = balance
    }

    /// Coins' worth of an item the market takes before its price halves.
    public func depth(_ item: ItemDefinition, in state: GameState) -> Double {
        balance.marketDepth(item.category) * Village.perks(state).marketDepth
    }

    /// Today's price factor for the next one sold (1 = a fresh market).
    public func factor(_ itemID: String, in state: GameState) -> Double {
        guard let item = ItemCatalog.item(itemID) else { return 1 }
        return factor(sold: recent(itemID, in: state), depth: depth(item, in: state))
    }

    private func factor(sold: Double, depth: Double) -> Double {
        max(balance.marketPriceFloor, 1 / (1 + sold / max(1, depth)))
    }

    /// Recent sales of an item in coins, as of today (fading days applied).
    public func recent(_ itemID: String, in state: GameState) -> Double {
        let sold = state.market.sold[itemID] ?? 0
        let days = state.market.day < 0 ? 0 : max(0, state.clock.dayIndex - state.market.day)
        return sold * pow(memory(state), Double(days))
    }

    /// The share of recent sales still weighing on prices after a day.
    private func memory(_ state: GameState) -> Double {
        min(1, max(0, (1 - balance.marketRecoveryPerDay) * Village.perks(state).marketMemory))
    }

    /// What one of an item counts as, in coins (its usual price).
    private func weight(_ item: ItemDefinition) -> Double {
        Double(item.value.lowerBound + item.value.upperBound) / 2
    }

    /// What selling `count` of an item would earn now, one at a time, each a
    /// little less than the last.
    public func quote(_ itemID: String, count: Int, unitPrice: Int, in state: GameState) -> Int {
        guard count > 0, let item = ItemCatalog.item(itemID) else { return 0 }
        let depth = depth(item, in: state)
        let weight = weight(item)
        var sold = recent(itemID, in: state)
        var total = 0
        for _ in 0..<count {
            total += max(1, Int((Double(unitPrice) * factor(sold: sold, depth: depth)).rounded()))
            sold += weight
        }
        return total
    }

    /// Records a sale: brings every item up to today, then adds this one.
    public func record(_ itemID: String, count: Int, in state: inout GameState) {
        guard count > 0, let item = ItemCatalog.item(itemID) else { return }
        let today = state.clock.dayIndex
        if state.market.day != today {
            let days = state.market.day < 0 ? 0 : max(0, today - state.market.day)
            let fade = pow(memory(state), Double(days))
            state.market.sold = state.market.sold.compactMapValues { value in
                let faded = value * fade
                return faded < 1 ? nil : faded
            }
            state.market.day = today
        }
        state.market.sold[itemID, default: 0] += weight(item) * Double(count)
    }
}
