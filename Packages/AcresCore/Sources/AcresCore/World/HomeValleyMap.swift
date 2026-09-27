import Foundation

/// The starting area: a run-down farm in a quiet valley.
///
/// Phase 1 contains only the home farm and its surroundings (64 × 64 tiles,
/// 4 × 4 chunks). Phase 3 grows this into the full hand-designed world.
///
/// Layout (x → east, y → north; 144 × 96 tiles, 9 × 6 chunks):
/// ```
///  y 96 ┌──────────────────────────── forest ────────────────────────────┐
///       │                              │ county road                     │
///  y 41 │ ┌─ fence ────────────┐       │                                 │
///       │ │ house  barn  field │ sale  │         ┌ houses ┐              │
///  y 28 │ └──── driveway ──────┘       │ gas  seeds  market square        │
///       │ pond   └─ gravel road ───────┼─────── village street ──────────►│
///       │               meadow         │         houses                   │
///  y  0 └──────────────────────────────┴──────────────────────────────────┘
///       x 0                           x 57                             x 144
/// ```
public enum HomeValleyMap {
    public static let width = 144
    public static let height = 96

    /// The original Phase 1 area. Its layout is frozen so saved fields never
    /// end up under a new tree: new content is only ever added after it.
    static let homeArea = TileRect(minX: 0, minY: 0, maxX: 64, maxY: 64)

    // --- The village (Phase 3) ---------------------------------------------
    /// Where the truck must stop to use each shop (tile units).
    public static let gasStationZone = TileRect(minX: 61.5, minY: 22.4, maxX: 70.5, maxY: 28.4)
    public static let seedShopZone = TileRect(minX: 76.5, minY: 22.4, maxX: 83.5, maxY: 27.2)
    public static let marketZone = TileRect(minX: 88, minY: 22.4, maxX: 106, maxY: 27.2)
    /// The livestock market at the east end of the village (Phase 4).
    public static let livestockZone = TileRect(minX: 123, minY: 22.4, maxX: 134, maxY: 28.8)

    /// Where the truck waits on a new game (tile units).
    public static let truckParkingSpot = Vec2(26.2, 30.2)

    /// A pleasant spot to point the camera at when there is nothing better.
    public static let farmCenter = Vec2(26, 32.5)

    /// The fenced fields of the home farm. (Since Phase 4 the farm also owns
    /// the backyard with the pens and the woodlot behind it; see `PropertyCatalog`.)
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
        b.scatter(["nature_bush_a", "nature_bush_b"], count: 55, in: homeArea, radius: 0.6, spacing: 1.5)
        b.scatter(["nature_rock_small"], count: 26, in: homeArea, radius: 0.35, spacing: 2)
        b.scatter(["nature_rock_large"], count: 7, in: homeArea, radius: 0.8, spacing: 6)
        b.scatter(["nature_flowers_yellow", "nature_flowers_white", "nature_flowers_purple"], count: 90,
                  in: TileRect(minX: 8, minY: 1, maxX: 55, maxY: 27), radius: 0.25, spacing: 0.6)
        b.scatter(["nature_grass_tuft_a", "nature_grass_tuft_b"], count: 220, in: homeArea, radius: 0.22, spacing: 0.5)
        // The old field is overgrown with weeds and stones.
        b.scatter(["nature_grass_tuft_a", "nature_grass_tuft_b"], count: 26,
                  in: TileRect(minX: 34, minY: 30, maxX: 46, maxY: 39), radius: 0.3, spacing: 0.8, on: [.dirt])
        b.scatter(["nature_rock_small"], count: 6, in: TileRect(minX: 34, minY: 30, maxX: 46, maxY: 39),
                  radius: 0.4, spacing: 2, on: [.dirt])

        // Everything below was added in Phase 3. Append only: never insert above.
        buildVillageAndBeyond(&b)
        // Phase 4.
        buildBackyardAndLivestock(&b)

        return b.build(name: "Home Valley")
    }

    /// The road east, the village with its shops, and the wider countryside.
    private static func buildVillageAndBeyond(_ b: inout MapBuilder) {
        // --- Roads -----------------------------------------------------------
        b.paintPath(.asphalt, through: [Vec2(56.6, 63), Vec2(56.0, 80), Vec2(57, 98)], width: 2.8)
        b.paintPath(.asphalt, through: [Vec2(57.2, 22.3), Vec2(66, 23.2), Vec2(78, 24), Vec2(106, 24),
                                        Vec2(120, 23.4), Vec2(146, 22.6)], width: 2.6)
        // Gas station forecourt, seed shop apron and the market square.
        b.paintRect(.gravel, TileRect(minX: 61.5, minY: 25, maxX: 70.5, maxY: 29))
        b.paintRect(.gravel, TileRect(minX: 77, minY: 25, maxX: 83, maxY: 27.6))
        b.paintRect(.gravel, TileRect(minX: 88, minY: 25, maxX: 106, maxY: 30.6))
        // Garden paths from the houses to the street.
        for x in [72.0, 84, 95, 107, 118] {
            b.paintPath(.dirt, through: [Vec2(x, 18.3), Vec2(x, 22.8)], width: 1.3, roughness: 0.2)
        }
        b.paintPath(.dirt, through: [Vec2(86, 30.6), Vec2(86, 34)], width: 1.3, roughness: 0.2)
        b.paintPath(.dirt, through: [Vec2(106, 29.5), Vec2(112, 29.8)], width: 1.3, roughness: 0.2)

        // Trees and plants that used to stand where the new roads run are cleared.
        b.removeObjects { object, terrain in
            let isNature = object.kind.hasPrefix("tree_") || object.kind.hasPrefix("nature_")
            return isNature && (terrain == .asphalt || terrain == .gravel)
        }

        // --- The village -----------------------------------------------------
        let village = TileRect(minX: 59, minY: 15, maxX: 124, maxY: 36.5)
        b.reserve(village)

        b.place("building_gas_station", at: Vec2(66, 29.2), radius: 3)
        b.place("prop_gas_pump", at: Vec2(64.2, 26.7), radius: 0.4)
        b.place("prop_gas_pump", at: Vec2(67.8, 26.7), variant: 1, radius: 0.4)
        b.place("building_seed_shop", at: Vec2(80, 27.9), radius: 2.5)
        b.place("building_farmers_market_stall", at: Vec2(91.5, 28.4), radius: 1.3)
        b.place("building_farmers_market_stall", at: Vec2(96, 28.6), variant: 1, radius: 1.3)
        b.place("building_farmers_market_stall", at: Vec2(100.5, 28.4), variant: 2, radius: 1.3)
        b.place("prop_market_goods", at: Vec2(103.8, 28), radius: 0.8)

        b.place("building_house_village_a", at: Vec2(72, 18), radius: 2)
        b.place("building_house_village_b", at: Vec2(84, 17.6), radius: 2)
        b.place("building_house_village_c", at: Vec2(95, 18.2), radius: 2)
        b.place("building_house_village_a", at: Vec2(107, 17.8), variant: 1, radius: 2)
        b.place("building_house_village_b", at: Vec2(86, 34.2), variant: 1, radius: 2)
        b.place("building_house_village_c", at: Vec2(114, 29.2), variant: 1, radius: 2)
        b.place("building_house_village_a", at: Vec2(118, 18), variant: 2, radius: 2)

        for x in [74.5, 88.5, 101.5, 113.5] {
            b.place("prop_lamp_post", at: Vec2(x, 21.6), radius: 0.3)
        }
        b.place("prop_lamp_post", at: Vec2(88.6, 30.2), radius: 0.3)
        b.place("prop_lamp_post", at: Vec2(105.4, 30.2), radius: 0.3)
        b.place("prop_bench", at: Vec2(94, 30.2), radius: 0.7)
        b.place("prop_bench", at: Vec2(98.5, 30.2), variant: 1, radius: 0.7)
        b.place("prop_signpost", at: Vec2(59.6, 26.2), radius: 0.4)

        // A little green around the houses.
        b.scatter(["nature_bush_a", "nature_bush_b"], count: 14, in: TileRect(minX: 66, minY: 14, maxX: 122, maxY: 20.5),
                  radius: 0.6, spacing: 2.5)
        b.scatter(["nature_flowers_yellow", "nature_flowers_white", "nature_flowers_purple"], count: 40,
                  in: TileRect(minX: 66, minY: 14, maxX: 122, maxY: 21.5), radius: 0.25, spacing: 0.8)

        // --- Countryside -----------------------------------------------------
        let trees = ["tree_oak", "tree_pine", "tree_birch"]
        b.scatter(["tree_pine", "tree_pine", "tree_oak", "tree_birch"], count: 300,
                  in: TileRect(minX: 0, minY: 64, maxX: 144, maxY: 96), radius: 0.9, spacing: 1.8,
                  density: { p in p.x > 53 && p.x < 60 ? 0 : 0.85 })
        b.scatter(trees, count: 90, in: TileRect(minX: 64, minY: 42, maxX: 144, maxY: 64), radius: 0.9, spacing: 2.2)
        b.scatter(["tree_oak", "tree_birch", "tree_oak"], count: 40, in: TileRect(minX: 64, minY: 0, maxX: 144, maxY: 42),
                  radius: 1.0, spacing: 4.5)
        b.scatter(["tree_stump"], count: 10, in: TileRect(minX: 64, minY: 36, maxX: 144, maxY: 70), radius: 0.5, spacing: 3)
        b.scatter(["nature_bush_a", "nature_bush_b"], count: 90, in: TileRect(minX: 0, minY: 0, maxX: 144, maxY: 96),
                  radius: 0.6, spacing: 1.5, density: { p in homeArea.contains(p) ? 0 : 1 })
        b.scatter(["nature_rock_small"], count: 40, in: TileRect(minX: 64, minY: 0, maxX: 144, maxY: 96), radius: 0.35, spacing: 2)
        b.scatter(["nature_rock_large"], count: 10, in: TileRect(minX: 64, minY: 0, maxX: 144, maxY: 96), radius: 0.8, spacing: 6)
        b.scatter(["nature_flowers_yellow", "nature_flowers_white", "nature_flowers_purple"], count: 160,
                  in: TileRect(minX: 64, minY: 0, maxX: 144, maxY: 42), radius: 0.25, spacing: 0.6)
        b.scatter(["nature_grass_tuft_a", "nature_grass_tuft_b"], count: 420, in: TileRect(minX: 0, minY: 0, maxX: 144, maxY: 96),
                  radius: 0.22, spacing: 0.5, density: { p in homeArea.contains(p) ? 0 : 1 })
    }

    /// The pens behind the farmhouse and the livestock market (Phase 4).
    private static func buildBackyardAndLivestock(_ b: inout MapBuilder) {
        // --- Pens -------------------------------------------------------------
        // Their fences, troughs and huts are drawn from game state (run-down
        // until repaired); the map keeps the ground clear and solid.
        for pen in PenCatalog.all {
            let clear = pen.footprint.insetBy(-0.9)
            b.removeObjects { object, _ in
                (object.kind.hasPrefix("tree_") || object.kind.hasPrefix("nature_")) && clear.contains(object.position)
            }
            b.addSolidArea(pen.footprint)
        }
        // Scratched-bare chicken yard and a muddy pigsty.
        if let coop = PenCatalog.pen("coop") { b.paintRect(.dirt, coop.area.insetBy(0.4)) }
        if let sty = PenCatalog.pen("pigsty") { b.paintRect(.dirt, sty.area.insetBy(0.2)) }
        // A worn path from the field gate up between the pens to the woodlot.
        b.paintPath(.dirt, through: [Vec2(22, 41.2), Vec2(24, 43), Vec2(24, 49.8), Vec2(27, 51)], width: 1.2, roughness: 0.3)
        b.removeObjects { object, terrain in
            object.kind.hasPrefix("tree_") && terrain == .dirt && TileRect(minX: 21, minY: 41, maxX: 28, maxY: 52).contains(object.position)
        }

        // --- Livestock market -----------------------------------------------------
        let yard = TileRect(minX: 122.5, minY: 24.4, maxX: 134.5, maxY: 29.2)
        let grounds = TileRect(minX: 121, minY: 23, maxX: 142, maxY: 35)
        b.removeObjects { object, _ in
            (object.kind.hasPrefix("tree_") || object.kind.hasPrefix("nature_bush") || object.kind.hasPrefix("nature_rock"))
                && grounds.contains(object.position)
        }
        b.reserve(grounds)
        b.paintRect(.gravel, yard)
        b.place("building_livestock_market", at: Vec2(128.5, 30), radius: 3.4)
        b.place("prop_hay_bale", at: Vec2(124, 29.9), variant: 2, radius: 0.6)
        b.place("prop_feeder", at: Vec2(133.4, 29.8), radius: 0.6)
        b.place("prop_lamp_post", at: Vec2(122.8, 29.6), radius: 0.3)
        // A small corral with a few animals for sale.
        for x in stride(from: 135.5, through: 139.5, by: 1) {
            b.place("prop_fence_wood_h", at: Vec2(x, 25), radius: 0.2)
            b.place("prop_fence_wood_h", at: Vec2(x, 30), radius: 0.2)
        }
        for y in stride(from: 25.0, through: 29, by: 1) {
            b.place("prop_fence_wood_v", at: Vec2(135, y), radius: 0.2)
            b.place("prop_fence_wood_v", at: Vec2(140, y), radius: 0.2)
        }
        b.place("animal_sheep_idle", at: Vec2(136.8, 28.2), radius: 0.5)
        b.place("animal_lamb_eat", at: Vec2(138.4, 27.4), radius: 0.4)
        b.place("animal_cow_idle", at: Vec2(137.6, 25.9), variant: 1, radius: 0.8)
        b.place("animal_piglet_idle", at: Vec2(139, 26.6), radius: 0.3)
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
