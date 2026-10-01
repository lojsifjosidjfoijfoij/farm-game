import Foundation

/// How much ground map objects occupy, for farming rules.
public enum ObjectFootprint {

    /// Small decorations that plowing simply clears away (weeds, flowers, pebbles).
    public static func isClearable(_ kind: String) -> Bool {
        kind.hasPrefix("nature_grass_tuft") || kind.hasPrefix("nature_flowers") || kind == "nature_rock_small"
    }

    /// Ground covered by an object in tile units, or nil if it blocks nothing.
    /// Standing objects extend *north* of their foot point (away from the camera).
    public static func rect(for object: MapObject) -> TileRect? {
        let p = object.position
        let kind = object.kind
        if isClearable(kind) { return nil }
        // Fences run along tile edges: they frame fields, they don't block them.
        if kind.hasPrefix("prop_fence") { return nil }
        switch kind {
        case "building_farmhouse_t0":
            return TileRect(minX: p.x - 2.3, minY: p.y - 0.2, maxX: p.x + 2.3, maxY: p.y + 3.4)
        case "building_barn_old":
            return TileRect(minX: p.x - 2.0, minY: p.y - 0.2, maxX: p.x + 2.0, maxY: p.y + 2.8)
        case "nature_pond_small":
            return TileRect(minX: p.x - 1.6, minY: p.y - 1.1, maxX: p.x + 1.6, maxY: p.y + 1.1)
        case "nature_lake":
            return TileRect(minX: p.x - 4.6, minY: p.y - 2.4, maxX: p.x + 4.6, maxY: p.y + 2.4)
        case "prop_well":
            return TileRect(minX: p.x - 0.7, minY: p.y - 0.3, maxX: p.x + 0.7, maxY: p.y + 0.8)
        case "prop_log_pile":
            return TileRect(minX: p.x - 0.8, minY: p.y - 0.2, maxX: p.x + 0.8, maxY: p.y + 0.6)
        case let k where k.hasPrefix("building_"):
            // Other buildings: most of the sprite's width, about half its height in depth.
            guard let spec = AssetManifest.spec(named: k) else { break }
            let halfWidth = spec.tilesWide * 0.45
            return TileRect(minX: p.x - halfWidth, minY: p.y - 0.2, maxX: p.x + halfWidth, maxY: p.y + spec.tilesHigh * 0.55)
        default:
            break
        }
        switch kind {
        default:
            // Trees, bushes, rocks, crates, signs: the ground right at their foot.
            return TileRect(minX: p.x - 0.3, minY: p.y - 0.2, maxX: p.x + 0.3, maxY: p.y + 0.3)
        }
    }
}
