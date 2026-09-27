import Foundation

/// Smooth 2D value noise in -1…1, deterministic for a given seed.
/// Used for organic terrain edges and scatter placement.
public struct ValueNoise: Sendable {
    public let seed: UInt64

    public init(seed: UInt64) {
        self.seed = seed
    }

    /// Noise at a point; `scale` is the feature size in the same units as `p`.
    public func value(at p: Vec2, scale: Double) -> Double {
        let x = p.x / scale
        let y = p.y / scale
        let x0 = x.rounded(.down), y0 = y.rounded(.down)
        let tx = smooth(x - x0), ty = smooth(y - y0)
        let ix = Int(x0), iy = Int(y0)
        let a = lattice(ix, iy), b = lattice(ix + 1, iy)
        let c = lattice(ix, iy + 1), d = lattice(ix + 1, iy + 1)
        let top = a + (b - a) * tx
        let bottom = c + (d - c) * tx
        return top + (bottom - top) * ty
    }

    private func smooth(_ t: Double) -> Double { t * t * (3 - 2 * t) }

    private func lattice(_ x: Int, _ y: Int) -> Double {
        var h = seed ^ (UInt64(bitPattern: Int64(x)) &* 0x9E37_79B9_7F4A_7C15)
        h ^= UInt64(bitPattern: Int64(y)) &* 0xC2B2_AE3D_27D4_EB4F
        h = (h ^ (h >> 31)) &* 0xBF58_476D_1CE4_E5B9
        h ^= h >> 29
        return Double(h >> 11) / Double(1 << 53) * 2 - 1
    }
}

/// A tiny DSL for hand-designing maps in code: paint terrain shapes, place
/// landmarks precisely, and scatter nature deterministically.
///
/// Later phases can add a PNG-based importer (paint the world in any image
/// editor, one pixel per tile) that feeds the same `WorldMap` type.
public struct MapBuilder {
    public let width: Int
    public let height: Int
    private var terrain: [Terrain]
    private var objects: [MapObject] = []
    /// Footprint radius of each placed object, parallel to `objects`.
    private var radii: [Double] = []
    /// Areas where scatter must not place anything (buildings, yards).
    private var reserved: [TileRect] = []
    /// Spatial hash (tile index → object indices) for fast spacing checks.
    private var buckets: [Int: [Int]] = [:]
    private var rng: SeededRandom
    private let noise: ValueNoise

    public init(width: Int, height: Int, seed: UInt64) {
        self.width = width
        self.height = height
        self.terrain = Array(repeating: .grass, count: width * height)
        self.rng = SeededRandom(seed: seed)
        self.noise = ValueNoise(seed: seed ^ 0xA5A5_5A5A)
    }

    public func terrain(at tile: TileCoord) -> Terrain? {
        guard tile.x >= 0, tile.y >= 0, tile.x < width, tile.y < height else { return nil }
        return terrain[tile.y * width + tile.x]
    }

    // MARK: Terrain painting

    /// Paints every tile whose center lies inside an ellipse. `roughness`
    /// (in tiles) wobbles the edge with smooth noise so shapes look natural.
    public mutating func paintEllipse(_ type: Terrain, center: Vec2, radiusX: Double, radiusY: Double, roughness: Double = 0) {
        let pad = roughness + 1
        for tile in tiles(minX: center.x - radiusX - pad, minY: center.y - radiusY - pad,
                          maxX: center.x + radiusX + pad, maxY: center.y + radiusY + pad) {
            let p = tile.center
            let dx = (p.x - center.x) / radiusX
            let dy = (p.y - center.y) / radiusY
            let d = (dx * dx + dy * dy).squareRoot()  // 1.0 on the ellipse edge
            let wobble = noise.value(at: p, scale: 3) * roughness / max(radiusX, radiusY)
            if d <= 1 + wobble { set(type, at: tile) }
        }
    }

    /// Paints a road or path along a polyline.
    public mutating func paintPath(_ type: Terrain, through points: [Vec2], width pathWidth: Double, roughness: Double = 0) {
        guard points.count >= 2 else { return }
        let half = pathWidth / 2
        for i in 0..<(points.count - 1) {
            let a = points[i], b = points[i + 1]
            let pad = half + roughness + 1
            for tile in tiles(minX: min(a.x, b.x) - pad, minY: min(a.y, b.y) - pad,
                              maxX: max(a.x, b.x) + pad, maxY: max(a.y, b.y) + pad) {
                let p = tile.center
                let wobble = noise.value(at: p, scale: 4) * roughness
                if Self.distance(from: p, toSegment: a, b) <= half + wobble {
                    set(type, at: tile)
                }
            }
        }
    }

    /// Paints a rectangle (tile centers inside `rect`).
    public mutating func paintRect(_ type: Terrain, _ rect: TileRect) {
        for tile in tiles(minX: rect.minX, minY: rect.minY, maxX: rect.maxX, maxY: rect.maxY)
        where rect.contains(tile.center) {
            set(type, at: tile)
        }
    }

    // MARK: Objects

    /// Keeps scatter out of an area (e.g. a building's footprint or a yard).
    public mutating func reserve(_ rect: TileRect) {
        reserved.append(rect)
    }

    /// Places an object at an exact spot. `radius` is its footprint for spacing checks.
    public mutating func place(_ kind: String, at position: Vec2, variant: Int = 0, radius: Double = 0.4) {
        let index = objects.count
        objects.append(MapObject(kind: kind, position: position, variant: variant))
        radii.append(radius)
        buckets[bucketKey(for: position), default: []].append(index)
    }

    /// Randomly (but deterministically) places up to `count` objects in `area`.
    /// - Parameters:
    ///   - kinds: picked at random per object.
    ///   - radius: footprint of each new object; it never overlaps other footprints.
    ///   - spacing: extra minimum distance between objects of this batch.
    ///   - on: terrain the object may stand on.
    ///   - density: optional 0…1 function; lower values thin out placement (clearings).
    public mutating func scatter(
        _ kinds: [String],
        count: Int,
        in area: TileRect,
        radius: Double,
        spacing: Double = 0,
        on allowed: Set<Terrain> = [.grass],
        variants: Int = 4,
        density: ((Vec2) -> Double)? = nil
    ) {
        guard !kinds.isEmpty, count > 0 else { return }
        var placed = 0
        var attempts = 0
        let maxAttempts = count * 40
        var batch: [Vec2] = []
        while placed < count && attempts < maxAttempts {
            attempts += 1
            let p = Vec2(rng.next(in: area.minX...area.maxX), rng.next(in: area.minY...area.maxY))
            guard let t = terrain(at: TileCoord(containing: p)), allowed.contains(t) else { continue }
            if let density, rng.nextUnit() > density(p) { continue }
            if reserved.contains(where: { $0.contains(p) }) { continue }
            if !isFree(p, radius: radius) { continue }
            if spacing > 0, batch.contains(where: { $0.distance(to: p) < spacing }) { continue }
            let kind = kinds[Int(rng.nextUnit() * Double(kinds.count)) % kinds.count]
            place(kind, at: p, variant: Int(rng.nextUnit() * Double(max(1, variants))), radius: radius)
            batch.append(p)
            placed += 1
        }
    }

    /// Removes placed objects matching a condition (given the object and the
    /// terrain under it), e.g. trees left standing where a new road was painted.
    public mutating func removeObjects(where shouldRemove: (MapObject, Terrain) -> Bool) {
        var keptObjects: [MapObject] = []
        var keptRadii: [Double] = []
        for (object, radius) in zip(objects, radii) {
            let terrain = terrain(at: TileCoord(containing: object.position)) ?? .grass
            if shouldRemove(object, terrain) { continue }
            keptObjects.append(object)
            keptRadii.append(radius)
        }
        objects = keptObjects
        radii = keptRadii
        buckets = [:]
        for (index, object) in objects.enumerated() {
            buckets[bucketKey(for: object.position), default: []].append(index)
        }
    }

    /// Smooth noise shared with terrain painting, for density functions.
    public func noiseValue(at p: Vec2, scale: Double) -> Double {
        noise.value(at: p, scale: scale)
    }

    public func build(name: String) -> WorldMap {
        WorldMap(name: name, width: width, height: height, terrain: terrain, objects: objects)
    }

    // MARK: Helpers

    private mutating func set(_ type: Terrain, at tile: TileCoord) {
        guard tile.x >= 0, tile.y >= 0, tile.x < width, tile.y < height else { return }
        terrain[tile.y * width + tile.x] = type
    }

    /// All map tiles within a bounding box (clipped to the map).
    private func tiles(minX: Double, minY: Double, maxX: Double, maxY: Double) -> [TileCoord] {
        let x0 = max(0, Int(minX.rounded(.down))), x1 = min(width - 1, Int(maxX.rounded(.up)))
        let y0 = max(0, Int(minY.rounded(.down))), y1 = min(height - 1, Int(maxY.rounded(.up)))
        guard x0 <= x1, y0 <= y1 else { return [] }
        var result: [TileCoord] = []
        result.reserveCapacity((x1 - x0 + 1) * (y1 - y0 + 1))
        for y in y0...y1 {
            for x in x0...x1 {
                result.append(TileCoord(x, y))
            }
        }
        return result
    }

    private func bucketKey(for p: Vec2) -> Int {
        let tile = TileCoord(containing: p)
        return tile.y &* 100_003 &+ tile.x
    }

    /// True if a footprint of `radius` at `p` overlaps no existing footprint.
    private func isFree(_ p: Vec2, radius: Double) -> Bool {
        // Largest footprint we ever use is ~3 tiles; search that neighbourhood.
        let reach = Int((radius + 3).rounded(.up))
        let center = TileCoord(containing: p)
        for dy in -reach...reach {
            for dx in -reach...reach {
                guard let indices = buckets[(center.y + dy) &* 100_003 &+ (center.x + dx)] else { continue }
                for i in indices where objects[i].position.distance(to: p) < radii[i] + radius {
                    return false
                }
            }
        }
        return true
    }

    static func distance(from p: Vec2, toSegment a: Vec2, _ b: Vec2) -> Double {
        let ab = b - a
        let lengthSquared = ab.x * ab.x + ab.y * ab.y
        guard lengthSquared > 0 else { return p.distance(to: a) }
        let ap = p - a
        let t = max(0, min(1, (ap.x * ab.x + ap.y * ab.y) / lengthSquared))
        return p.distance(to: a + ab * t)
    }
}
