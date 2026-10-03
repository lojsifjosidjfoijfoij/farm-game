import Foundation

/// Ground material of a tile. Grass is the base; the others are painted on top
/// with soft, organic edges by the renderer.
///
/// Raw values are stable (they may be stored in map files); append only.
public enum Terrain: UInt8, Sendable, CaseIterable {
    case grass = 0
    case dirt = 1
    case gravel = 2
    case asphalt = 3
}

/// How much of each non-grass terrain surrounds a point (0…1 each).
/// Grass is whatever is left. Used to paint soft terrain transitions.
public struct TerrainCoverage: Equatable, Sendable {
    public var dirt: Double
    public var gravel: Double
    public var asphalt: Double

    public init(dirt: Double = 0, gravel: Double = 0, asphalt: Double = 0) {
        self.dirt = dirt
        self.gravel = gravel
        self.asphalt = asphalt
    }

    public var grass: Double { max(0, 1 - dirt - gravel - asphalt) }
}

/// Chunk coordinate. The world is streamed in square chunks of
/// `WorldMap.chunkSize` × `WorldMap.chunkSize` tiles.
public struct ChunkCoord: Hashable, Sendable, CustomStringConvertible {
    public var x: Int
    public var y: Int

    public init(_ x: Int, _ y: Int) {
        self.x = x
        self.y = y
    }

    public var description: String { "chunk(\(x), \(y))" }
}

/// A decorative or interactive thing placed on the map by the level designer.
public struct MapObject: Hashable, Sendable {
    /// Asset family name, e.g. "tree_oak" or "building_farmhouse_t0". The
    /// renderer resolves it to a concrete asset (e.g. adding a season suffix).
    public let kind: String
    /// The object's foot point (where it touches the ground), in tile units.
    public let position: Vec2
    /// Small visual variation (size/tint), chosen by the map builder.
    public let variant: Int

    public init(kind: String, position: Vec2, variant: Int = 0) {
        self.kind = kind
        self.position = position
        self.variant = variant
    }
}

/// Static, hand-designed world content: terrain and placed objects.
///
/// This is *content*, not save state. Things the player changes (plowed
/// fields, chopped trees, bought land) live in `GameState` as overlays.
public struct WorldMap: Sendable {
    /// Tiles per chunk side.
    public static let chunkSize = 16

    public let name: String
    /// Size in tiles.
    public let width: Int
    public let height: Int
    private let terrain: [Terrain]
    public let objects: [MapObject]
    private let objectIndicesByChunk: [ChunkCoord: [Int]]
    /// Tiles covered by solid objects (buildings, trees, the pond, …) and solid
    /// areas (pens): no farming or driving there. Ignores the player's changes
    /// to trees; `Obstacles` combines both.
    public let blockedTiles: Set<TileCoord>
    /// Like `blockedTiles`, minus what wild trees and old stumps cover.
    public let solidTiles: Set<TileCoord>
    /// Wild trees and stumps by the tile their trunk stands on.
    public let treesByFoot: [TileCoord: [MapObject]]
    /// For each tile a wild tree covers, the trunk tiles of the trees covering it.
    public let treeCover: [TileCoord: [TileCoord]]
    /// What the truck bumps into, shape by shape (see `DrivingObstacles`).
    public let colliders: [Collider]
    /// The colliders overlapping each tile (indices into `colliders`).
    private let collidersByTile: [TileCoord: [Int]]

    public init(name: String, width: Int, height: Int, terrain: [Terrain], objects: [MapObject],
                solidAreas: [TileRect] = []) {
        precondition(width > 0 && height > 0 && terrain.count == width * height)
        self.name = name
        self.width = width
        self.height = height
        self.terrain = terrain
        self.objects = objects

        var index: [ChunkCoord: [Int]] = [:]
        for (i, object) in objects.enumerated() {
            index[Self.chunk(containing: object.position), default: []].append(i)
        }
        self.objectIndicesByChunk = index

        var solid = Set<TileCoord>()
        var treesByFoot: [TileCoord: [MapObject]] = [:]
        var treeCover: [TileCoord: [TileCoord]] = [:]
        for object in objects {
            guard let rect = ObjectFootprint.rect(for: object) else { continue }
            if TreeCatalog.isMapTree(object.kind) {
                let foot = TileCoord(containing: object.position)
                treesByFoot[foot, default: []].append(object)
                for tile in Self.tiles(covering: rect) { treeCover[tile, default: []].append(foot) }
            } else {
                solid.formUnion(Self.tiles(covering: rect))
            }
        }
        for area in solidAreas { solid.formUnion(Self.tiles(covering: area)) }

        var colliders: [Collider] = []
        var collidersByTile: [TileCoord: [Int]] = [:]
        func addCollider(_ collider: Collider) {
            for tile in Self.tiles(covering: collider.rect) { collidersByTile[tile, default: []].append(colliders.count) }
            colliders.append(collider)
        }
        for object in objects {
            guard let rect = ObjectFootprint.collider(for: object) else { continue }
            let foot = TreeCatalog.isMapTree(object.kind) ? TileCoord(containing: object.position) : nil
            addCollider(Collider(rect: rect, treeFoot: foot))
        }
        for area in solidAreas { addCollider(Collider(rect: area)) }
        self.colliders = colliders
        self.collidersByTile = collidersByTile
        self.solidTiles = solid
        self.treesByFoot = treesByFoot
        self.treeCover = treeCover
        self.blockedTiles = solid.union(treeCover.keys)
    }

    /// Tiles a rectangle overlaps (by area, not just centers).
    static func tiles(covering rect: TileRect) -> [TileCoord] {
        let x0 = Int(rect.minX.rounded(.down)), x1 = Int((rect.maxX - 1e-9).rounded(.down))
        let y0 = Int(rect.minY.rounded(.down)), y1 = Int((rect.maxY - 1e-9).rounded(.down))
        guard x0 <= x1, y0 <= y1 else { return [] }
        var result: [TileCoord] = []
        for y in y0...y1 {
            for x in x0...x1 { result.append(TileCoord(x, y)) }
        }
        return result
    }

    public func isBlocked(_ tile: TileCoord) -> Bool { blockedTiles.contains(tile) }

    /// The colliders overlapping a tile (indices into `colliders`).
    public func colliderIndex(at tile: TileCoord) -> [Int] { collidersByTile[tile] ?? [] }

    public var bounds: TileRect { TileRect(x: 0, y: 0, width: Double(width), height: Double(height)) }

    public var chunkColumns: Int { (width + Self.chunkSize - 1) / Self.chunkSize }
    public var chunkRows: Int { (height + Self.chunkSize - 1) / Self.chunkSize }

    public func isInside(_ tile: TileCoord) -> Bool {
        tile.x >= 0 && tile.y >= 0 && tile.x < width && tile.y < height
    }

    /// Terrain at a tile. Outside the map, the nearest edge tile is returned so
    /// the world "continues" naturally past its border.
    public func terrain(at tile: TileCoord) -> Terrain {
        let x = min(max(tile.x, 0), width - 1)
        let y = min(max(tile.y, 0), height - 1)
        return terrain[y * width + x]
    }

    public static func chunk(containing point: Vec2) -> ChunkCoord {
        let size = Double(chunkSize)
        return ChunkCoord(Int((point.x / size).rounded(.down)), Int((point.y / size).rounded(.down)))
    }

    public func isValid(_ chunk: ChunkCoord) -> Bool {
        chunk.x >= 0 && chunk.y >= 0 && chunk.x < chunkColumns && chunk.y < chunkRows
    }

    /// The chunk's area in tile units.
    public func rect(of chunk: ChunkCoord) -> TileRect {
        let size = Double(Self.chunkSize)
        return TileRect(x: Double(chunk.x) * size, y: Double(chunk.y) * size, width: size, height: size)
    }

    public func objects(in chunk: ChunkCoord) -> [MapObject] {
        (objectIndicesByChunk[chunk] ?? []).map { objects[$0] }
    }

    /// All valid chunks overlapping a rectangle (tile units).
    public func chunks(overlapping rect: TileRect) -> [ChunkCoord] {
        let size = Double(Self.chunkSize)
        let minX = max(0, Int((rect.minX / size).rounded(.down)))
        let minY = max(0, Int((rect.minY / size).rounded(.down)))
        let maxX = min(chunkColumns - 1, Int((rect.maxX / size).rounded(.down)))
        let maxY = min(chunkRows - 1, Int((rect.maxY / size).rounded(.down)))
        guard minX <= maxX, minY <= maxY else { return [] }
        var result: [ChunkCoord] = []
        result.reserveCapacity((maxX - minX + 1) * (maxY - minY + 1))
        for y in minY...maxY {
            for x in minX...maxX {
                result.append(ChunkCoord(x, y))
            }
        }
        return result
    }

    /// Box-blurred terrain coverage around `point` (tile units): the fraction of
    /// a `2·radius` square that is dirt / gravel / asphalt. Adjacent chunks
    /// sample the same global function, so terrain blends seamlessly across
    /// chunk borders.
    public func coverage(at point: Vec2, radius: Double = 0.5, samples: Int = 4) -> TerrainCoverage {
        let n = max(1, samples)
        var dirt = 0, gravel = 0, asphalt = 0
        for sy in 0..<n {
            for sx in 0..<n {
                // Sample at the centers of an n×n grid spanning the square.
                let fx = (Double(sx) + 0.5) / Double(n) * 2 - 1
                let fy = (Double(sy) + 0.5) / Double(n) * 2 - 1
                let p = Vec2(point.x + fx * radius, point.y + fy * radius)
                switch terrain(at: TileCoord(containing: p)) {
                case .grass: break
                case .dirt: dirt += 1
                case .gravel: gravel += 1
                case .asphalt: asphalt += 1
                }
            }
        }
        let total = Double(n * n)
        return TerrainCoverage(dirt: Double(dirt) / total, gravel: Double(gravel) / total, asphalt: Double(asphalt) / total)
    }
}
