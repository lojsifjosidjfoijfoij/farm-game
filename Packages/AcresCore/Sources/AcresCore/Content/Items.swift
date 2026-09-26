import Foundation

/// What kind of thing an item is. Decides storage rules and inventory grouping.
public enum ItemCategory: String, Sendable, CaseIterable {
    case seed
    case crop

    public var title: String {
        switch self {
        case .seed: "Seeds"
        case .crop: "Harvest"
        }
    }

    /// Seeds live in the seed pouch and don't take storage space.
    public var usesStorage: Bool { self != .seed }
}

/// Static description of an item type.
public struct ItemDefinition: Sendable, Hashable, Identifiable {
    public let id: String
    public let name: String
    public let category: ItemCategory
    /// Asset name of the icon (see the manifest).
    public let icon: String
    /// Typical market value per item, for display.
    public let value: ClosedRange<Int>
}

/// Every item in the game, derived from the content catalogs.
public enum ItemCatalog {
    public static let all: [ItemDefinition] = CropCatalog.all.flatMap { crop in
        [
            ItemDefinition(id: crop.produceItemID, name: crop.name, category: .crop,
                           icon: "item_\(crop.id)", value: crop.sellPrice),
            ItemDefinition(id: crop.seedItemID, name: "\(crop.name) seeds", category: .seed,
                           icon: "item_seeds_\(crop.id)", value: crop.seedCost...crop.seedCost),
        ]
    }

    private static let index: [String: ItemDefinition] = {
        var result: [String: ItemDefinition] = [:]
        for item in all { result[item.id] = item }
        return result
    }()

    public static func item(_ id: String) -> ItemDefinition? { index[id] }
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
