import Foundation

/// Thick brush over land the farm can't use yet. A new farm is a small
/// clearing: the house, the barn, the yard and one field, with brush pressing
/// in on every side. More of the home farm clears as you level up, and land
/// you buy comes cleared. Brush blocks walking, driving and building (see
/// `Obstacles`), and wild finds don't turn up in it.
///
/// Derived from the level and the land you own, so nothing about it is saved.
public struct WildLand: Sendable, Equatable {
    /// A patch of the home farm and the level it clears at.
    public struct Patch: Sendable, Equatable {
        public let area: TileRect
        public let level: Int
    }

    /// The home farm outside the starting clearing (x 17…33, y 28…41 inside
    /// the fence). Patches never overlap, and each field lies in a patch that
    /// clears at the field's own level.
    public static let homePatches: [Patch] = [
        // Along the west fence, by the old well.
        Patch(area: TileRect(minX: 15, minY: 28, maxX: 17, maxY: 41), level: 2),
        // East of the first field (field 2).
        Patch(area: TileRect(minX: 33, minY: 28, maxX: 40, maxY: 35), level: 2),
        // The backyard behind the house and barn: the coop and the path to the woodlot.
        Patch(area: TileRect(minX: 15, minY: 41, maxX: 46, maxY: 50), level: 2),
        // Beside the barn (field 3).
        Patch(area: TileRect(minX: 33, minY: 35, maxX: 42, maxY: 41), level: 3),
        // The far corner (field 4).
        Patch(area: TileRect(minX: 40, minY: 28, maxX: 46, maxY: 35), level: 4),
        Patch(area: TileRect(minX: 42, minY: 35, maxX: 46, maxY: 41), level: 4),
    ]

    /// Tracks through land for sale stay open (the way up Goat Hill).
    static let openTracks = [HomeValleyMap.goatHillTrack]

    public let level: Int
    public let ownedProperties: Set<String>
    /// Fields you own are always clear (buying one clears it; old saves keep theirs).
    public let ownedFields: Set<String>
    /// Tiles that stay clear whatever the level: farmland from old saves.
    public let openTiles: Set<TileCoord>

    public init(level: Int, ownedProperties: some Sequence<String>, ownedFields: some Sequence<String> = [String](),
                openTiles: Set<TileCoord> = []) {
        self.level = level
        self.ownedProperties = Set(ownedProperties)
        self.ownedFields = Set(ownedFields)
        self.openTiles = openTiles
    }

    public init(state: GameState) {
        self.init(level: state.progress.level, ownedProperties: state.ownedProperties, ownedFields: state.ownedFields,
                  openTiles: Set(state.plots.sorted.map(\.tile)))
    }

    /// Nothing overgrown (for tools and tests that don't care).
    public static let none = WildLand(level: Int.max, ownedProperties: PropertyCatalog.all.map(\.id))

    /// Whether brush covers this tile.
    public func contains(_ tile: TileCoord) -> Bool {
        if openTiles.contains(tile) { return false }
        if let field = FieldCatalog.field(containing: tile), ownedFields.contains(field.id) { return false }
        let p = tile.center
        if Self.homePatches.contains(where: { $0.level > level && $0.area.contains(p) }) { return true }
        guard !Self.openTracks.contains(where: { $0.contains(p) }) else { return false }
        return PropertyCatalog.forSale.contains { !ownedProperties.contains($0.id) && $0.area.contains(p) }
    }

    /// Home patches that clear on reaching this level.
    public static func patches(clearingAt level: Int) -> [Patch] {
        homePatches.filter { $0.level == level }
    }
}
