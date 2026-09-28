import Foundation

/// A patch of farmland. Crops only grow in fields: you start with one small
/// field, and more come up for sale as you level up and buy land.
public struct FieldDefinition: Sendable, Hashable, Identifiable {
    public let id: String
    public let name: String
    /// Whole tiles (integer edges).
    public let area: TileRect
    /// The land it's on (it's for sale once you own that).
    public let propertyID: String
    /// Coins to clear it for farming (0 for the starter field).
    public let price: Int
    public let unlockLevel: Int

    public func contains(_ tile: TileCoord) -> Bool { area.contains(tile.center) }

    public var tiles: [TileCoord] {
        var result: [TileCoord] = []
        for y in Int(area.minY)..<Int(area.maxY) {
            for x in Int(area.minX)..<Int(area.maxX) { result.append(TileCoord(x, y)) }
        }
        return result
    }

    public var tileCount: Int { Int(area.width) * Int(area.height) }
}

public enum FieldCatalog {
    /// The field every farm starts with, by the old overgrown patch east of the yard.
    public static let starterID = "home_1"

    public static let all: [FieldDefinition] = [
        // The home farm, inside the fence.
        FieldDefinition(id: "home_1", name: "Starter field", area: TileRect(minX: 37, minY: 32, maxX: 42, maxY: 35),
                        propertyID: "home_farm", price: 0, unlockLevel: 1),
        FieldDefinition(id: "home_2", name: "Old field", area: TileRect(minX: 37, minY: 35, maxX: 42, maxY: 38),
                        propertyID: "home_farm", price: 250, unlockLevel: 2),
        FieldDefinition(id: "home_3", name: "Fence field", area: TileRect(minX: 42, minY: 32, maxX: 45, maxY: 38),
                        propertyID: "home_farm", price: 600, unlockLevel: 3),
        FieldDefinition(id: "home_4", name: "Long field", area: TileRect(minX: 35, minY: 29, maxX: 45, maxY: 32),
                        propertyID: "home_farm", price: 1_200, unlockLevel: 4),
        // East Meadow.
        FieldDefinition(id: "meadow_1", name: "Meadow field", area: TileRect(minX: 50, minY: 31, maxX: 55, maxY: 36),
                        propertyID: "east_meadow", price: 500, unlockLevel: 3),
        FieldDefinition(id: "meadow_2", name: "North meadow field", area: TileRect(minX: 47, minY: 38, maxX: 53, maxY: 42),
                        propertyID: "east_meadow", price: 800, unlockLevel: 4),
        FieldDefinition(id: "meadow_3", name: "South meadow field", area: TileRect(minX: 47, minY: 26, maxX: 53, maxY: 30),
                        propertyID: "east_meadow", price: 1_000, unlockLevel: 5),
        // West Field.
        FieldDefinition(id: "west_1", name: "West field", area: TileRect(minX: 10, minY: 29, maxX: 15, maxY: 33),
                        propertyID: "west_field", price: 900, unlockLevel: 5),
        FieldDefinition(id: "west_2", name: "Hedge field", area: TileRect(minX: 10, minY: 35, maxX: 15, maxY: 40),
                        propertyID: "west_field", price: 1_200, unlockLevel: 6),
        // South Pasture.
        FieldDefinition(id: "south_1", name: "Big pasture field", area: TileRect(minX: 12, minY: 8, maxX: 20, maxY: 13),
                        propertyID: "south_pasture", price: 1_500, unlockLevel: 7),
        FieldDefinition(id: "south_2", name: "Roadside field", area: TileRect(minX: 24, minY: 6, maxX: 32, maxY: 11),
                        propertyID: "south_pasture", price: 1_800, unlockLevel: 7),
        FieldDefinition(id: "south_3", name: "Far pasture field", area: TileRect(minX: 43, minY: 3, maxX: 48, maxY: 8),
                        propertyID: "south_pasture", price: 2_000, unlockLevel: 8),
    ]

    public static func field(_ id: String) -> FieldDefinition? { all.first { $0.id == id } }

    public static func field(containing tile: TileCoord) -> FieldDefinition? { all.first { $0.contains(tile) } }

    /// Fields a farm at this level on this land may own (for old saves).
    static func earned(level: Int, properties: [String]) -> [String] {
        all.filter { $0.unlockLevel <= level && properties.contains($0.propertyID) }.map(\.id)
    }
}

extension GameState {
    /// True if the tile is in one of the farm's fields.
    public func isFarmland(_ tile: TileCoord) -> Bool {
        guard let field = FieldCatalog.field(containing: tile) else { return false }
        return ownedFields.contains(field.id)
    }
}

// MARK: - Features that open up as you level

/// Parts of the game that stay hidden until the farmer is ready for them, so
/// the start is small and simple and the game opens up level by level.
public enum Feature: String, CaseIterable, Sendable {
    /// The business phone: orders from the village, the books, the Farm tab.
    case phone
    case chores
    case axe
    case foraging
    case rod
    case almanac

    public var unlockLevel: Int {
        switch self {
        case .phone, .chores, .axe: 2
        case .foraging, .rod: 3
        case .almanac: 4
        }
    }

    /// For the level-up card.
    public var title: String {
        switch self {
        case .phone: "your phone: orders from the village"
        case .chores: "daily chores with rewards"
        case .axe: "the axe (chop trees for logs)"
        case .foraging: "wild finds in the woods and meadows"
        case .rod: "the fishing rod"
        case .almanac: "the almanac and your farm's rank"
        }
    }
}

extension GameState {
    public func has(_ feature: Feature) -> Bool { progress.level >= feature.unlockLevel }
}
