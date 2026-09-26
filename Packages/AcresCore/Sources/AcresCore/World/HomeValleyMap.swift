import Foundation

/// The starting area: a run-down farm in a quiet valley.
///
/// Phase 1 contains only the home farm and its surroundings (64 × 64 tiles,
/// 4 × 4 chunks). Phase 3 grows this into the full hand-designed world.
///
/// Layout (x → east, y → north):
/// ```
///  y 64 ┌───────────────── forest ─────────────────┬─┐
///       │                                           │a│
///  y 41 │ ┌─ fence ───────────────────────────────┐ │s│
///       │ │ house  barn                           │ │p│
///       │ │  well  (yard, dirt)   (old field)     │ │h│  For Sale plot →
///  y 28 │ └────── driveway ───────────────────────┘ │a│
///       │ pond        └── gravel road ──────────────┤l│
///       │                meadow                     │t│
///  y  0 └───────────────────────────────────────────┴─┘
///       x 0                                     x 57
/// ```
public enum HomeValleyMap {
    public static let width = 64
    public static let height = 64

    /// Where the truck waits on a new game (tile units).
    public static let truckParkingSpot = Vec2(26.2, 30.2)

    /// A pleasant spot to point the camera at when there is nothing better.
    public static let farmCenter = Vec2(26, 32.5)

    /// The fenced home farm (the land the player owns at the start).
    public static let homeFarmArea = TileRect(minX: 15, minY: 28, maxX: 46, maxY: 41)

    /// The map is deterministic, so it is built once and shared.
    public static let map: WorldMap = build()

    public static func build() -> WorldMap {
        var b = MapBuilder(width: width, height: height, seed: 0xACE5_F4A7)

        // --- Roads -------------------------------------------------------
        // Paved county road along the east side (leads to the village in Phase 3).
        b.paintPath(.asphalt, through: [Vec2(57, -2), Vec2(57.6, 18), Vec2(57.2, 40), Vec2(56.6, 66)], width: 2.8)
        // Gravel road from the farm gate to the county road.
        b.paintPath(.gravel, through: [Vec2(26, 23.4), Vec2(34, 22.2), Vec2(45, 21.6), Vec2(57, 22)], width: 2.3, roughness: 0.25)

        // --- Farmyard ----------------------------------------------------
        b.paintEllipse(.dirt, center: Vec2(24.5, 33.5), radiusX: 7.2, radiusY: 5.2, roughness: 1.2)
        // Driveway from the yard down to the gravel road.
        b.paintPath(.dirt, through: [Vec2(26, 29), Vec2(26.2, 25.5), Vec2(26, 23)], width: 2.2, roughness: 0.3)
        // Footpath to the pond.
        b.paintPath(.dirt, through: [Vec2(18.5, 31.5), Vec2(15.5, 28.8), Vec2(13.8, 26.8)], width: 1.5, roughness: 0.3)
        // The old, overgrown field east of the yard (becomes farmland in Phase 2).
        b.paintEllipse(.dirt, center: Vec2(40, 34.5), radiusX: 5.0, radiusY: 4.0, roughness: 0.8)

        // --- Landmarks (exact placement) ----------------------------------
        b.place("building_farmhouse_t0", at: Vec2(21, 36.2), radius: 2.6)
        b.reserve(TileRect(minX: 18, minY: 35.6, maxX: 24, maxY: 40.5))
        b.place("building_barn_old", at: Vec2(30, 37), radius: 2.8)
        b.reserve(TileRect(minX: 27, minY: 36.4, maxX: 33, maxY: 41.5))

        b.place("prop_well", at: Vec2(16.8, 33.2), radius: 0.9)
        b.place("prop_log_pile", at: Vec2(33.6, 37.4), radius: 0.9)
        b.place("prop_crate", at: Vec2(33.2, 35.9), radius: 0.4)
        b.place("prop_crate", at: Vec2(34.0, 35.5), variant: 1, radius: 0.4)
        b.place("prop_hay_bale", at: Vec2(28.4, 35.2), radius: 0.6)
        b.place("prop_hay_bale", at: Vec2(29.6, 34.9), variant: 1, radius: 0.6)
        b.place("prop_mailbox", at: Vec2(27.7, 23.9), radius: 0.3)
        b.place("prop_sign_for_sale", at: Vec2(49.5, 34.5), radius: 0.5)
        b.place("nature_pond_small", at: Vec2(12.4, 25.2), radius: 2.0)
        b.reserve(TileRect(minX: 10, minY: 23.8, maxX: 14.8, maxY: 26.8))
        // Keep the yard, driveway and truck spot clear of random clutter.
        b.reserve(TileRect(minX: 19, minY: 29, maxX: 32, maxY: 35.5))
        b.reserve(TileRect(minX: 24.5, minY: 22, maxX: 28, maxY: 29))

        placeFence(&b)

        // --- Nature (deterministic scatter) --------------------------------
        let trees = ["tree_oak", "tree_pine", "tree_birch"]
        let forest = TileRect(minX: 0, minY: 44, maxX: 64, maxY: 64)
        // Thinner near the forest edge, with a few clearings.
        let forestDensity: (Vec2) -> Double = { p in
            let edge = min(1, max(0, (p.y - 43) / 5))
            return edge * 0.85
        }
        b.scatter(["tree_pine", "tree_pine", "tree_oak", "tree_birch"], count: 150, in: forest,
                  radius: 0.9, spacing: 1.7, density: forestDensity)
        b.scatter(trees, count: 40, in: TileRect(minX: 0, minY: 0, maxX: 9, maxY: 44), radius: 0.9, spacing: 2)
        b.scatter(["tree_oak", "tree_birch", "tree_oak"], count: 16, in: TileRect(minX: 9, minY: 1, maxX: 54, maxY: 20),
                  radius: 1.0, spacing: 5)
        b.scatter(trees, count: 14, in: TileRect(minX: 60, minY: 0, maxX: 64, maxY: 44), radius: 0.9, spacing: 2)
        b.scatter(["tree_oak", "tree_birch"], count: 6, in: TileRect(minX: 34, minY: 41.5, maxX: 56, maxY: 44),
                  radius: 1.0, spacing: 4)

        b.scatter(["tree_stump"], count: 8, in: TileRect(minX: 2, minY: 41, maxX: 56, maxY: 50), radius: 0.5, spacing: 3)
        b.scatter(["nature_bush_a", "nature_bush_b"], count: 55, in: b.bounds, radius: 0.6, spacing: 1.5)
        b.scatter(["nature_rock_small"], count: 26, in: b.bounds, radius: 0.35, spacing: 2)
        b.scatter(["nature_rock_large"], count: 7, in: b.bounds, radius: 0.8, spacing: 6)
        b.scatter(["nature_flowers_yellow", "nature_flowers_white", "nature_flowers_purple"], count: 90,
                  in: TileRect(minX: 8, minY: 1, maxX: 55, maxY: 27), radius: 0.25, spacing: 0.6)
        b.scatter(["nature_grass_tuft_a", "nature_grass_tuft_b"], count: 220, in: b.bounds, radius: 0.22, spacing: 0.5)
        // The old field is overgrown with weeds and stones.
        b.scatter(["nature_grass_tuft_a", "nature_grass_tuft_b"], count: 26,
                  in: TileRect(minX: 34, minY: 30, maxX: 46, maxY: 39), radius: 0.3, spacing: 0.8, on: [.dirt])
        b.scatter(["nature_rock_small"], count: 6, in: TileRect(minX: 34, minY: 30, maxX: 46, maxY: 39),
                  radius: 0.4, spacing: 2, on: [.dirt])

        return b.build(name: "Home Valley")
    }

    /// An old wooden fence around the home farm, with gaps and broken rails.
    private static func placeFence(_ b: inout MapBuilder) {
        let area = homeFarmArea
        var rng = SeededRandom(seed: 0xFE_7CE)
        let gate = 24.5...27.5  // opening for the driveway

        // South and north sides: horizontal segments, one per tile.
        for side in [area.minY, area.maxY] {
            var x = area.minX
            while x < area.maxX {
                let isGate = side == area.minY && gate.contains(x + 0.5)
                let roll = rng.nextUnit()
                if !isGate && roll > 0.12 {
                    let kind = roll < 0.3 ? "prop_fence_wood_h_broken" : "prop_fence_wood_h"
                    b.place(kind, at: Vec2(x + 0.5, side), radius: 0.3)
                }
                x += 1
            }
        }
        // West and east sides: vertical segments, anchored at their south end.
        for side in [area.minX, area.maxX] {
            var y = area.minY
            while y < area.maxY {
                if rng.nextUnit() > 0.15 {
                    b.place("prop_fence_wood_v", at: Vec2(side, y), radius: 0.3)
                }
                y += 1
            }
        }
        // Corner posts.
        for corner in [Vec2(area.minX, area.minY), Vec2(area.maxX, area.minY),
                       Vec2(area.minX, area.maxY), Vec2(area.maxX, area.maxY)] {
            b.place("prop_fence_wood_post", at: corner, radius: 0.2)
        }
        // Gate posts.
        b.place("prop_fence_wood_post", at: Vec2(gate.lowerBound, area.minY), radius: 0.2)
        b.place("prop_fence_wood_post", at: Vec2(gate.upperBound, area.minY), radius: 0.2)
    }
}

extension MapBuilder {
    /// The whole map as a rectangle.
    public var bounds: TileRect { TileRect(x: 0, y: 0, width: Double(width), height: Double(height)) }
}
