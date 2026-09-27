import Foundation

/// A piece of land the player can own: the starting farm, and the parcels
/// around it that come up for sale (Phase 8).
public struct PropertyDefinition: Sendable, Hashable, Identifiable {
    public let id: String
    public let name: String
    /// Farmable area in tile units.
    public let area: TileRect
    /// Purchase price; nil if it can't be bought (the starting farm).
    public let price: Int?
    /// Farmer level the seller asks for.
    public let unlockLevel: Int
    /// One line for the sale listing.
    public let blurb: String
    /// Where its FOR SALE sign stands (tile units).
    public let signSpot: Vec2?

    public init(id: String, name: String, area: TileRect, price: Int?, unlockLevel: Int = 1, blurb: String = "",
                signSpot: Vec2? = nil) {
        self.id = id
        self.name = name
        self.area = area
        self.price = price
        self.unlockLevel = unlockLevel
        self.blurb = blurb
        self.signSpot = signSpot
    }

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

    /// Land for sale around the farm. Areas never overlap each other or the
    /// county road (x 56–58).
    public static let forSale: [PropertyDefinition] = [
        PropertyDefinition(id: "east_meadow", name: "East Meadow", area: TileRect(minX: 46, minY: 25, maxX: 55.5, maxY: 49),
                           price: 2_500, unlockLevel: 2, blurb: "Flat meadow between your fence and the county road.",
                           signSpot: Vec2(47.2, 29.4)),
        PropertyDefinition(id: "north_woods", name: "North Woods", area: TileRect(minX: 16, minY: 57, maxX: 46, maxY: 72),
                           price: 4_000, unlockLevel: 4, blurb: "Old forest behind the woodlot: plenty of timber, room to clear.",
                           signSpot: Vec2(30.5, 57.6)),
        PropertyDefinition(id: "west_field", name: "West Field", area: TileRect(minX: 3, minY: 29, maxX: 16, maxY: 57),
                           price: 6_000, unlockLevel: 5, blurb: "Rolling fields west of the farm, with a few old trees.",
                           signSpot: Vec2(14.6, 34.6)),
        PropertyDefinition(id: "south_pasture", name: "South Pasture", area: TileRect(minX: 8, minY: 3, maxX: 55, maxY: 20.5),
                           price: 12_000, unlockLevel: 7, blurb: "A big sunny pasture across the road. Room for a real operation.",
                           signSpot: Vec2(28.6, 19.6)),
    ]

    public static let all: [PropertyDefinition] = [homeFarm] + forSale

    public static func property(_ id: String) -> PropertyDefinition? {
        all.first { $0.id == id }
    }

    public static func property(containing tile: TileCoord) -> PropertyDefinition? {
        all.first { $0.contains(tile) }
    }
}
