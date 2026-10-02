import Foundation

/// What the farmer has on hand to sell, deliver or put on a shelf: their bag
/// (always with them) and the truck bed when the truck is parked close by.
/// The market, clients and your shop all take from both, bag first.
public enum Goods {
    /// How far outside a place's stop zone the truck can stand and still count
    /// as "here". A place's button shows up to a tile out, so this is a little
    /// more generous: where the button shows, the goods in the truck count.
    public static let truckReach: Double = 2

    public static func truckIsNear(_ zone: TileRect, in state: GameState) -> Bool {
        state.farmer.inTruck || zone.insetBy(-truckReach).contains(state.truck.position)
    }

    /// How many of an item are on hand near `zone`.
    public static func count(_ itemID: String, near zone: TileRect, in state: GameState) -> Int {
        state.farmer.bag.count(itemID) + (truckIsNear(zone, in: state) ? state.truck.cargo.count(itemID) : 0)
    }

    /// Everything on hand near `zone`: the bag plus a nearby truck bed.
    public static func onHand(near zone: TileRect, in state: GameState) -> [String: Int] {
        var all = state.farmer.bag.items
        if truckIsNear(zone, in: state) {
            for (item, count) in state.truck.cargo.items { all[item, default: 0] += count }
        }
        return all
    }

    /// Takes up to `amount` of an item, from the bag first; returns how many.
    @discardableResult
    public static func take(_ itemID: String, _ amount: Int, near zone: TileRect, from state: inout GameState) -> Int {
        var left = max(0, amount)
        let fromBag = min(left, state.farmer.bag.count(itemID))
        state.farmer.bag.remove(itemID, fromBag)
        left -= fromBag
        var fromTruck = 0
        if left > 0, truckIsNear(zone, in: state) {
            fromTruck = min(left, state.truck.cargo.count(itemID))
            state.truck.cargo.remove(itemID, fromTruck)
        }
        return fromBag + fromTruck
    }

    /// True when the goods asked for are in the truck, but the truck is too far away.
    public static func truckHasThemButIsFar(_ items: [String], near zone: TileRect, in state: GameState) -> Bool {
        !truckIsNear(zone, in: state) && items.contains { state.truck.cargo.count($0) > 0 }
    }
}
