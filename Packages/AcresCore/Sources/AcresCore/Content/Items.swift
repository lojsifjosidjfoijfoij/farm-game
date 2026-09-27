import Foundation

/// What kind of thing an item is. Decides storage rules, selling and
/// inventory grouping (in this order).
public enum ItemCategory: String, Sendable, CaseIterable {
    case crop
    case fruit
    case animalProduct
    case wood
    case feed
    case seed
    case sapling

    public var title: String {
        switch self {
        case .crop: "Harvest"
        case .fruit: "Fruit"
        case .animalProduct: "From the animals"
        case .wood: "Wood"
        case .feed: "Animal feed"
        case .seed: "Seeds"
        case .sapling: "Saplings"
        }
    }

    /// Seeds and saplings live in the seed pouch and don't take storage space.
    public var usesStorage: Bool { self != .seed && self != .sapling }

    /// Things markets buy.
    public var isSellable: Bool {
        switch self {
        case .crop, .fruit, .animalProduct, .wood: true
        case .feed, .seed, .sapling: false
        }
    }
}

/// Static description of an item type.
public struct ItemDefinition: Sendable, Hashable, Identifiable {
    public let id: String
    public let name: String
    /// Plural for messages ("eggs"; "wool" stays "wool").
    public let plural: String
    public let category: ItemCategory
    /// Asset name of the icon (see the manifest).
    public let icon: String
    /// Market value per item (sellable things), or the shop price.
    public let value: ClosedRange<Int>
}

/// Every item in the game, derived from the content catalogs.
public enum ItemCatalog {
    public static let all: [ItemDefinition] = {
        var items: [ItemDefinition] = []
        for crop in CropCatalog.all {
            items.append(ItemDefinition(id: crop.produceItemID, name: crop.name, plural: crop.plural, category: .crop,
                                        icon: "item_\(crop.id)", value: crop.sellPrice))
        }
        items += [
            ItemDefinition(id: "apple", name: "Apple", plural: "apples", category: .fruit, icon: "item_apple", value: 14...20),
            ItemDefinition(id: "cherry", name: "Cherry", plural: "cherries", category: .fruit, icon: "item_cherry", value: 22...30),
            ItemDefinition(id: "egg", name: "Egg", plural: "eggs", category: .animalProduct, icon: "item_egg", value: 18...26),
            ItemDefinition(id: "milk", name: "Milk", plural: "bottles of milk", category: .animalProduct, icon: "item_milk", value: 55...75),
            ItemDefinition(id: "wool", name: "Wool", plural: "wool", category: .animalProduct, icon: "item_wool", value: 80...110),
            ItemDefinition(id: "truffle", name: "Truffle", plural: "truffles", category: .animalProduct, icon: "item_truffle", value: 140...190),
            ItemDefinition(id: "log", name: "Log", plural: "logs", category: .wood, icon: "item_log", value: 8...12),
            ItemDefinition(id: "animal_feed", name: "Animal feed", plural: "sacks of feed", category: .feed,
                           icon: "item_animal_feed", value: 6...6),
        ]
        for crop in CropCatalog.all {
            items.append(ItemDefinition(id: crop.seedItemID, name: "\(crop.name) seeds", plural: "\(crop.name.lowercased()) seeds",
                                        category: .seed, icon: "item_seeds_\(crop.id)", value: crop.seedCost...crop.seedCost))
        }
        for tree in TreeCatalog.all {
            items.append(ItemDefinition(id: tree.saplingItemID, name: "\(tree.name) sapling",
                                        plural: "\(tree.name.lowercased()) saplings", category: .sapling,
                                        icon: "item_sapling_\(tree.id)", value: tree.saplingCost...tree.saplingCost))
        }
        return items
    }()

    private static let index: [String: ItemDefinition] = {
        var result: [String: ItemDefinition] = [:]
        for item in all { result[item.id] = item }
        return result
    }()

    public static func item(_ id: String) -> ItemDefinition? { index[id] }

    /// "1 egg", "4 eggs", "3 wool".
    public static func describe(_ count: Int, _ id: String) -> String {
        guard let item = item(id) else { return "\(count) \(id)" }
        return "\(count) \(count == 1 ? item.name.lowercased() : item.plural)"
    }
}

/// A pile of items: `[itemID: count]`. Counts are always positive.
public struct Inventory: Codable, Equatable, Sendable {
    public private(set) var items: [String: Int]

    public init(items: [String: Int] = [:]) {
        self.items = items.filter { $0.value > 0 }
    }

    public func count(_ id: String) -> Int { items[id] ?? 0 }

    public mutating func add(_ id: String, _ amount: Int) {
        guard amount > 0 else { return }
        items[id, default: 0] += amount
    }

    /// Removes items if enough are present; returns false (and changes nothing) otherwise.
    @discardableResult
    public mutating func remove(_ id: String, _ amount: Int) -> Bool {
        guard amount > 0 else { return true }
        let have = count(id)
        guard have >= amount else { return false }
        items[id] = have == amount ? nil : have - amount
        return true
    }

    /// Items that take up storage space (everything but seeds; unknown items count too).
    public var storageUsed: Int {
        items.reduce(0) { total, entry in
            let usesStorage = ItemCatalog.item(entry.key)?.category.usesStorage ?? true
            return total + (usesStorage ? entry.value : 0)
        }
    }
}
