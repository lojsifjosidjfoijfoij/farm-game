import Foundation

/// Every visual asset the game needs, across all phases.
///
/// This list is the single source of truth for art: the app sizes sprites
/// from it, the placeholder painter draws from it, and `docs/ASSETS.md` is
/// generated from it (`swift run acres-tools assets`).
///
/// Adding content (a crop, a tree, a building) = add its entries here.
public enum AssetManifest {

    public static let all: [AssetSpec] =
        terrain + fields + crops + trees + nature + buildings + props + workshops + vehicles + characters + animals + items + effects + ui

    /// Workshops standing on the farm (after Phase 9).
    static let workshops: [AssetSpec] = WorkshopCatalog.all.map { workshop in
        .sprite(workshop.prop, .prop, tiles: 1.1, 1.4, anchorY: 0.1, shadow: 0.9, phase: 10,
                "\(workshop.name) standing on the farm: \(workshop.blurb.lowercased())")
    }

    private static let index: [String: AssetSpec] = {
        var result: [String: AssetSpec] = [:]
        for spec in all { result[spec.name] = spec }
        return result
    }()

    public static func spec(named name: String) -> AssetSpec? { index[name] }

    /// The asset to draw for a map object kind, preferring a seasonal variant
    /// (`tree_oak` → `tree_oak_summer`) and falling back to the plain name.
    public static func assetName(forObjectKind kind: String, season: Season) -> String? {
        let seasonal = "\(kind)_\(season.name.lowercased())"
        if index[seasonal] != nil { return seasonal }
        if index[kind] != nil { return kind }
        return nil
    }

    // MARK: - Shared content lists (temporary until the content catalogs arrive in later phases)

    public static var cropNames: [String] { CropCatalog.all.map(\.id) }
    public static let seasonalTreeSpecies = ["oak", "birch", "pine", "maple", "apple", "cherry"]

    private static func capitalizedFirst(_ text: String) -> String {
        text.prefix(1).uppercased() + text.dropFirst()
    }

    // MARK: - Terrain

    static let terrain: [AssetSpec] = [
        .tileable("terrain_grass", tiles: 16, pixels: 2048, phase: 1,
                  "Summer meadow grass seen from above, pixel art: tufts, clover, leafy weeds, scattered tiny flowers and a few daisy patches; sunny and shady patches in flat steps. One chunk (16 × 16 tiles), so it doesn't visibly repeat. Seamless."),
        .tileable("terrain_grass_spring", tiles: 4, pixels: 512, phase: 7,
                  "Spring grass: fresher yellow-green, a few tiny white/yellow flower specks. Seamless."),
        .tileable("terrain_grass_autumn", tiles: 4, pixels: 512, phase: 7,
                  "Autumn grass: olive and ochre, a few fallen leaves. Seamless."),
        .tileable("terrain_snow", tiles: 4, pixels: 512, phase: 7,
                  "Winter snow cover: soft blue-white with gentle drifts and sparkle. Seamless."),
        .tileable("terrain_dirt", tiles: 16, pixels: 2048, phase: 1,
                  "Packed farmyard earth, pixel art: warm tan speckle, small pebbles, a few damper patches. Seamless."),
        .tileable("terrain_gravel", tiles: 16, pixels: 2048, phase: 1,
                  "Country gravel road: beige-grey stones on dusty ground. Seamless."),
        .tileable("terrain_asphalt", tiles: 16, pixels: 2048, phase: 1,
                  "Old county asphalt: dark warm grey, fine grain, a few hairline cracks. No markings. Seamless."),
        .tileable("terrain_sand", tiles: 4, pixels: 512, phase: 3,
                  "Lake and harbor sand: pale warm beige, ripples. Seamless."),
        .tileable("terrain_water", tiles: 4, pixels: 512, phase: 3,
                  "Calm lake water: muted blue-green, soft painted highlights. Seamless."),
        .tileable("terrain_variation", tiles: 16, pixels: 256, phase: 1,
                  "Technical texture, not visible art: red = large soft blotches, green = medium noise, both greyscale and seamless. Breaks up visible tiling."),
        .sprite("terrain_road_marking", .terrain, tiles: 1, 0.25, layer: .flat, phase: 3,
                "Faded dashed centre line segment for asphalt roads."),
    ]

    // MARK: - Fields

    static let fields: [AssetSpec] = [
        // Soil is pixel art from art/terrain/make_soil.py: three pictures of each,
        // picked by position, so a field isn't one repeated tile.
        .sprite("field_soil_plowed", .field, tiles: 1, 1, layer: .flat, phase: 2,
                "One tile of plowed soil, pixel art: four furrows running left-right (lit crest, ridge, dark trough) that join into rows across tiles, clods, pebbles, bits of straw."),
        .sprite("field_soil_plowed_2", .field, tiles: 1, 1, layer: .flat, phase: 2, "Plowed soil, a second picture."),
        .sprite("field_soil_plowed_3", .field, tiles: 1, 1, layer: .flat, phase: 2, "Plowed soil, a third picture."),
        .sprite("field_soil_watered", .field, tiles: 1, 1, layer: .flat, phase: 2,
                "The same tile wet: darker and cooler, with glints on the crests (same layout, so a plot only darkens)."),
        .sprite("field_soil_watered_2", .field, tiles: 1, 1, layer: .flat, phase: 2, "Wet soil, the second picture."),
        .sprite("field_soil_watered_3", .field, tiles: 1, 1, layer: .flat, phase: 2, "Wet soil, the third picture."),
        .sprite("field_soil_fertilized", .field, tiles: 1, 1, layer: .flat, phase: 7,
                "Plowed soil with pale specks of fertilizer."),
        .sprite("field_soil_fertilized_2", .field, tiles: 1, 1, layer: .flat, phase: 7, "Fertilized soil, the second picture."),
        .sprite("field_soil_fertilized_3", .field, tiles: 1, 1, layer: .flat, phase: 7, "Fertilized soil, the third picture."),
        .sprite("field_edge_n", .field, tiles: 1, 1, layer: .flat, phase: 2,
                "Laid over a plot with no plot to the north: grass creeping over the soil's border, a dark lip, upright tufts. Transparent elsewhere."),
        .sprite("field_edge_e", .field, tiles: 1, 1, layer: .flat, phase: 2, "The same, on the east side."),
        .sprite("field_edge_s", .field, tiles: 1, 1, layer: .flat, phase: 2, "The same, on the south side."),
        .sprite("field_edge_w", .field, tiles: 1, 1, layer: .flat, phase: 2, "The same, on the west side."),
        .sprite("field_weeds", .field, tiles: 1, 1.1, anchorY: 0.1, phase: 2,
                "Overgrown weeds and dry grass covering a tile that must be cleared."),
    ]

    // MARK: - Crops

    static let crops: [AssetSpec] = CropCatalog.all.flatMap { crop -> [AssetSpec] in
        let tall = crop.id == "corn" || crop.id == "sunflower"
        return crop.stageNotes.enumerated().map { stage, text in
            .sprite("crop_\(crop.id)_stage\(stage)", .crop, tiles: 1, tall ? 2 : 1.25, anchorY: 0.1,
                    phase: 2, family: "crop_\(crop.id)",
                    "\(crop.name), stage \(stage) of 4: \(text). One tile of plants standing on the soil tile.")
        }
    }

    // MARK: - Trees

    static let trees: [AssetSpec] = {
        var result: [AssetSpec] = []
        let sizes: [String: (Double, Double)] = [
            "oak": (3, 4), "birch": (2, 3.5), "pine": (2, 4), "maple": (3, 4), "apple": (2.5, 3), "cherry": (2.5, 3),
        ]
        let looks: [String: String] = [
            "oak": "broad round oak, thick trunk, layered canopy",
            "birch": "slender birch, white bark with dark marks, airy canopy",
            "pine": "tall pine, stacked soft-edged tiers",
            "maple": "rare maple (forest plot), elegant spreading crown",
            "apple": "small apple tree, rounded crown",
            "cherry": "small cherry tree, graceful crown",
        ]
        let seasonText: [Season: String] = [
            .spring: "spring: fresh light green (fruit trees in blossom)",
            .summer: "summer: rich deep green",
            .autumn: "autumn: orange, red and gold (pine stays green)",
            .winter: "winter: bare branches with snow (pine: snow-dusted)",
        ]
        for species in seasonalTreeSpecies {
            let (w, h) = sizes[species]!
            let phase = ["oak", "birch", "pine"].contains(species) ? 1 : (species == "maple" ? 6 : 4)
            for season in Season.allCases {
                let seasonPhase = season == .summer ? phase : max(phase, 7)
                result.append(.sprite(
                    "tree_\(species)_\(season.name.lowercased())", .tree, tiles: w, h, anchorY: 0.06,
                    shadow: w * 0.7, phase: seasonPhase, family: "tree_\(species)",
                    "\(capitalizedFirst(looks[species]!)), \(seasonText[season]!)."))
            }
            result.append(.sprite("tree_\(species)_sapling", .tree, tiles: 0.8, 1.1, anchorY: 0.08, shadow: 0.5,
                                  phase: 4, family: "tree_\(species)_growth",
                                  "Freshly planted \(species) sapling with a small stake."))
            result.append(.sprite("tree_\(species)_young", .tree, tiles: w * 0.6, h * 0.6, anchorY: 0.07, shadow: w * 0.45,
                                  phase: 4, family: "tree_\(species)_growth",
                                  "Half-grown \(species), summer look."))
        }
        result.append(.sprite("tree_apple_fruit", .tree, tiles: 2.5, 3, anchorY: 0.06, phase: 4,
                              "Overlay: red apples only, aligned to tree_apple_*, shown when fruit is ready."))
        result.append(.sprite("tree_cherry_fruit", .tree, tiles: 2.5, 3, anchorY: 0.06, phase: 4,
                              "Overlay: dark red cherries only, aligned to tree_cherry_*."))
        result.append(.sprite("tree_stump", .tree, tiles: 1, 0.8, anchorY: 0.2, shadow: 0.8, phase: 1,
                              "Cut tree stump with visible rings, a little moss."))
        result.append(.sprite("tree_felled", .tree, tiles: 3, 1.2, anchorY: 0.25, shadow: 2.5, phase: 4,
                              "A tree lying on the ground just after being chopped."))
        return result
    }()

    // MARK: - Nature

    static let nature: [AssetSpec] = [
        .sprite("nature_bush_a", .nature, tiles: 1.2, 1.0, anchorY: 0.1, shadow: 1.0, phase: 1, "Round leafy bush."),
        .sprite("nature_bush_b", .nature, tiles: 1.3, 0.9, anchorY: 0.1, shadow: 1.1, phase: 1, "Low wide bush, slightly darker."),
        .sprite("nature_rock_small", .nature, tiles: 0.8, 0.6, anchorY: 0.15, shadow: 0.7, phase: 1, "Small grey field stone."),
        .sprite("nature_rock_large", .nature, tiles: 1.6, 1.2, anchorY: 0.12, shadow: 1.5, phase: 1, "Large mossy boulder."),
        .sprite("nature_grass_tuft_a", .nature, tiles: 0.6, 0.5, anchorY: 0.1, phase: 1, "Tuft of taller grass (sways)."),
        .sprite("nature_grass_tuft_b", .nature, tiles: 0.7, 0.5, anchorY: 0.1, phase: 1, "Tuft of grass with a seed head."),
        .sprite("nature_flowers_yellow", .nature, tiles: 0.6, 0.5, anchorY: 0.1, phase: 1, "Cluster of small yellow wildflowers."),
        .sprite("nature_flowers_white", .nature, tiles: 0.6, 0.5, anchorY: 0.1, phase: 1, "Cluster of white daisies."),
        .sprite("nature_flowers_purple", .nature, tiles: 0.6, 0.5, anchorY: 0.1, phase: 1, "Cluster of purple wildflowers."),
        .sprite("nature_pond_small", .nature, tiles: 3.4, 2.4, layer: .flat, anchorY: 0.5, phase: 1,
                "Small farm pond seen from above with soft muddy banks and a few reeds; flat."),
        .sprite("nature_reeds", .nature, tiles: 1, 1.2, anchorY: 0.1, phase: 3, "Clump of reeds for lake shores."),
        .sprite("nature_lily_pads", .nature, tiles: 1, 0.6, layer: .flat, anchorY: 0.5, phase: 3, "Lily pads floating on water."),
        .sprite("nature_lake", .nature, tiles: 10.4, 5.8, layer: .flat, anchorY: 0.5, phase: 11,
                "Willow Lake seen from above: a big rounded lake with sandy and grassy banks and darker deep water; flat."),
        .sprite("nature_mushrooms", .nature, tiles: 0.5, 0.4, anchorY: 0.1, phase: 3, "Small cluster of forest mushrooms."),
        .sprite("nature_log_fallen", .nature, tiles: 2.5, 0.9, anchorY: 0.2, shadow: 2.2, phase: 3, "Old mossy fallen log in the forest."),
    ]

    // MARK: - Buildings

    static let buildings: [AssetSpec] = {
        func building(_ name: String, _ w: Double, _ h: Double, phase: Int, lights: Bool = false, _ notes: String) -> [AssetSpec] {
            var result = [AssetSpec.sprite(name, .building, tiles: w, h, anchorY: 0.06, shadow: w * 0.95, phase: phase, notes)]
            if lights {
                result.append(.sprite("\(name)_lights", .building, tiles: w, h, layer: .light, anchorY: 0.06, phase: phase,
                                      "Night overlay for \(name): only the warm glow of lit windows on transparent background, pixel-aligned with the building."))
            }
            return result
        }
        var result: [AssetSpec] = []
        result += building("building_farmhouse_t0", 5, 5, phase: 1, lights: true,
                           "The starting farmhouse: small run-down wooden house, faded paint, patched roof, one boarded window, sagging porch.")
        // Renovations as the farm climbs the ranks (Phase 12): same footprint as the starter house.
        result += building("building_farmhouse_t1", 5, 5, phase: 12, lights: true, "Repaired cozy cottage: new roof, fresh paint, flower boxes.")
        result += building("building_farmhouse_t2", 5, 5, phase: 12, lights: true, "Farmhouse with a porch, shutters and a dormer window.")
        result += building("building_farmhouse_t3", 5, 5, phase: 12, lights: true,
                           "Grand farmhouse: green roof, two dormers, a golden weathervane, lanterns and flower beds.")
        result += building("building_barn_old", 5, 5.5, phase: 1, "Old weathered red barn: gambrel roof with white trim, faded paint, a hayloft door and a small window. Restorable.")
        result += building("building_barn", 5, 5.5, phase: 4, lights: true, "Restored red barn (cows, sheep, goats).")
        result += building("building_coop", 3, 3, phase: 4, "Chicken coop with a little ramp.")
        result += building("building_pigsty", 3, 2.5, phase: 4, "Pigsty: low shed with a muddy yard.")
        result += building("building_sheep_shelter", 3, 2.5, phase: 4, "Open-fronted sheep shelter with a sloped roof and straw inside.")
        result += building("building_goat_shed", 3, 2.5, phase: 11, "Small open goat shed with a red roof and a hay rack.")
        result += building("building_beehives", 2, 1.6, phase: 7, "Row of three painted beehives.")
        result += building("building_stable", 4, 4, phase: 7, "Horse stable with half doors.")
        result += building("building_storage_shed", 3, 3, phase: 2, "Wooden storage shed for harvested goods.")
        result += building("building_silo", 2, 4.5, phase: 6, "Metal grain silo with a conical roof.")
        result += building("building_greenhouse", 5, 4, phase: 6, lights: true, "Glass greenhouse with visible plants inside.")
        result += building("building_garage", 4, 3.5, phase: 6, "Farm garage for bigger vehicles and trailers.")
        result += building("building_mill", 3, 5, phase: 6, "Small wooden windmill (wheat to flour).")
        result += building("building_dairy", 3, 3, phase: 6, "Dairy hut (milk to cheese), white walls.")
        result += building("building_sawmill", 4, 3, phase: 6, "Open-sided sawmill with a big blade (logs to planks).")
        result += building("building_juice_press", 2.5, 2.5, phase: 6, "Wooden juice press shed with barrels.")
        // The wider world.
        result += building("building_seed_shop", 5, 4.5, phase: 3, lights: true, "Village seed shop: green awning, seed racks outside.")
        result += building("building_gas_station", 6, 4, phase: 3, lights: true, "Small old gas station with a canopy.")
        result += building("building_house_village_a", 4, 4.5, phase: 3, lights: true, "Village house, cream walls, red roof.")
        result += building("building_house_village_b", 4, 4.5, phase: 3, lights: true, "Village house, blue shutters, grey roof.")
        result += building("building_house_village_c", 4, 4.5, phase: 3, lights: true, "Village cottage with climbing roses.")
        result += building("building_livestock_market", 7, 5, phase: 4, "Livestock market: a big open barn with a sign, pens and an auction shed.")
        result += building("building_hardware_store", 5, 4.5, phase: 5, lights: true, "Hardware store with tools displayed outside.")
        result += building("building_farmers_market_stall", 2.5, 2.5, phase: 3, "Farmers' market stall with striped awning.")
        result += building("building_restaurant", 5, 4.5, phase: 6, lights: true, "The Rusty Spoon: a cheerful diner (contract client).")
        result += building("building_bakery", 4, 4.5, phase: 6, lights: true, "Hansen's Bakery: warm brick bakery with a bread sign (contract client).")
        result += building("building_bank", 4, 4.5, phase: 6, lights: true, "Valley Savings Bank: small stone bank with columns.")
        result += building("building_wholesale_depot", 8, 6, phase: 5, lights: true, "Harbor wholesale depot: big warehouse with loading doors.")
        result += building("building_harbor_warehouse", 7, 5, phase: 5, "Old brick harbor warehouse.")
        result += building("building_lumber_yard", 6, 5, phase: 6, "North Woods Lumber: yard office with stacked timber (contract client).")
        result += building("building_town_shop", 4, 4.5, phase: 6, lights: true, "Player-owned shop in town (sell your own goods).")
        result += building("building_deli", 4, 4.5, phase: 10, lights: true, "Valley Deli: striped awning, cheeses and jars in the window (client).")
        result += building("building_cabin_lakeside", 4, 4, phase: 6, lights: true, "Lakeside log cabin with a small jetty.")
        result += building("building_farm_abandoned", 6, 6, phase: 6, "The old abandoned farmhouse, overgrown; a long-term restoration goal.")
        result += building("building_lighthouse", 2, 6, phase: 8, lights: true, "Harbor lighthouse, white with a red band.")
        return result
    }()

    // MARK: - Props

    static let props: [AssetSpec] = [
        .sprite("prop_fence_wood_h", .prop, tiles: 1.05, 0.9, anchorY: 0.12, phase: 1,
                "One tile of weathered wooden fence running left-right: two rails and a post on the left end."),
        .sprite("prop_fence_wood_h_broken", .prop, tiles: 1.05, 0.9, anchorY: 0.12, phase: 1,
                "Same fence with a broken, hanging rail."),
        .sprite("prop_fence_wood_v", .prop, tiles: 0.35, 1.9, anchorY: 0.03, phase: 1,
                "One tile of the same fence running away from the camera (north-south), seen in 3/4 view."),
        .sprite("prop_fence_wood_post", .prop, tiles: 0.3, 0.95, anchorY: 0.08, phase: 1, "Single fence post."),
        .sprite("prop_fence_new_h", .prop, tiles: 1.05, 0.9, anchorY: 0.12, phase: 6, "Repaired white-painted fence, left-right."),
        .sprite("prop_fence_new_v", .prop, tiles: 0.35, 1.9, anchorY: 0.03, phase: 6, "Repaired white-painted fence, north-south."),
        .sprite("prop_well", .prop, tiles: 1.6, 2.0, anchorY: 0.1, shadow: 1.4, phase: 1, "Old stone well with a little wooden roof and bucket."),
        .sprite("prop_mailbox", .prop, tiles: 0.5, 1.1, anchorY: 0.05, shadow: 0.4, phase: 1, "Rusty farm mailbox on a post."),
        .sprite("prop_log_pile", .prop, tiles: 1.6, 1.1, anchorY: 0.12, shadow: 1.5, phase: 1, "Neat pile of split firewood logs."),
        .sprite("prop_crate", .prop, tiles: 0.7, 0.8, anchorY: 0.12, shadow: 0.7, phase: 1, "Wooden crate."),
        .sprite("prop_hay_bale", .prop, tiles: 1.1, 0.9, anchorY: 0.12, shadow: 1.1, phase: 1, "Rectangular hay bale."),
        .sprite("prop_sign_for_sale", .prop, tiles: 0.9, 1.3, anchorY: 0.05, shadow: 0.5, phase: 1, "Hand-painted 'For Sale' sign on a stake."),
        .sprite("prop_sign_sold", .prop, tiles: 0.9, 1.3, anchorY: 0.05, shadow: 0.5, phase: 6, "The same sign with a 'Sold' banner."),
        .sprite("prop_scarecrow", .prop, tiles: 1, 1.7, anchorY: 0.05, shadow: 0.6, phase: 2, "Friendly scarecrow with a straw hat."),
        .sprite("prop_sprinkler", .prop, tiles: 0.6, 0.6, anchorY: 0.2, phase: 5, "Brass field sprinkler head."),
        .sprite("prop_sprinkler_pro", .prop, tiles: 0.8, 0.9, anchorY: 0.15, phase: 8, "Big rotating sprinkler on a green stand."),
        .sprite("prop_water_trough", .prop, tiles: 1.5, 0.8, anchorY: 0.15, shadow: 1.4, phase: 4, "Animal water trough, full of fresh water."),
        .sprite("prop_water_trough_empty", .prop, tiles: 1.5, 0.8, anchorY: 0.15, shadow: 1.4, phase: 4, "The same trough, empty and dry."),
        .sprite("prop_sign_repair", .prop, tiles: 0.9, 1.3, anchorY: 0.05, shadow: 0.5, phase: 4,
                "Little wooden sign with a hammer on it: this pen can be repaired."),
        .sprite("prop_feeder", .prop, tiles: 1.2, 0.8, anchorY: 0.15, shadow: 1.1, phase: 4, "Wooden animal feeder with hay."),
        .sprite("prop_notice_board", .prop, tiles: 1.5, 1.8, anchorY: 0.05, shadow: 1.2, phase: 5, "Village notice board with pinned papers (contracts)."),
        .sprite("prop_lamp_post", .prop, tiles: 0.5, 2.5, anchorY: 0.03, shadow: 0.4, phase: 3, "Old iron street lamp."),
        .sprite("prop_lamp_post_lights", .prop, tiles: 0.5, 2.5, layer: .light, anchorY: 0.03, phase: 3, "Glow of the street lamp, aligned with prop_lamp_post."),
        .sprite("prop_bench", .prop, tiles: 1.5, 1, anchorY: 0.1, shadow: 1.3, phase: 3, "Wooden park bench (viewpoint)."),
        .sprite("prop_signpost", .prop, tiles: 0.8, 1.8, anchorY: 0.04, shadow: 0.5, phase: 3, "Wooden signpost with arrows."),
        .sprite("prop_for_rent_sign", .prop, tiles: 1, 1.3, anchorY: 0.05, shadow: 0.6, phase: 7, "Little wooden \"FOR RENT\" board on a post (the corner shop, before it's rented)."),
        .sprite("prop_open_sign", .prop, tiles: 0.9, 1.1, anchorY: 0.05, shadow: 0.6, phase: 7, "Chalkboard A-frame sign saying \"OPEN\" with a drawn carrot (your shop)."),
        .sprite("prop_gas_pump", .prop, tiles: 0.8, 1.6, anchorY: 0.05, shadow: 0.7, phase: 3, "Vintage gas pump."),
        .sprite("prop_market_goods", .prop, tiles: 1.5, 1, anchorY: 0.1, shadow: 1.3, phase: 3, "Baskets and crates of produce for the market square."),
        .sprite("prop_pier", .prop, tiles: 2, 6, layer: .flat, anchorY: 0.5, phase: 3, "Wooden fishing pier seen from above."),
        .sprite("prop_rowboat", .prop, tiles: 2, 1, layer: .flat, anchorY: 0.5, phase: 3, "Small wooden rowboat on water."),
        .sprite("prop_bridge_wood", .prop, tiles: 3, 4, layer: .flat, anchorY: 0.5, phase: 3, "Wooden road bridge over a stream, seen from above."),
        .sprite("prop_merchant_wagon", .prop, tiles: 3, 2.5, anchorY: 0.08, shadow: 2.6, phase: 5, "The traveling merchant's colorful covered wagon."),
    ]

    // MARK: - Vehicles

    static let vehicles: [AssetSpec] = {
        var result: [AssetSpec] = []
        func directional(_ base: String, _ tiles: Double, phase: Int, _ notes: String) {
            for dir in 0..<16 {
                let degrees = dir * 360 / 16
                result.append(.sprite(
                    "\(base)_dir\(dir < 10 ? "0" : "")\(dir)", .vehicle, tiles: tiles, tiles, anchorY: 0.4,
                    shadow: tiles * 0.8, phase: (base == "vehicle_truck_old" && dir == 8) ? 1 : phase, family: base,
                    "\(notes) Facing \(degrees)° (0° = east/right, counter-clockwise; 90° = away from camera)."))
            }
        }
        directional("vehicle_truck_old", 2.5, phase: 3, "The player's beat-up pickup truck: faded teal paint, rust spots, open cargo bed, 3/4 view.")
        directional("vehicle_truck_old_load1", 2.5, phase: 3,
                    "Overlay: a few crates and sacks in the truck bed only (transparent elsewhere), aligned with vehicle_truck_old.")
        directional("vehicle_truck_old_load2", 2.5, phase: 3,
                    "Overlay: a fully loaded truck bed, crates stacked high, aligned with vehicle_truck_old.")
        directional("vehicle_trailer", 2.2, phase: 6, "Small flatbed trailer that hitches to the truck.")
        directional("vehicle_truck_big", 3.2, phase: 7, "Bigger farm truck with a large bed, upgrade.")
        directional("vehicle_car_npc_a", 2.3, phase: 8, "Villager's small hatchback, red.")
        directional("vehicle_car_npc_b", 2.3, phase: 8, "Villager's station wagon, beige.")
        result += [
            .sprite("vehicle_cargo_crate", .vehicle, tiles: 0.4, 0.4, anchorY: 0.2, phase: 3, "Small crate shown in the truck bed."),
            .sprite("vehicle_cargo_sack", .vehicle, tiles: 0.4, 0.35, anchorY: 0.2, phase: 3, "Burlap sack shown in the truck bed."),
            .sprite("vehicle_cargo_logs", .vehicle, tiles: 0.8, 0.4, anchorY: 0.2, phase: 4, "Bundle of logs shown in the truck bed."),
            .sprite("vehicle_cargo_milk_can", .vehicle, tiles: 0.3, 0.4, anchorY: 0.2, phase: 4, "Milk can shown in the truck bed."),
        ]
        return result
    }()

    // MARK: - Characters

    /// The farmer: three facings (side faces left; mirrored in code), walking,
    /// and working with a tool.
    public static let farmerFacings = ["down", "up", "side"]
    public static let farmerPoses = ["idle", "walk1", "walk2", "hoe1", "hoe2", "can1", "can2", "hands1", "hands2", "axe1", "axe2",
                                     "rod1", "rod2"]

    static let characters: [AssetSpec] = {
        var result: [AssetSpec] = []
        let facingText = ["down": "facing the camera", "up": "seen from behind", "side": "facing left (mirrored for right)"]
        let poseText = [
            "idle": "standing relaxed", "walk1": "walking, left foot forward", "walk2": "walking, right foot forward",
            "hoe1": "raising a hoe", "hoe2": "striking the ground with a hoe",
            "can1": "tilting a watering can", "can2": "pouring from a watering can",
            "hands1": "bending down to the ground", "hands2": "picking something up / sowing",
            "axe1": "raising an axe", "axe2": "swinging an axe",
            "rod1": "holding a fishing rod out, waiting for a bite", "rod2": "pulling up a bent fishing rod",
        ]
        for facing in farmerFacings {
            for pose in farmerPoses {
                result.append(.sprite("character_farmer_\(facing)_\(pose)", .character, tiles: 0.9, 1.5, anchorY: 0.05,
                                      shadow: 0.6, phase: 5, family: "character_farmer",
                                      "The farmer: friendly young farmer in a straw hat, checked shirt, blue overalls and boots, \(facingText[facing]!), \(poseText[pose]!)."))
            }
        }
        // Farmhands (Phase 8): walking, watering and picking.
        for (index, look) in workerLooks.enumerated() {
            for facing in farmerFacings {
                for pose in workerPoses {
                    result.append(.sprite("character_worker\(index + 1)_\(facing)_\(pose)", .character, tiles: 0.9, 1.5, anchorY: 0.05,
                                          shadow: 0.6, phase: 8, family: "character_worker\(index + 1)",
                                          "Farmhand: \(look), \(facingText[facing]!), \(poseText[pose]!)."))
                }
            }
        }
        // Villagers who shop at your store (Phase 7): walking only.
        for (index, look) in villagerLooks.enumerated() {
            for facing in farmerFacings {
                for pose in villagerPoses {
                    result.append(.sprite("character_villager\(index + 1)_\(facing)_\(pose)", .character, tiles: 0.9, 1.5, anchorY: 0.05,
                                          shadow: 0.6, phase: 7, family: "character_villager\(index + 1)",
                                          "Villager: \(look), \(facingText[facing]!), \(poseText[pose]!)."))
                }
            }
        }
        return result
    }()

    public static let villagerPoses = ["idle", "walk1", "walk2"]
    /// Farmhands walk, water and pick (Phase 8).
    public static let workerPoses = ["idle", "walk1", "walk2", "can1", "can2", "hands1", "hands2"]
    static let workerLooks = [
        "farmhand in a green cap, red shirt and brown dungarees",
        "farmhand with a blond ponytail, blue shirt and green dungarees",
        "farmhand with a beard, straw hat, white shirt and denim dungarees",
    ]
    static let villagerLooks = [
        "young woman with dark hair in a teal blouse and brown trousers",
        "man in a red cap, mustard shirt and blue jeans",
        "white-haired grandmother in a lavender cardigan and grey skirt",
    ]
    public static var villagerCount: Int { villagerLooks.count }

    // MARK: - Animals

    static let animals: [AssetSpec] = {
        var result: [AssetSpec] = []
        let poses = ["idle", "walk1", "walk2", "eat", "sleep"]
        let kinds: [(String, Double, Double, Int, String)] = [
            ("chicken", 0.6, 0.6, 4, "Brown hen"),
            ("chick", 0.35, 0.35, 4, "Fluffy yellow chick"),
            ("cow", 2.0, 1.6, 4, "Brown and white dairy cow"),
            ("calf", 1.3, 1.1, 4, "Calf"),
            ("sheep", 1.3, 1.1, 4, "Woolly cream sheep"),
            ("sheep_sheared", 1.2, 1.0, 4, "Freshly sheared sheep, slim"),
            ("lamb", 0.9, 0.8, 4, "Lamb"),
            ("pig", 1.3, 1.0, 4, "Pink pig with a muddy belly"),
            ("piglet", 0.7, 0.55, 4, "Piglet"),
            ("goat", 1.2, 1.1, 7, "White goat with small horns"),
            ("goat_kid", 0.8, 0.7, 7, "Goat kid"),
            ("horse", 2.2, 2.0, 7, "Chestnut horse"),
            ("foal", 1.4, 1.3, 7, "Foal"),
            ("dog", 0.9, 0.8, 8, "The farm dog, a scruffy friendly mutt"),
        ]
        for (name, w, h, phase, look) in kinds {
            for pose in poses {
                result.append(.sprite("animal_\(name)_\(pose)", .animal, tiles: w, h, anchorY: 0.1, shadow: w * 0.8,
                                      phase: phase, family: "animal_\(name)",
                                      "\(look), \(pose), facing left (mirrored in code for right)."))
            }
        }
        return result
    }()

    // MARK: - Items

    static let items: [AssetSpec] = {
        var result: [AssetSpec] = []
        for crop in CropCatalog.all {
            result.append(.ui("item_\(crop.id)", .item, points: 44, 44, phase: 2, "\(crop.produceNotes) Inventory icon."))
            result.append(.ui("item_seeds_\(crop.id)", .item, points: 44, 44, phase: 2,
                              "Paper seed packet with a picture of \(crop.plural) on it."))
        }
        let goods: [(String, Int, String)] = [
            ("egg", 4, "Brown egg"), ("milk", 4, "Glass bottle of milk"), ("wool", 4, "Ball of cream wool"),
            ("truffle", 4, "Black truffle (pigs dig them up)"), ("honey", 7, "Jar of golden honey"),
            ("goat_milk", 7, "Small jug of goat milk"), ("log", 4, "Cut log"), ("log_maple", 6, "Rare maple log, reddish"),
            ("plank", 6, "Stack of planks"), ("flour", 6, "Sack of flour"), ("cheese", 6, "Wheel of cheese"),
            ("juice", 6, "Bottle of juice"), ("apple", 4, "Red apple"), ("cherry", 4, "Pair of cherries"),
            ("fertilizer", 7, "Bag of fertilizer"), ("animal_feed", 4, "Sack of animal feed"),
            ("sprinkler", 8, "Brass sprinkler head on a short stake"), ("sprinkler_pro", 8, "Big rotating sprinkler, green and brass"),
        ]
        for (name, phase, look) in goods {
            result.append(.ui("item_\(name)", .item, points: 44, 44, phase: phase, "\(look), inventory icon."))
        }
        // Workshop goods and the workshops themselves (after Phase 9).
        let listed = Set(goods.map(\.0))
        for recipe in WorkshopCatalog.recipes where !listed.contains(recipe.output) {
            result.append(.ui("item_\(recipe.output)", .item, points: 44, 44, phase: 10, "\(recipe.name), inventory icon."))
        }
        for workshop in WorkshopCatalog.all {
            result.append(.ui(workshop.icon, .item, points: 44, 44, phase: 10, "\(workshop.name) (workshop), inventory icon."))
        }
        // Fish and wild finds (Phase 11).
        for fish in FishCatalog.all {
            result.append(.ui("item_\(fish.id)", .item, points: 44, 44, phase: 11, "\(fish.name) (fish), side view, inventory icon."))
        }
        for find in ForageCatalog.all {
            result.append(.ui("item_\(find.id)", .item, points: 44, 44, phase: 11, "\(find.name) (wild find), inventory icon."))
        }
        for species in seasonalTreeSpecies {
            result.append(.ui("item_sapling_\(species)", .item, points: 44, 44, phase: 4, "\(species.capitalized) sapling in a pot."))
        }
        return result
    }()

    // MARK: - Effects

    static let effects: [AssetSpec] = [
        .sprite("fx_shadow_soft", .effect, tiles: 1, 0.5, layer: .flat, anchorY: 0.5, phase: 1,
                "Soft black ellipse with blurred edges (used at ~30% opacity under objects)."),
        .sprite("fx_smoke_puff", .effect, tiles: 0.5, 0.5, layer: .particle, anchorY: 0.5, phase: 1, "Soft grey-white smoke puff (chimneys)."),
        .sprite("fx_window_glow", .effect, tiles: 0.5, 0.5, layer: .light, anchorY: 0.5, phase: 1, "Soft warm radial glow."),
        .sprite("fx_tile_highlight", .effect, tiles: 1, 1, layer: .flat, anchorY: 0.5, phase: 1, "Rounded square outline with soft glow: tapped tile."),
        .sprite("fx_sparkle", .effect, tiles: 0.3, 0.3, layer: .particle, anchorY: 0.5, phase: 2, "Four-point sparkle (crop ready)."),
        .sprite("fx_coin", .effect, tiles: 0.3, 0.3, layer: .particle, anchorY: 0.5, phase: 2, "Gold coin that flies to the money counter."),
        .sprite("fx_harvest_pop", .effect, tiles: 0.6, 0.6, layer: .particle, anchorY: 0.5, phase: 2, "Burst of leaves and soil when harvesting."),
        .sprite("fx_water_drops", .effect, tiles: 0.6, 0.6, layer: .particle, anchorY: 0.5, phase: 2, "Water droplets when watering."),
        .sprite("fx_dust_puff", .effect, tiles: 0.5, 0.5, layer: .particle, anchorY: 0.5, phase: 2, "Beige dust puff: plowing, and behind the truck on dirt roads."),
        .sprite("fx_guide_arrow", .effect, tiles: 0.8, 0.8, layer: .particle, anchorY: 0.5, phase: 3,
                "Chunky friendly arrow pointing right (rotated in code): points the way to the next goal."),
        .sprite("fx_headlight_cone", .effect, tiles: 2, 3, layer: .light, anchorY: 0.0, phase: 3, "Soft headlight beam, pointing up, additive."),
        .sprite("fx_wood_chip", .effect, tiles: 0.15, 0.15, layer: .particle, anchorY: 0.5, phase: 4, "Wood chip flying off when chopping."),
        .sprite("fx_feather", .effect, tiles: 0.15, 0.15, layer: .particle, anchorY: 0.5, phase: 4, "Small feather."),
        .sprite("fx_job_marker", .effect, tiles: 0.5, 0.5, layer: .particle, anchorY: 0.5, phase: 5,
                 "Small round marker with a soft glow: a job the farmer has lined up."),
        .sprite("fx_bubble", .effect, tiles: 0.7, 0.7, layer: .particle, anchorY: 0.5, phase: 4,
                "Round white speech bubble with a small tail at the bottom: shows what an animal has or wants."),
        .sprite("fx_bobber", .effect, tiles: 0.3, 0.3, layer: .particle, anchorY: 0.5, phase: 11, "Red and white fishing bobber."),
        .sprite("fx_exclaim", .effect, tiles: 0.5, 0.5, layer: .particle, anchorY: 0.5, phase: 11,
                "Bold '!' in a white speech bubble: a fish bites."),
        .sprite("fx_heart", .effect, tiles: 0.3, 0.3, layer: .particle, anchorY: 0.5, phase: 4, "Small heart over a happy animal."),
        .sprite("fx_zzz", .effect, tiles: 0.3, 0.3, layer: .particle, anchorY: 0.5, phase: 4, "'z' for sleeping animals."),
        .sprite("fx_bee", .effect, tiles: 0.12, 0.12, layer: .particle, anchorY: 0.5, phase: 7, "Tiny bee."),
        .sprite("fx_leaf_green", .effect, tiles: 0.15, 0.15, layer: .particle, anchorY: 0.5, phase: 8, "Falling leaf, green."),
        .sprite("fx_leaf_orange", .effect, tiles: 0.15, 0.15, layer: .particle, anchorY: 0.5, phase: 8, "Falling leaf, autumn orange."),
        .sprite("fx_blossom_petal", .effect, tiles: 0.1, 0.1, layer: .particle, anchorY: 0.5, phase: 8, "Pink blossom petal (spring)."),
        .sprite("fx_raindrop", .effect, tiles: 0.05, 0.3, layer: .particle, anchorY: 0.5, phase: 8, "Rain streak."),
        .sprite("fx_splash", .effect, tiles: 0.2, 0.15, layer: .particle, anchorY: 0.5, phase: 8, "Tiny rain splash ring."),
        .sprite("fx_puddle", .effect, tiles: 2, 1, layer: .flat, anchorY: 0.5, phase: 8, "Rain puddle with sky reflection."),
        .sprite("fx_snowflake", .effect, tiles: 0.1, 0.1, layer: .particle, anchorY: 0.5, phase: 8, "Snowflake."),
        .sprite("fx_bird_fly1", .effect, tiles: 0.5, 0.35, layer: .particle, anchorY: 0.5, phase: 8, family: "fx_bird", "Small songbird flying, wings up."),
        .sprite("fx_bird_fly2", .effect, tiles: 0.5, 0.35, layer: .particle, anchorY: 0.5, phase: 8, family: "fx_bird", "Small songbird flying, wings down."),
        .sprite("fx_bird_sit", .effect, tiles: 0.3, 0.3, layer: .particle, anchorY: 0.1, phase: 8, family: "fx_bird", "Small songbird sitting on the ground."),
        .sprite("fx_butterfly1", .effect, tiles: 0.2, 0.2, layer: .particle, anchorY: 0.5, phase: 8, family: "fx_butterfly", "Butterfly, wings open."),
        .sprite("fx_butterfly2", .effect, tiles: 0.2, 0.2, layer: .particle, anchorY: 0.5, phase: 8, family: "fx_butterfly", "Butterfly, wings closed."),
        .sprite("fx_firefly", .effect, tiles: 0.1, 0.1, layer: .light, anchorY: 0.5, phase: 8, "Firefly glow dot (summer nights)."),
        .sprite("fx_cloud_shadow", .effect, tiles: 12, 8, layer: .flat, anchorY: 0.5, phase: 8, "Very soft cloud shadow drifting over the land."),
        .sprite("fx_water_ripple", .effect, tiles: 1, 0.5, layer: .flat, anchorY: 0.5, phase: 8, "Expanding ripple ring on water."),
    ]

    // MARK: - UI

    static let ui: [AssetSpec] = [
        AssetSpec(name: "ui_app_icon", category: .ui, layer: .ui, tilesWide: 0, tilesHigh: 0,
                  pixelWidth: 1024, pixelHeight: 1024, anchorY: 0.5, shadowWidth: 0, phase: 1,
                  notes: "App icon: the little farm at golden hour, truck in front. No transparency."),
        .ui("ui_icon_coin", points: 24, 24, phase: 1, "Gold coin, HUD money counter."),
        .ui("ui_icon_level", points: 24, 24, phase: 1, "Wheat-ear badge for the farmer level."),
        .ui("ui_icon_season_spring", points: 24, 24, phase: 1, "Blossom."),
        .ui("ui_icon_season_summer", points: 24, 24, phase: 1, "Sun."),
        .ui("ui_icon_season_autumn", points: 24, 24, phase: 1, "Maple leaf."),
        .ui("ui_icon_season_winter", points: 24, 24, phase: 1, "Snowflake."),
        .ui("ui_icon_time_morning", points: 20, 20, phase: 1, "Sunrise."),
        .ui("ui_icon_time_day", points: 20, 20, phase: 1, "Sun."),
        .ui("ui_icon_time_evening", points: 20, 20, phase: 1, "Sunset."),
        .ui("ui_icon_time_night", points: 20, 20, phase: 1, "Moon."),
        .ui("ui_icon_inventory", points: 32, 32, phase: 1, "Woven basket (inventory button)."),
        .ui("ui_icon_settings", points: 28, 28, phase: 1, "Gear."),
        .ui("ui_icon_hoe", points: 32, 32, phase: 2, "Hoe (plow action)."),
        .ui("ui_icon_watering_can", points: 32, 32, phase: 2, "Watering can."),
        .ui("ui_icon_basket", points: 32, 32, phase: 2, "Harvest basket."),
        .ui("ui_icon_hand", points: 32, 32, phase: 8, "Work glove (the bare-hand tool: walk, pick, tend animals)."),
        .ui("ui_icon_sickle", points: 32, 32, phase: 8, "Sickle with a wooden handle (harvest tool)."),
        .ui("ui_icon_axe", points: 32, 32, phase: 8, "Wood axe (chop trees, clear stumps)."),
        .ui("ui_icon_rod", points: 32, 32, phase: 11, "Bamboo fishing rod with a red and white bobber."),
        .ui("ui_icon_map", points: 32, 32, phase: 3, "Folded map."),
        .ui("ui_icon_fuel", points: 24, 24, phase: 3, "Jerry can (fuel gauge)."),
        .ui("ui_icon_truck", points: 32, 32, phase: 3, "Pickup truck (drive button)."),
        .ui("ui_icon_energy", points: 24, 24, phase: 5, "Little sun / lightning badge for the farmer's energy."),
        .ui("ui_icon_goals", points: 32, 32, phase: 5, "Rolled-up checklist with a ribbon (goals)."),
        .ui("ui_icon_bed", points: 32, 32, phase: 5, "Cozy bed with a moon (go to bed)."),
        .ui("ui_icon_contracts", points: 32, 32, phase: 5, "Pinned note (contracts board)."),
        .ui("ui_icon_journal", points: 24, 24, phase: 6, "Leather-bound farm journal with a paper label and a red ribbon bookmark (orders, the accounts, farm plans, the almanac)."),
        .ui("ui_icon_worker", points: 32, 32, phase: 6, "Farmhand in a straw hat."),
        .ui("ui_icon_collection", points: 32, 32, phase: 7, "Leather-bound book (collection)."),
        .ui("fx_vignette", .effect, points: 128, 128, phase: 13,
            "Screen-edge vignette: clear centre, soft warm-brown edges (about 50 % at the corners). Stretched over the whole view."),
        .ui("ui_portrait_mentor", points: 64, 64, phase: 13,
            "Tom, the old farmer who teaches you (tutorial card): head and shoulders, grey hair and beard, straw hat, green shirt, overalls. Transparent; the card puts it on a sky-blue disc."),
        .ui("ui_joystick_base", points: 140, 140, phase: 3, "Joystick ring, soft translucent."),
        .ui("ui_joystick_knob", points: 64, 64, phase: 3, "Joystick knob."),
        .ui("ui_panel_parchment", points: 96, 96, phase: 1, "9-slice panel: warm parchment with a subtle hand-drawn border (slice 32 pt)."),
        .ui("ui_button_primary", points: 96, 48, phase: 1, "9-slice button: warm green, soft bevel (slice 20 pt)."),
        // The wood-and-paper HUD (pixel art at 2 pt per art pixel; art/hud/make_hud.py).
        .ui("ui_hud_panel", points: 80, 40, phase: 13,
            "HUD panel, 9-slice: a slim wooden frame (dark outline, two rows of board lit top-left, an inner line) around paper. Fixed border 5 art px (10 pt); edges and middle tile."),
        .ui("ui_hud_wood", points: 80, 48, phase: 13, "HUD board, 9-slice: the same wooden frame around planks (the tool tray). Fixed border 10 pt; tiles."),
        .ui("ui_hud_slot", points: 32, 32, phase: 13, "Tool-belt slot, 9-slice: paper with a dark edge. Fixed border 6 pt."),
        .ui("ui_hud_slot_selected", points: 32, 32, phase: 13, "The tool in hand: a lighter slot with an orange edge. Fixed border 6 pt."),
        .ui("ui_hud_button", points: 48, 40, phase: 13,
            "Main HUD button, 9-slice: an orange painted board, notched corners, lit top edge, darker bottom it presses into. Fixed border 12 pt."),
        .ui("ui_hud_button_quiet", points: 48, 40, phase: 13, "The same board in plain brown, for buttons that can't be used yet (a closed shop)."),
        .ui("ui_title_scene", points: 960, 480, phase: 13,
            "The title screen: the farm on a calm evening, 480 × 240 art pixels shown at 2 pt each (a starry sky with a crescent moon, pine-lined hills, the farmhouse with warm windows, a lamp, the barn, a wheat field). Made by art/title/make_title.py; the screen animates stars, smoke and fireflies on top."),
        .ui("ui_hud_leather", points: 84, 36, phase: 13,
            "The farm journal's cover band, 9-slice: brown leather with a little grain, a lit top edge and light stitching just inside the edge (repeats every 4 art px). Fixed border 10 pt."),
        .ui("ui_icon_seeds", points: 24, 24, phase: 13, "Seed pouch with a sprout on it (the seeds tool when no packet is chosen)."),
        .ui("ui_icon_weather_cloudy", points: 24, 24, phase: 13, "Cloud (the clock on a grey day)."),
        .ui("ui_icon_weather_rain", points: 24, 24, phase: 13, "Cloud with rain."),
        .ui("ui_icon_weather_snow", points: 24, 24, phase: 13, "Cloud with snow."),
    ]
}
