import Foundation

/// A piece of land the player can own. More arrive in Phase 6 (fields next
/// door, forest plots, the lakeside cabin, …).
public struct PropertyDefinition: Sendable, Hashable, Identifiable {
    public let id: String
    public let name: String
    /// Farmable area in tile units.
    public let area: TileRect
    /// Purchase price; nil if it can't be bought (the starting farm).
    public let price: Int?

    public func contains(_ tile: TileCoord) -> Bool {
        area.contains(tile.center)
    }
}

public enum PropertyCatalog {
    /// The run-down starting farm: the fenced fields around the farmhouse,
    /// plus (since Phase 4) the backyard pens and the woodlot behind them.
    public static let homeFarm = PropertyDefinition(
        id: "home_farm", name: "Your farm",
        area: TileRect(minX: 16, minY: 29, maxX: 46, maxY: 57),
        price: nil)

    public static let all: [PropertyDefinition] = [homeFarm]

    public static func property(_ id: String) -> PropertyDefinition? {
        all.first { $0.id == id }
    }

    public static func property(containing tile: TileCoord) -> PropertyDefinition? {
        all.first { $0.contains(tile) }
    }
}
