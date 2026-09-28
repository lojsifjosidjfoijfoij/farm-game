import Foundation

/// Everything the game knows about one kind of farm animal.
public struct AnimalSpecies: Sendable, Hashable, Identifiable {
    public let id: String
    /// Display name, singular ("Chicken").
    public let name: String
    /// Plural for messages ("chickens").
    public let plural: String
    /// What the young are called ("Chick").
    public let youngName: String
    /// Art family of the adult (`animal_<art>_idle`) and the young.
    public let adultArt: String
    public let youngArt: String
    /// The pen it lives in (`PenCatalog`).
    public let penID: String
    /// What it gives (an item ID).
    public let productItemID: String
    /// Real seconds from feeding to product with water in the trough.
    public let produceSeconds: TimeInterval
    /// Real seconds for a young animal to grow up.
    public let growUpSeconds: TimeInterval
    /// Items it eats, in order of preference (one per feeding).
    public let feeds: [String]
    /// Price of a young animal at the livestock market.
    public let price: Int
    /// Experience per product collected.
    public let xp: Int
    /// Farmer level needed to buy one.
    public let unlockLevel: Int
    /// Names given to new animals (picked at random, then numbered).
    public let names: [String]

    public init(
        id: String, name: String, plural: String, youngName: String, adultArt: String, youngArt: String,
        penID: String, productItemID: String, produceSeconds: TimeInterval, growUpSeconds: TimeInterval,
        feeds: [String], price: Int, xp: Int, unlockLevel: Int, names: [String]
    ) {
        self.id = id
        self.name = name
        self.plural = plural
        self.youngName = youngName
        self.adultArt = adultArt
        self.youngArt = youngArt
        self.penID = penID
        self.productItemID = productItemID
        self.produceSeconds = produceSeconds
        self.growUpSeconds = growUpSeconds
        self.feeds = feeds
        self.price = price
        self.xp = xp
        self.unlockLevel = unlockLevel
        self.names = names
    }
}

/// All farm animals. Times are in game days with water in the trough (a full
/// trough lasts a day); an empty one halves the pace (`Balance.dryProductionRate`).
public enum AnimalCatalog {
    public static let all: [AnimalSpecies] = [
        AnimalSpecies(
            id: "chicken", name: "Chicken", plural: "chickens", youngName: "Chick",
            adultArt: "chicken", youngArt: "chick", penID: "coop",
            productItemID: "egg", produceSeconds: GameTime.days(1), growUpSeconds: GameTime.days(1),
            feeds: ["wheat", "corn", "animal_feed"], price: 40, xp: 2, unlockLevel: 2,
            names: ["Henrietta", "Pip", "Nugget", "Clucky", "Maple", "Butterscotch", "Dotty", "Peaches"]),
        AnimalSpecies(
            id: "cow", name: "Cow", plural: "cows", youngName: "Calf",
            adultArt: "cow", youngArt: "calf", penID: "pasture",
            productItemID: "milk", produceSeconds: GameTime.days(1), growUpSeconds: GameTime.days(2),
            feeds: ["corn", "wheat", "animal_feed"], price: 250, xp: 5, unlockLevel: 4,
            names: ["Daisy", "Buttercup", "Clover", "Bessie", "Moomoo", "Hazel", "Tilly"]),
        AnimalSpecies(
            id: "sheep", name: "Sheep", plural: "sheep", youngName: "Lamb",
            adultArt: "sheep", youngArt: "lamb", penID: "sheepfold",
            productItemID: "wool", produceSeconds: GameTime.days(2), growUpSeconds: GameTime.days(2),
            feeds: ["carrot", "wheat", "animal_feed"], price: 350, xp: 7, unlockLevel: 5,
            names: ["Woolly", "Cloud", "Dolly", "Marshmallow", "Fluff", "Biscuit"]),
        AnimalSpecies(
            id: "pig", name: "Pig", plural: "pigs", youngName: "Piglet",
            adultArt: "pig", youngArt: "piglet", penID: "pigsty",
            productItemID: "truffle", produceSeconds: GameTime.days(3), growUpSeconds: GameTime.days(3),
            feeds: ["potato", "pumpkin", "corn", "animal_feed"], price: 450, xp: 10, unlockLevel: 6,
            names: ["Truffles", "Wilbur", "Petunia", "Hamlet", "Rosie", "Porkchop"]),
        AnimalSpecies(
            id: "goat", name: "Goat", plural: "goats", youngName: "Kid",
            adultArt: "goat", youngArt: "goat_kid", penID: "goat_pen",
            productItemID: "goat_milk", produceSeconds: GameTime.days(1), growUpSeconds: GameTime.days(2),
            feeds: ["cabbage", "kale", "carrot", "wheat", "animal_feed"], price: 320, xp: 6, unlockLevel: 5,
            names: ["Billy", "Nanny", "Pepper", "Clementine", "Juniper", "Biscuit", "Gruff"]),
    ]

    private static let index: [String: AnimalSpecies] = {
        var result: [String: AnimalSpecies] = [:]
        for species in all { result[species.id] = species }
        return result
    }()

    public static func species(_ id: String) -> AnimalSpecies? { index[id] }
}

/// A fenced yard on the farm where one kind of animal lives. Pens start
/// run-down and are repaired once, for coins.
public struct PenDefinition: Sendable, Hashable, Identifiable {
    public let id: String
    public let name: String
    public let speciesID: String
    /// The fenced yard (tile units). Animals roam inside; the truck stays out.
    public let area: TileRect
    /// The little house at the back of the yard, if any (asset + foot point).
    public let shelterKind: String?
    public let shelterPosition: Vec2
    /// Where the water trough stands (inside the yard).
    public let trough: Vec2
    public let capacity: Int
    public let repairCost: Int
    public let unlockLevel: Int

    public var species: AnimalSpecies? { AnimalCatalog.species(speciesID) }

    /// Where a tap counts as tapping the pen: the ground plus the shelter's picture.
    public var tapArea: TileRect {
        guard let shelterKind, let spec = AssetManifest.spec(named: shelterKind) else { return area }
        let halfWidth = spec.tilesWide * 0.45
        return TileRect(minX: min(area.minX, shelterPosition.x - halfWidth), minY: area.minY,
                        maxX: max(area.maxX, shelterPosition.x + halfWidth),
                        maxY: max(area.maxY, shelterPosition.y + spec.tilesHigh * (1 - spec.anchorY)))
    }

    /// Ground the pen takes up: the yard plus its shelter.
    public var footprint: TileRect {
        guard let shelterKind, let spec = AssetManifest.spec(named: shelterKind) else { return area }
        let halfWidth = spec.tilesWide * 0.45
        return TileRect(minX: min(area.minX, shelterPosition.x - halfWidth), minY: area.minY,
                        maxX: max(area.maxX, shelterPosition.x + halfWidth),
                        maxY: max(area.maxY, shelterPosition.y + spec.tilesHigh * 0.55))
    }
}

/// The pens behind the farmhouse (Phase 4). More farms and bigger pens come
/// with properties and buildings in Phase 6.
public enum PenCatalog {
    public static let all: [PenDefinition] = [
        PenDefinition(
            id: "coop", name: "Chicken coop", speciesID: "chicken",
            area: TileRect(minX: 17, minY: 43, maxX: 23, maxY: 47.6),
            shelterKind: "building_coop", shelterPosition: Vec2(20, 47.9),
            trough: Vec2(18.4, 43.8), capacity: 6, repairCost: 150, unlockLevel: 2),
        PenDefinition(
            id: "pasture", name: "Cow pasture", speciesID: "cow",
            area: TileRect(minX: 25, minY: 42.6, maxX: 35, maxY: 49),
            shelterKind: nil, shelterPosition: Vec2(30, 49),
            trough: Vec2(26.6, 43.4), capacity: 4, repairCost: 600, unlockLevel: 4),
        PenDefinition(
            id: "sheepfold", name: "Sheepfold", speciesID: "sheep",
            area: TileRect(minX: 37, minY: 43, maxX: 44.5, maxY: 47.6),
            shelterKind: "building_sheep_shelter", shelterPosition: Vec2(40.7, 47.9),
            trough: Vec2(38.4, 43.8), capacity: 4, repairCost: 900, unlockLevel: 5),
        PenDefinition(
            id: "pigsty", name: "Pigsty", speciesID: "pig",
            area: TileRect(minX: 17, minY: 50.6, maxX: 23, maxY: 54.4),
            shelterKind: "building_pigsty", shelterPosition: Vec2(20, 54.7),
            trough: Vec2(18.4, 51.4), capacity: 3, repairCost: 1200, unlockLevel: 6),
        // On Goat Hill (Phase 11), up the county road: bought with the land.
        PenDefinition(
            id: "goat_pen", name: "Goat pen", speciesID: "goat",
            area: TileRect(minX: 47.4, minY: 51.4, maxX: 53.6, maxY: 55.6),
            shelterKind: "building_goat_shed", shelterPosition: Vec2(50.5, 55.9),
            trough: Vec2(48.8, 52.2), capacity: 4, repairCost: 900, unlockLevel: 5),
    ]

    private static let index: [String: PenDefinition] = {
        var result: [String: PenDefinition] = [:]
        for pen in all { result[pen.id] = pen }
        return result
    }()

    public static func pen(_ id: String) -> PenDefinition? { index[id] }

    /// The pen whose ground (yard or shelter) contains a point.
    public static func pen(containing point: Vec2) -> PenDefinition? {
        all.first { $0.footprint.contains(point) }
    }

    /// The pen a tap at a point is meant for: its ground, or anywhere on the
    /// picture of its shelter (which stands taller than its footprint).
    public static func pen(tappedAt point: Vec2) -> PenDefinition? {
        all.first { $0.tapArea.contains(point) }
    }

    public static func pen(for speciesID: String) -> PenDefinition? {
        all.first { $0.speciesID == speciesID }
    }
}
