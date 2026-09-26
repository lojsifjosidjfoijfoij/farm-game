import Foundation

/// One tilled tile of farmland.
public struct Plot: Codable, Equatable, Sendable {
    public var tile: TileCoord
    /// The soil is wet until this `worldTime`. Wet soil makes crops grow at full speed.
    public var wetUntil: TimeInterval
    public var crop: PlantedCrop?

    public init(tile: TileCoord, wetUntil: TimeInterval = 0, crop: PlantedCrop? = nil) {
        self.tile = tile
        self.wetUntil = wetUntil
        self.crop = crop
    }

    public func isWet(at time: TimeInterval) -> Bool { time < wetUntil }
}

/// A crop growing in a plot. Growth is stored as accumulated seconds so the
/// visible stage and readiness are always derived, never stored.
public struct PlantedCrop: Codable, Equatable, Sendable {
    public var cropID: String
    /// `worldTime` when it was planted.
    public var plantedAt: TimeInterval
    /// Seconds of full-speed growth so far (capped at the crop's growth time).
    public var growth: TimeInterval
    /// Part of `growth` that happened in wet soil (future crop quality).
    public var wateredGrowth: TimeInterval
    /// Times harvested (regrowing crops).
    public var harvests: Int

    public init(cropID: String, plantedAt: TimeInterval, growth: TimeInterval = 0, wateredGrowth: TimeInterval = 0, harvests: Int = 0) {
        self.cropID = cropID
        self.plantedAt = plantedAt
        self.growth = growth
        self.wateredGrowth = wateredGrowth
        self.harvests = harvests
    }

    public var definition: CropDefinition? { CropCatalog.crop(cropID) }

    public var isReady: Bool {
        guard let def = definition else { return false }
        return growth >= def.growthSeconds
    }

    public var stage: Int { definition?.stage(forGrowth: growth) ?? 0 }
}

/// All farmland, indexed by tile. Saved as a list sorted by tile so save
/// files are stable and readable.
public struct FarmPlots: Equatable, Sendable {
    public private(set) var byTile: [TileCoord: Plot] = [:]

    public init(_ plots: [Plot] = []) {
        for plot in plots { byTile[plot.tile] = plot }
    }

    public subscript(tile: TileCoord) -> Plot? {
        get { byTile[tile] }
        set {
            if var plot = newValue {
                plot.tile = tile
                byTile[tile] = plot
            } else {
                byTile[tile] = nil
            }
        }
    }

    public var count: Int { byTile.count }
    public var isEmpty: Bool { byTile.isEmpty }

    /// Plots sorted north-to-south, west-to-east (deterministic order).
    public var sorted: [Plot] {
        byTile.values.sorted { a, b in
            a.tile.y != b.tile.y ? a.tile.y > b.tile.y : a.tile.x < b.tile.x
        }
    }

    /// Mutates every plot in place (fast path for simulation systems).
    public mutating func updateEach(_ body: (inout Plot) -> Void) {
        var index = byTile.values.startIndex
        while index != byTile.values.endIndex {
            body(&byTile.values[index])
            index = byTile.values.index(after: index)
        }
    }
}

extension FarmPlots: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(try container.decode([Plot].self))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(sorted)
    }
}
