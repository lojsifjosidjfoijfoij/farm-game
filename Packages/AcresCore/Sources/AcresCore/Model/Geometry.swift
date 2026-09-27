import Foundation

/// A 2D vector in **tile units** (1.0 = one map tile). y points north (up).
///
/// The core uses its own tiny vector type instead of CGPoint so it stays free
/// of CoreGraphics and compiles everywhere.
public struct Vec2: Codable, Hashable, Sendable, CustomStringConvertible {
    public var x: Double
    public var y: Double

    public init(_ x: Double, _ y: Double) {
        self.x = x
        self.y = y
    }

    public static let zero = Vec2(0, 0)

    public static func + (a: Vec2, b: Vec2) -> Vec2 { Vec2(a.x + b.x, a.y + b.y) }
    public static func - (a: Vec2, b: Vec2) -> Vec2 { Vec2(a.x - b.x, a.y - b.y) }
    public static func * (a: Vec2, s: Double) -> Vec2 { Vec2(a.x * s, a.y * s) }

    public var length: Double { (x * x + y * y).squareRoot() }

    public func distance(to other: Vec2) -> Double { (self - other).length }

    public var description: String { "(\(x), \(y))" }
}

/// Integer tile coordinate. (0, 0) is the south-west corner of the map.
public struct TileCoord: Codable, Hashable, Sendable, CustomStringConvertible {
    public var x: Int
    public var y: Int

    public init(_ x: Int, _ y: Int) {
        self.x = x
        self.y = y
    }

    /// The tile containing a point given in tile units.
    public init(containing point: Vec2) {
        self.init(Int(point.x.rounded(.down)), Int(point.y.rounded(.down)))
    }

    /// Center of the tile in tile units.
    public var center: Vec2 { Vec2(Double(x) + 0.5, Double(y) + 0.5) }

    public var description: String { "[\(x), \(y)]" }
}

/// Axis-aligned rectangle in tile units.
public struct TileRect: Codable, Hashable, Sendable {
    public var minX: Double
    public var minY: Double
    public var maxX: Double
    public var maxY: Double

    public init(minX: Double, minY: Double, maxX: Double, maxY: Double) {
        self.minX = min(minX, maxX)
        self.minY = min(minY, maxY)
        self.maxX = max(minX, maxX)
        self.maxY = max(minY, maxY)
    }

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.init(minX: x, minY: y, maxX: x + width, maxY: y + height)
    }

    public var width: Double { maxX - minX }
    public var height: Double { maxY - minY }
    public var center: Vec2 { Vec2((minX + maxX) / 2, (minY + maxY) / 2) }

    public func contains(_ p: Vec2) -> Bool {
        p.x >= minX && p.x < maxX && p.y >= minY && p.y < maxY
    }

    /// Distance from a point to the rectangle (0 inside).
    public func distance(to p: Vec2) -> Double {
        let dx = max(minX - p.x, 0, p.x - maxX)
        let dy = max(minY - p.y, 0, p.y - maxY)
        return (dx * dx + dy * dy).squareRoot()
    }

    public func intersects(_ other: TileRect) -> Bool {
        minX < other.maxX && other.minX < maxX && minY < other.maxY && other.minY < maxY
    }

    public func insetBy(_ d: Double) -> TileRect {
        TileRect(minX: minX + d, minY: minY + d, maxX: maxX - d, maxY: maxY - d)
    }
}
