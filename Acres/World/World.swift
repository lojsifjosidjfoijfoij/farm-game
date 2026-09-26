import SpriteKit
import AcresCore

/// Conversions between simulation units (tiles) and SpriteKit world points.
enum World {
    /// World points per tile. The camera zoom decides how big that is on screen.
    static let tileSize: CGFloat = 64
    static let chunkSize: CGFloat = CGFloat(WorldMap.chunkSize) * tileSize

    static func point(_ v: Vec2) -> CGPoint {
        CGPoint(x: CGFloat(v.x) * tileSize, y: CGFloat(v.y) * tileSize)
    }

    static func tiles(_ p: CGPoint) -> Vec2 {
        Vec2(Double(p.x / tileSize), Double(p.y / tileSize))
    }

    static func tileRect(_ rect: CGRect) -> TileRect {
        TileRect(minX: Double(rect.minX / tileSize), minY: Double(rect.minY / tileSize),
                 maxX: Double(rect.maxX / tileSize), maxY: Double(rect.maxY / tileSize))
    }

    static func rect(_ tiles: TileRect) -> CGRect {
        CGRect(x: CGFloat(tiles.minX) * tileSize, y: CGFloat(tiles.minY) * tileSize,
               width: CGFloat(tiles.width) * tileSize, height: CGFloat(tiles.height) * tileSize)
    }

    /// Depth for standing objects in the 3/4 view: further north (higher y)
    /// is further away, so it is drawn first.
    static func depth(forY y: CGFloat) -> CGFloat {
        ZLayer.objects - y * 0.001
    }
}

/// Global draw order. With `ignoresSiblingOrder`, SpriteKit sorts by the sum of
/// zPositions up the tree, so these values are absolute.
enum ZLayer {
    static let ground: CGFloat = -1000
    /// Flat things on the ground: shadows, ponds, tile highlights.
    static let flat: CGFloat = -500
    /// Standing objects occupy roughly 100 … 30 (see `World.depth`).
    static let objects: CGFloat = 100
    /// Day/night color grade (child of the camera).
    static let lightingOverlay: CGFloat = 800
    /// Additive night lights, *relative to their owner* (owner ≈ 100 → ≈ 1000, above the grade).
    static let nightLightOffset: CGFloat = 900
    static let debug: CGFloat = 2000
}
