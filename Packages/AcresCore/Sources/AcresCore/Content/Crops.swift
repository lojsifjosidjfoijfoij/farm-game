import Foundation

/// Everything the game knows about one crop. Adding a crop = adding an entry
/// to `CropCatalog.all` (plus its art, listed automatically in the manifest).
public struct CropDefinition: Sendable, Hashable, Identifiable {
    public let id: String
    /// Display name, singular ("Carrot").
    public let name: String
    /// Plural for messages ("carrots"; "wheat" stays "wheat").
    public let plural: String
    /// Seasons in which it can be *planted*. Once planted it always finishes.
    public let seasons: Set<Season>
    /// Real seconds from planting to ripe when kept watered.
    public let growthSeconds: TimeInterval
    /// If set, the plant stays after harvest and ripens again after this long.
    public let regrowSeconds: TimeInterval?
    public let seedCost: Int
    /// Typical market price per item (markets vary it, Phase 3 and 5).
    public let sellPrice: ClosedRange<Int>
    /// Items per harvest.
    public let yield: ClosedRange<Int>
    /// Experience per harvest.
    public let xp: Int
    /// Farmer level needed to buy the seeds (enforced by shops).
    public let unlockLevel: Int
    /// Art direction for growth stages 0…4 (used by the asset manifest).
    public let stageNotes: [String]
    /// Art direction for the harvested item icon.
    public let produceNotes: String

    public var seedItemID: String { "seeds_\(id)" }
    public var produceItemID: String { id }

    public init(
        id: String, name: String, plural: String, seasons: Set<Season>,
        growthSeconds: TimeInterval, regrowSeconds: TimeInterval? = nil,
        seedCost: Int, sellPrice: ClosedRange<Int>, yield: ClosedRange<Int>,
        xp: Int, unlockLevel: Int, stageNotes: [String], produceNotes: String
    ) {
        self.id = id
        self.name = name
        self.plural = plural
        self.seasons = seasons
        self.growthSeconds = growthSeconds
        self.regrowSeconds = regrowSeconds
        self.seedCost = seedCost
        self.sellPrice = sellPrice
        self.yield = yield
        self.xp = xp
        self.unlockLevel = unlockLevel
        self.stageNotes = stageNotes
        self.produceNotes = produceNotes
    }

    /// Number of visible growth stages (0 = just planted … 4 = ripe).
    public static let stageCount = 5

    /// Visible stage for an amount of accumulated growth.
    public func stage(forGrowth growth: TimeInterval) -> Int {
        if growth >= growthSeconds { return 4 }
        let f = growth / growthSeconds
        switch f {
        case ..<0.12: return 0
        case ..<0.4: return 1
        case ..<0.7: return 2
        default: return 3
        }
    }

    public func canBePlanted(in season: Season) -> Bool { seasons.contains(season) }

    /// Seasons in calendar order, for display.
    public var seasonList: [Season] { Season.allCases.filter(seasons.contains) }
}

/// All crops in the game. Times are in game days for crops kept watered (one
/// watering lasts a day); dry soil halves the speed (`Balance.dryGrowthRate`).
public enum CropCatalog {
    public static let all: [CropDefinition] = [
        CropDefinition(
            id: "wheat", name: "Wheat", plural: "wheat", seasons: [.spring, .summer, .autumn],
            growthSeconds: GameTime.days(1), seedCost: 4, sellPrice: 10...14, yield: 3...4, xp: 2, unlockLevel: 1,
            stageNotes: [
                "freshly sown row, a few golden seeds on dark soil",
                "short green sprouts",
                "a tuft of green blades",
                "tall green stalks with young green ears",
                "tall golden stalks with heavy ears, gently nodding",
            ],
            produceNotes: "A bundle of golden wheat ears tied with twine."),
        CropDefinition(
            id: "carrot", name: "Carrot", plural: "carrots", seasons: [.spring, .autumn],
            growthSeconds: GameTime.days(1.5), seedCost: 8, sellPrice: 18...24, yield: 2...4, xp: 3, unlockLevel: 1,
            stageNotes: [
                "sown soil with tiny seeds",
                "thin feathery seedlings",
                "small feathery carrot tops",
                "lush feathery tops, a hint of orange at the soil",
                "big feathery tops with bright orange carrot shoulders showing",
            ],
            produceNotes: "Two fresh carrots with green tops."),
        CropDefinition(
            id: "potato", name: "Potato", plural: "potatoes", seasons: [.spring, .summer],
            growthSeconds: GameTime.days(2), seedCost: 15, sellPrice: 32...42, yield: 3...5, xp: 5, unlockLevel: 1,
            stageNotes: [
                "a small mound with a seed potato",
                "a few round leaves breaking the soil",
                "a leafy young potato plant",
                "a full bushy plant with small white-lilac flowers",
                "yellowing bush with potatoes peeking out at the base",
            ],
            produceNotes: "Three earthy potatoes."),
        CropDefinition(
            id: "strawberry", name: "Strawberry", plural: "strawberries", seasons: [.spring, .summer],
            growthSeconds: GameTime.days(3), regrowSeconds: GameTime.days(1.5), seedCost: 40, sellPrice: 16...22, yield: 4...6, xp: 4, unlockLevel: 3,
            stageNotes: [
                "sown soil",
                "tiny three-part leaves",
                "a low leafy rosette",
                "rosette with white flowers",
                "rosette hung with ripe red strawberries",
            ],
            produceNotes: "Two glossy red strawberries."),
        CropDefinition(
            id: "corn", name: "Corn", plural: "corn", seasons: [.summer, .autumn],
            growthSeconds: GameTime.days(4), seedCost: 30, sellPrice: 60...80, yield: 3...5, xp: 9, unlockLevel: 4,
            stageNotes: [
                "sown soil",
                "a single green sprout",
                "knee-high stalks with long leaves",
                "tall green stalks",
                "tall stalks with tassels and ripe yellow cobs in green husks",
            ],
            produceNotes: "An ear of corn with the husk pulled back."),
        CropDefinition(
            id: "pumpkin", name: "Pumpkin", plural: "pumpkins", seasons: [.autumn],
            growthSeconds: GameTime.days(6), seedCost: 80, sellPrice: 280...360, yield: 1...2, xp: 20, unlockLevel: 6,
            stageNotes: [
                "sown soil",
                "two round seed leaves",
                "a young vine with big lobed leaves",
                "vine with a small green pumpkin",
                "vine with a big ribbed orange pumpkin",
            ],
            produceNotes: "A round orange pumpkin with a curly stem."),

        // --- More crops (after Phase 9): something to plant in every season. ---
        CropDefinition(
            id: "lettuce", name: "Lettuce", plural: "lettuce", seasons: [.spring, .autumn],
            growthSeconds: GameTime.days(1), seedCost: 6, sellPrice: 20...26, yield: 1...2, xp: 2, unlockLevel: 2,
            stageNotes: ["sown soil", "tiny round seedlings", "a small loose rosette", "a full soft rosette", "a big crisp lettuce head"],
            produceNotes: "A crisp green lettuce head."),
        CropDefinition(
            id: "onion", name: "Onion", plural: "onions", seasons: [.spring, .autumn],
            growthSeconds: GameTime.days(2), seedCost: 12, sellPrice: 14...18, yield: 3...5, xp: 3, unlockLevel: 2,
            stageNotes: ["sown soil", "thin green shoots", "a clump of hollow leaves", "tall leaves, bulb swelling",
                         "flopped leaves over golden onion bulbs"],
            produceNotes: "Two golden onions with papery skins."),
        CropDefinition(
            id: "kale", name: "Kale", plural: "kale", seasons: [.winter, .spring],
            growthSeconds: GameTime.days(2), seedCost: 20, sellPrice: 34...44, yield: 2...3, xp: 4, unlockLevel: 3,
            stageNotes: ["sown soil", "small frilly seedlings", "a low frilly plant", "tall curly blue-green leaves",
                         "a lush frosty-green kale plant"],
            produceNotes: "A bunch of curly dark-green kale."),
        CropDefinition(
            id: "tomato", name: "Tomato", plural: "tomatoes", seasons: [.summer],
            growthSeconds: GameTime.days(3), regrowSeconds: GameTime.days(1), seedCost: 45, sellPrice: 18...24, yield: 3...5, xp: 4,
            unlockLevel: 3,
            stageNotes: ["sown soil", "a small seedling", "a young plant tied to a cane", "a leafy plant with yellow flowers",
                         "a staked plant hung with ripe red tomatoes"],
            produceNotes: "Two ripe red tomatoes."),
        CropDefinition(
            id: "garlic", name: "Garlic", plural: "garlic", seasons: [.autumn, .winter],
            growthSeconds: GameTime.days(3), seedCost: 25, sellPrice: 26...34, yield: 3...4, xp: 4, unlockLevel: 4,
            stageNotes: ["sown soil", "thin green shoots", "flat green leaves", "tall leaves with a curling scape",
                         "dry leaves over plump white bulbs"],
            produceNotes: "A plump white garlic bulb."),
        CropDefinition(
            id: "sunflower", name: "Sunflower", plural: "sunflowers", seasons: [.summer],
            growthSeconds: GameTime.days(3), seedCost: 25, sellPrice: 70...90, yield: 1...2, xp: 5, unlockLevel: 4,
            stageNotes: ["sown soil", "two broad seed leaves", "a knee-high stem", "a tall stem with a green bud",
                         "a tall sunflower with a big golden head"],
            produceNotes: "A sunflower head, bright petals around dark seeds."),
        CropDefinition(
            id: "blueberry", name: "Blueberry", plural: "blueberries", seasons: [.summer],
            growthSeconds: GameTime.days(4), regrowSeconds: GameTime.days(1.5), seedCost: 70, sellPrice: 20...26, yield: 5...8,
            xp: 5, unlockLevel: 5,
            stageNotes: ["sown soil", "a twig with a few leaves", "a small round bush", "a bush with white bell flowers",
                         "a bush covered in dusty blue berries"],
            produceNotes: "A cluster of dusty blue blueberries."),
        CropDefinition(
            id: "cabbage", name: "Cabbage", plural: "cabbages", seasons: [.autumn, .winter],
            growthSeconds: GameTime.days(3), seedCost: 30, sellPrice: 60...80, yield: 1...2, xp: 5, unlockLevel: 5,
            stageNotes: ["sown soil", "small round seedlings", "a spreading rosette", "a rosette cupping a young head",
                         "a big firm pale-green cabbage"],
            produceNotes: "A round pale-green cabbage."),
        CropDefinition(
            id: "melon", name: "Melon", plural: "melons", seasons: [.summer],
            growthSeconds: GameTime.days(5), seedCost: 90, sellPrice: 200...260, yield: 1...2, xp: 12, unlockLevel: 7,
            stageNotes: ["sown soil", "two round seed leaves", "a young vine", "a vine with a small striped melon",
                         "a vine with a big ripe striped melon"],
            produceNotes: "A striped green melon with a juicy slice."),
    ]

    private static let index: [String: CropDefinition] = {
        var result: [String: CropDefinition] = [:]
        for crop in all { result[crop.id] = crop }
        return result
    }()

    public static func crop(_ id: String) -> CropDefinition? { index[id] }

    /// The crop a seed item grows, if it is a seed.
    public static func crop(forSeed itemID: String) -> CropDefinition? {
        guard itemID.hasPrefix("seeds_") else { return nil }
        return index[String(itemID.dropFirst("seeds_".count))]
    }
}
