# Acres — Asset List

> Generated from `Packages/AcresCore/Sources/AcresCore/Content/AssetManifest.swift`
> and `AudioManifest.swift`. Do not edit by hand: run
> `swift run acres-tools assets > ../../docs/ASSETS.md` from `Packages/AcresCore`.

Every visual is requested **by name**. To replace placeholder art, add a PNG with
exactly that name to `Acres/Resources/Assets.xcassets/Art/` (drag it in as an Image Set).
The game picks it up automatically: no code changes. Anything still missing is drawn
procedurally in code.

## Art direction

- **Camera:** top-down 3/4 view, looking down at about 60–70°. We see the ground from above
  and the *front* (south-facing) side of things standing on it. Roofs are visible from above.
- **Light:** from the upper left. Soft contact shadows are added by the game, so **do not
  paint ground shadows** into standing sprites (small self-shadows are fine).
- **Style:** stylized and warm, between cartoon and realistic. Soft painterly texture,
  slightly simplified shapes, natural but rich colors. Gentle, darker-than-fill outlines only
  where shapes need separation. Not bouncy or childish, not photorealistic.
- **Palette:** earthy greens, golden wheat, soft browns, muted blues. Keep saturation moderate:
  the game tints the whole world for time of day and season.
- **Format:** PNG with transparency, sRGB. World scale is **128 px per tile** (one tile ≈ one
  crop plot). Sizes below are recommendations; the game scales art to the listed world size,
  so any resolution with the same proportions works.
- **Anchor:** the *foot point* (where the object touches the ground) sits horizontally
  centered, at the listed fraction of the height from the bottom edge.
- **Directions:** unless noted, animals face left (mirrored in code). Vehicles have 16
  directions.

## Summary

| Category | Assets | Needed in Phase 1 |
|---|---:|---:|
| Terrain (tileable ground textures) | 11 | 5 |
| Fields | 4 | 0 |
| Crops | 75 | 0 |
| Trees | 40 | 4 |
| Nature props | 15 | 10 |
| Buildings | 59 | 3 |
| Props | 44 | 10 |
| Vehicles | 116 | 1 |
| Characters | 129 | 0 |
| Animals | 70 | 0 |
| Item icons | 107 | 0 |
| Effects & particles | 35 | 4 |
| User interface | 34 | 15 |
| **Total** | **739** | **52** |
| Audio files | 58 | 0 |

## Terrain (tileable ground textures)

| Name | Pixels | World size (tiles) | Anchor | Phase | Description |
|---|---|---|---|---:|---|
| `terrain_grass` | 512 × 512 | 4 × 4 | — | 1 | Summer meadow grass seen from above: short soft blades, painterly dabs, low contrast so objects read clearly. Must tile seamlessly. *(seamless)* |
| `terrain_grass_spring` | 512 × 512 | 4 × 4 | — | 7 | Spring grass: fresher yellow-green, a few tiny white/yellow flower specks. Seamless. *(seamless)* |
| `terrain_grass_autumn` | 512 × 512 | 4 × 4 | — | 7 | Autumn grass: olive and ochre, a few fallen leaves. Seamless. *(seamless)* |
| `terrain_snow` | 512 × 512 | 4 × 4 | — | 7 | Winter snow cover: soft blue-white with gentle drifts and sparkle. Seamless. *(seamless)* |
| `terrain_dirt` | 512 × 512 | 4 × 4 | — | 1 | Packed farmyard earth: warm brown, small pebbles, faint tracks. Seamless. *(seamless)* |
| `terrain_gravel` | 512 × 512 | 4 × 4 | — | 1 | Country gravel road: beige-grey stones on dusty ground. Seamless. *(seamless)* |
| `terrain_asphalt` | 512 × 512 | 4 × 4 | — | 1 | Old county asphalt: dark warm grey, fine grain, a few hairline cracks. No markings. Seamless. *(seamless)* |
| `terrain_sand` | 512 × 512 | 4 × 4 | — | 3 | Lake and harbor sand: pale warm beige, ripples. Seamless. *(seamless)* |
| `terrain_water` | 512 × 512 | 4 × 4 | — | 3 | Calm lake water: muted blue-green, soft painted highlights. Seamless. *(seamless)* |
| `terrain_variation` | 256 × 256 | 16 × 16 | — | 1 | Technical texture, not visible art: red = large soft blotches, green = medium noise, both greyscale and seamless. Breaks up visible tiling. *(seamless)* |
| `terrain_road_marking` | 128 × 32 | 1 × 0.25 | — | 3 | Faded dashed centre line segment for asphalt roads. *(flat)* |

## Fields

| Name | Pixels | World size (tiles) | Anchor | Phase | Description |
|---|---|---|---|---:|---|
| `field_soil_plowed` | 128 × 128 | 1 × 1 | — | 2 | One tile of freshly plowed soil, furrows running left-right, rich dark brown, soft edges so tiles merge. *(flat)* |
| `field_soil_watered` | 128 × 128 | 1 × 1 | — | 2 | Same as plowed but darker, slightly glossy: wet soil. *(flat)* |
| `field_soil_fertilized` | 128 × 128 | 1 × 1 | — | 7 | Plowed soil with pale specks of fertilizer. *(flat)* |
| `field_weeds` | 128 × 141 | 1 × 1.1 | 0.1 | 2 | Overgrown weeds and dry grass covering a tile that must be cleared. |

## Crops

| Name | Pixels | World size (tiles) | Anchor | Phase | Description |
|---|---|---|---|---:|---|
| `crop_wheat_stage0` | 128 × 160 | 1 × 1.25 | 0.1 | 2 | Wheat, stage 0 of 4: freshly sown row, a few golden seeds on dark soil. One tile of plants standing on the soil tile. |
| `crop_wheat_stage1` | 128 × 160 | 1 × 1.25 | 0.1 | 2 | Wheat, stage 1 of 4: short green sprouts. One tile of plants standing on the soil tile. |
| `crop_wheat_stage2` | 128 × 160 | 1 × 1.25 | 0.1 | 2 | Wheat, stage 2 of 4: a tuft of green blades. One tile of plants standing on the soil tile. |
| `crop_wheat_stage3` | 128 × 160 | 1 × 1.25 | 0.1 | 2 | Wheat, stage 3 of 4: tall green stalks with young green ears. One tile of plants standing on the soil tile. |
| `crop_wheat_stage4` | 128 × 160 | 1 × 1.25 | 0.1 | 2 | Wheat, stage 4 of 4: tall golden stalks with heavy ears, gently nodding. One tile of plants standing on the soil tile. |
| `crop_carrot_stage0` | 128 × 160 | 1 × 1.25 | 0.1 | 2 | Carrot, stage 0 of 4: sown soil with tiny seeds. One tile of plants standing on the soil tile. |
| `crop_carrot_stage1` | 128 × 160 | 1 × 1.25 | 0.1 | 2 | Carrot, stage 1 of 4: thin feathery seedlings. One tile of plants standing on the soil tile. |
| `crop_carrot_stage2` | 128 × 160 | 1 × 1.25 | 0.1 | 2 | Carrot, stage 2 of 4: small feathery carrot tops. One tile of plants standing on the soil tile. |
| `crop_carrot_stage3` | 128 × 160 | 1 × 1.25 | 0.1 | 2 | Carrot, stage 3 of 4: lush feathery tops, a hint of orange at the soil. One tile of plants standing on the soil tile. |
| `crop_carrot_stage4` | 128 × 160 | 1 × 1.25 | 0.1 | 2 | Carrot, stage 4 of 4: big feathery tops with bright orange carrot shoulders showing. One tile of plants standing on the soil tile. |
| `crop_potato_stage0` | 128 × 160 | 1 × 1.25 | 0.1 | 2 | Potato, stage 0 of 4: a small mound with a seed potato. One tile of plants standing on the soil tile. |
| `crop_potato_stage1` | 128 × 160 | 1 × 1.25 | 0.1 | 2 | Potato, stage 1 of 4: a few round leaves breaking the soil. One tile of plants standing on the soil tile. |
| `crop_potato_stage2` | 128 × 160 | 1 × 1.25 | 0.1 | 2 | Potato, stage 2 of 4: a leafy young potato plant. One tile of plants standing on the soil tile. |
| `crop_potato_stage3` | 128 × 160 | 1 × 1.25 | 0.1 | 2 | Potato, stage 3 of 4: a full bushy plant with small white-lilac flowers. One tile of plants standing on the soil tile. |
| `crop_potato_stage4` | 128 × 160 | 1 × 1.25 | 0.1 | 2 | Potato, stage 4 of 4: yellowing bush with potatoes peeking out at the base. One tile of plants standing on the soil tile. |
| `crop_strawberry_stage0` | 128 × 160 | 1 × 1.25 | 0.1 | 2 | Strawberry, stage 0 of 4: sown soil. One tile of plants standing on the soil tile. |
| `crop_strawberry_stage1` | 128 × 160 | 1 × 1.25 | 0.1 | 2 | Strawberry, stage 1 of 4: tiny three-part leaves. One tile of plants standing on the soil tile. |
| `crop_strawberry_stage2` | 128 × 160 | 1 × 1.25 | 0.1 | 2 | Strawberry, stage 2 of 4: a low leafy rosette. One tile of plants standing on the soil tile. |
| `crop_strawberry_stage3` | 128 × 160 | 1 × 1.25 | 0.1 | 2 | Strawberry, stage 3 of 4: rosette with white flowers. One tile of plants standing on the soil tile. |
| `crop_strawberry_stage4` | 128 × 160 | 1 × 1.25 | 0.1 | 2 | Strawberry, stage 4 of 4: rosette hung with ripe red strawberries. One tile of plants standing on the soil tile. |
| `crop_corn_stage0` | 128 × 256 | 1 × 2 | 0.1 | 2 | Corn, stage 0 of 4: sown soil. One tile of plants standing on the soil tile. |
| `crop_corn_stage1` | 128 × 256 | 1 × 2 | 0.1 | 2 | Corn, stage 1 of 4: a single green sprout. One tile of plants standing on the soil tile. |
| `crop_corn_stage2` | 128 × 256 | 1 × 2 | 0.1 | 2 | Corn, stage 2 of 4: knee-high stalks with long leaves. One tile of plants standing on the soil tile. |
| `crop_corn_stage3` | 128 × 256 | 1 × 2 | 0.1 | 2 | Corn, stage 3 of 4: tall green stalks. One tile of plants standing on the soil tile. |
| `crop_corn_stage4` | 128 × 256 | 1 × 2 | 0.1 | 2 | Corn, stage 4 of 4: tall stalks with tassels and ripe yellow cobs in green husks. One tile of plants standing on the soil tile. |
| `crop_pumpkin_stage0` | 128 × 160 | 1 × 1.25 | 0.1 | 2 | Pumpkin, stage 0 of 4: sown soil. One tile of plants standing on the soil tile. |
| `crop_pumpkin_stage1` | 128 × 160 | 1 × 1.25 | 0.1 | 2 | Pumpkin, stage 1 of 4: two round seed leaves. One tile of plants standing on the soil tile. |
| `crop_pumpkin_stage2` | 128 × 160 | 1 × 1.25 | 0.1 | 2 | Pumpkin, stage 2 of 4: a young vine with big lobed leaves. One tile of plants standing on the soil tile. |
| `crop_pumpkin_stage3` | 128 × 160 | 1 × 1.25 | 0.1 | 2 | Pumpkin, stage 3 of 4: vine with a small green pumpkin. One tile of plants standing on the soil tile. |
| `crop_pumpkin_stage4` | 128 × 160 | 1 × 1.25 | 0.1 | 2 | Pumpkin, stage 4 of 4: vine with a big ribbed orange pumpkin. One tile of plants standing on the soil tile. |
| `crop_lettuce_stage0` | 128 × 160 | 1 × 1.25 | 0.1 | 2 | Lettuce, stage 0 of 4: sown soil. One tile of plants standing on the soil tile. |
| `crop_lettuce_stage1` | 128 × 160 | 1 × 1.25 | 0.1 | 2 | Lettuce, stage 1 of 4: tiny round seedlings. One tile of plants standing on the soil tile. |
| `crop_lettuce_stage2` | 128 × 160 | 1 × 1.25 | 0.1 | 2 | Lettuce, stage 2 of 4: a small loose rosette. One tile of plants standing on the soil tile. |
| `crop_lettuce_stage3` | 128 × 160 | 1 × 1.25 | 0.1 | 2 | Lettuce, stage 3 of 4: a full soft rosette. One tile of plants standing on the soil tile. |
| `crop_lettuce_stage4` | 128 × 160 | 1 × 1.25 | 0.1 | 2 | Lettuce, stage 4 of 4: a big crisp lettuce head. One tile of plants standing on the soil tile. |
| `crop_onion_stage0` | 128 × 160 | 1 × 1.25 | 0.1 | 2 | Onion, stage 0 of 4: sown soil. One tile of plants standing on the soil tile. |
| `crop_onion_stage1` | 128 × 160 | 1 × 1.25 | 0.1 | 2 | Onion, stage 1 of 4: thin green shoots. One tile of plants standing on the soil tile. |
| `crop_onion_stage2` | 128 × 160 | 1 × 1.25 | 0.1 | 2 | Onion, stage 2 of 4: a clump of hollow leaves. One tile of plants standing on the soil tile. |
| `crop_onion_stage3` | 128 × 160 | 1 × 1.25 | 0.1 | 2 | Onion, stage 3 of 4: tall leaves, bulb swelling. One tile of plants standing on the soil tile. |
| `crop_onion_stage4` | 128 × 160 | 1 × 1.25 | 0.1 | 2 | Onion, stage 4 of 4: flopped leaves over golden onion bulbs. One tile of plants standing on the soil tile. |
| `crop_kale_stage0` | 128 × 160 | 1 × 1.25 | 0.1 | 2 | Kale, stage 0 of 4: sown soil. One tile of plants standing on the soil tile. |
| `crop_kale_stage1` | 128 × 160 | 1 × 1.25 | 0.1 | 2 | Kale, stage 1 of 4: small frilly seedlings. One tile of plants standing on the soil tile. |
| `crop_kale_stage2` | 128 × 160 | 1 × 1.25 | 0.1 | 2 | Kale, stage 2 of 4: a low frilly plant. One tile of plants standing on the soil tile. |
| `crop_kale_stage3` | 128 × 160 | 1 × 1.25 | 0.1 | 2 | Kale, stage 3 of 4: tall curly blue-green leaves. One tile of plants standing on the soil tile. |
| `crop_kale_stage4` | 128 × 160 | 1 × 1.25 | 0.1 | 2 | Kale, stage 4 of 4: a lush frosty-green kale plant. One tile of plants standing on the soil tile. |
| `crop_tomato_stage0` | 128 × 160 | 1 × 1.25 | 0.1 | 2 | Tomato, stage 0 of 4: sown soil. One tile of plants standing on the soil tile. |
| `crop_tomato_stage1` | 128 × 160 | 1 × 1.25 | 0.1 | 2 | Tomato, stage 1 of 4: a small seedling. One tile of plants standing on the soil tile. |
| `crop_tomato_stage2` | 128 × 160 | 1 × 1.25 | 0.1 | 2 | Tomato, stage 2 of 4: a young plant tied to a cane. One tile of plants standing on the soil tile. |
| `crop_tomato_stage3` | 128 × 160 | 1 × 1.25 | 0.1 | 2 | Tomato, stage 3 of 4: a leafy plant with yellow flowers. One tile of plants standing on the soil tile. |
| `crop_tomato_stage4` | 128 × 160 | 1 × 1.25 | 0.1 | 2 | Tomato, stage 4 of 4: a staked plant hung with ripe red tomatoes. One tile of plants standing on the soil tile. |
| `crop_garlic_stage0` | 128 × 160 | 1 × 1.25 | 0.1 | 2 | Garlic, stage 0 of 4: sown soil. One tile of plants standing on the soil tile. |
| `crop_garlic_stage1` | 128 × 160 | 1 × 1.25 | 0.1 | 2 | Garlic, stage 1 of 4: thin green shoots. One tile of plants standing on the soil tile. |
| `crop_garlic_stage2` | 128 × 160 | 1 × 1.25 | 0.1 | 2 | Garlic, stage 2 of 4: flat green leaves. One tile of plants standing on the soil tile. |
| `crop_garlic_stage3` | 128 × 160 | 1 × 1.25 | 0.1 | 2 | Garlic, stage 3 of 4: tall leaves with a curling scape. One tile of plants standing on the soil tile. |
| `crop_garlic_stage4` | 128 × 160 | 1 × 1.25 | 0.1 | 2 | Garlic, stage 4 of 4: dry leaves over plump white bulbs. One tile of plants standing on the soil tile. |
| `crop_sunflower_stage0` | 128 × 256 | 1 × 2 | 0.1 | 2 | Sunflower, stage 0 of 4: sown soil. One tile of plants standing on the soil tile. |
| `crop_sunflower_stage1` | 128 × 256 | 1 × 2 | 0.1 | 2 | Sunflower, stage 1 of 4: two broad seed leaves. One tile of plants standing on the soil tile. |
| `crop_sunflower_stage2` | 128 × 256 | 1 × 2 | 0.1 | 2 | Sunflower, stage 2 of 4: a knee-high stem. One tile of plants standing on the soil tile. |
| `crop_sunflower_stage3` | 128 × 256 | 1 × 2 | 0.1 | 2 | Sunflower, stage 3 of 4: a tall stem with a green bud. One tile of plants standing on the soil tile. |
| `crop_sunflower_stage4` | 128 × 256 | 1 × 2 | 0.1 | 2 | Sunflower, stage 4 of 4: a tall sunflower with a big golden head. One tile of plants standing on the soil tile. |
| `crop_blueberry_stage0` | 128 × 160 | 1 × 1.25 | 0.1 | 2 | Blueberry, stage 0 of 4: sown soil. One tile of plants standing on the soil tile. |
| `crop_blueberry_stage1` | 128 × 160 | 1 × 1.25 | 0.1 | 2 | Blueberry, stage 1 of 4: a twig with a few leaves. One tile of plants standing on the soil tile. |
| `crop_blueberry_stage2` | 128 × 160 | 1 × 1.25 | 0.1 | 2 | Blueberry, stage 2 of 4: a small round bush. One tile of plants standing on the soil tile. |
| `crop_blueberry_stage3` | 128 × 160 | 1 × 1.25 | 0.1 | 2 | Blueberry, stage 3 of 4: a bush with white bell flowers. One tile of plants standing on the soil tile. |
| `crop_blueberry_stage4` | 128 × 160 | 1 × 1.25 | 0.1 | 2 | Blueberry, stage 4 of 4: a bush covered in dusty blue berries. One tile of plants standing on the soil tile. |
| `crop_cabbage_stage0` | 128 × 160 | 1 × 1.25 | 0.1 | 2 | Cabbage, stage 0 of 4: sown soil. One tile of plants standing on the soil tile. |
| `crop_cabbage_stage1` | 128 × 160 | 1 × 1.25 | 0.1 | 2 | Cabbage, stage 1 of 4: small round seedlings. One tile of plants standing on the soil tile. |
| `crop_cabbage_stage2` | 128 × 160 | 1 × 1.25 | 0.1 | 2 | Cabbage, stage 2 of 4: a spreading rosette. One tile of plants standing on the soil tile. |
| `crop_cabbage_stage3` | 128 × 160 | 1 × 1.25 | 0.1 | 2 | Cabbage, stage 3 of 4: a rosette cupping a young head. One tile of plants standing on the soil tile. |
| `crop_cabbage_stage4` | 128 × 160 | 1 × 1.25 | 0.1 | 2 | Cabbage, stage 4 of 4: a big firm pale-green cabbage. One tile of plants standing on the soil tile. |
| `crop_melon_stage0` | 128 × 160 | 1 × 1.25 | 0.1 | 2 | Melon, stage 0 of 4: sown soil. One tile of plants standing on the soil tile. |
| `crop_melon_stage1` | 128 × 160 | 1 × 1.25 | 0.1 | 2 | Melon, stage 1 of 4: two round seed leaves. One tile of plants standing on the soil tile. |
| `crop_melon_stage2` | 128 × 160 | 1 × 1.25 | 0.1 | 2 | Melon, stage 2 of 4: a young vine. One tile of plants standing on the soil tile. |
| `crop_melon_stage3` | 128 × 160 | 1 × 1.25 | 0.1 | 2 | Melon, stage 3 of 4: a vine with a small striped melon. One tile of plants standing on the soil tile. |
| `crop_melon_stage4` | 128 × 160 | 1 × 1.25 | 0.1 | 2 | Melon, stage 4 of 4: a vine with a big ripe striped melon. One tile of plants standing on the soil tile. |

## Trees

| Name | Pixels | World size (tiles) | Anchor | Phase | Description |
|---|---|---|---|---:|---|
| `tree_oak_spring` | 384 × 512 | 3 × 4 | 0.06 | 7 | Broad round oak, thick trunk, layered canopy, spring: fresh light green (fruit trees in blossom). |
| `tree_oak_summer` | 384 × 512 | 3 × 4 | 0.06 | 1 | Broad round oak, thick trunk, layered canopy, summer: rich deep green. |
| `tree_oak_autumn` | 384 × 512 | 3 × 4 | 0.06 | 7 | Broad round oak, thick trunk, layered canopy, autumn: orange, red and gold (pine stays green). |
| `tree_oak_winter` | 384 × 512 | 3 × 4 | 0.06 | 7 | Broad round oak, thick trunk, layered canopy, winter: bare branches with snow (pine: snow-dusted). |
| `tree_oak_sapling` | 102 × 141 | 0.8 × 1.1 | 0.08 | 4 | Freshly planted oak sapling with a small stake. |
| `tree_oak_young` | 230 × 307 | 1.8 × 2.4 | 0.07 | 4 | Half-grown oak, summer look. |
| `tree_birch_spring` | 256 × 448 | 2 × 3.5 | 0.06 | 7 | Slender birch, white bark with dark marks, airy canopy, spring: fresh light green (fruit trees in blossom). |
| `tree_birch_summer` | 256 × 448 | 2 × 3.5 | 0.06 | 1 | Slender birch, white bark with dark marks, airy canopy, summer: rich deep green. |
| `tree_birch_autumn` | 256 × 448 | 2 × 3.5 | 0.06 | 7 | Slender birch, white bark with dark marks, airy canopy, autumn: orange, red and gold (pine stays green). |
| `tree_birch_winter` | 256 × 448 | 2 × 3.5 | 0.06 | 7 | Slender birch, white bark with dark marks, airy canopy, winter: bare branches with snow (pine: snow-dusted). |
| `tree_birch_sapling` | 102 × 141 | 0.8 × 1.1 | 0.08 | 4 | Freshly planted birch sapling with a small stake. |
| `tree_birch_young` | 154 × 269 | 1.2 × 2.1 | 0.07 | 4 | Half-grown birch, summer look. |
| `tree_pine_spring` | 256 × 512 | 2 × 4 | 0.06 | 7 | Tall pine, stacked soft-edged tiers, spring: fresh light green (fruit trees in blossom). |
| `tree_pine_summer` | 256 × 512 | 2 × 4 | 0.06 | 1 | Tall pine, stacked soft-edged tiers, summer: rich deep green. |
| `tree_pine_autumn` | 256 × 512 | 2 × 4 | 0.06 | 7 | Tall pine, stacked soft-edged tiers, autumn: orange, red and gold (pine stays green). |
| `tree_pine_winter` | 256 × 512 | 2 × 4 | 0.06 | 7 | Tall pine, stacked soft-edged tiers, winter: bare branches with snow (pine: snow-dusted). |
| `tree_pine_sapling` | 102 × 141 | 0.8 × 1.1 | 0.08 | 4 | Freshly planted pine sapling with a small stake. |
| `tree_pine_young` | 154 × 307 | 1.2 × 2.4 | 0.07 | 4 | Half-grown pine, summer look. |
| `tree_maple_spring` | 384 × 512 | 3 × 4 | 0.06 | 7 | Rare maple (forest plot), elegant spreading crown, spring: fresh light green (fruit trees in blossom). |
| `tree_maple_summer` | 384 × 512 | 3 × 4 | 0.06 | 6 | Rare maple (forest plot), elegant spreading crown, summer: rich deep green. |
| `tree_maple_autumn` | 384 × 512 | 3 × 4 | 0.06 | 7 | Rare maple (forest plot), elegant spreading crown, autumn: orange, red and gold (pine stays green). |
| `tree_maple_winter` | 384 × 512 | 3 × 4 | 0.06 | 7 | Rare maple (forest plot), elegant spreading crown, winter: bare branches with snow (pine: snow-dusted). |
| `tree_maple_sapling` | 102 × 141 | 0.8 × 1.1 | 0.08 | 4 | Freshly planted maple sapling with a small stake. |
| `tree_maple_young` | 230 × 307 | 1.8 × 2.4 | 0.07 | 4 | Half-grown maple, summer look. |
| `tree_apple_spring` | 320 × 384 | 2.5 × 3 | 0.06 | 7 | Small apple tree, rounded crown, spring: fresh light green (fruit trees in blossom). |
| `tree_apple_summer` | 320 × 384 | 2.5 × 3 | 0.06 | 4 | Small apple tree, rounded crown, summer: rich deep green. |
| `tree_apple_autumn` | 320 × 384 | 2.5 × 3 | 0.06 | 7 | Small apple tree, rounded crown, autumn: orange, red and gold (pine stays green). |
| `tree_apple_winter` | 320 × 384 | 2.5 × 3 | 0.06 | 7 | Small apple tree, rounded crown, winter: bare branches with snow (pine: snow-dusted). |
| `tree_apple_sapling` | 102 × 141 | 0.8 × 1.1 | 0.08 | 4 | Freshly planted apple sapling with a small stake. |
| `tree_apple_young` | 192 × 230 | 1.5 × 1.8 | 0.07 | 4 | Half-grown apple, summer look. |
| `tree_cherry_spring` | 320 × 384 | 2.5 × 3 | 0.06 | 7 | Small cherry tree, graceful crown, spring: fresh light green (fruit trees in blossom). |
| `tree_cherry_summer` | 320 × 384 | 2.5 × 3 | 0.06 | 4 | Small cherry tree, graceful crown, summer: rich deep green. |
| `tree_cherry_autumn` | 320 × 384 | 2.5 × 3 | 0.06 | 7 | Small cherry tree, graceful crown, autumn: orange, red and gold (pine stays green). |
| `tree_cherry_winter` | 320 × 384 | 2.5 × 3 | 0.06 | 7 | Small cherry tree, graceful crown, winter: bare branches with snow (pine: snow-dusted). |
| `tree_cherry_sapling` | 102 × 141 | 0.8 × 1.1 | 0.08 | 4 | Freshly planted cherry sapling with a small stake. |
| `tree_cherry_young` | 192 × 230 | 1.5 × 1.8 | 0.07 | 4 | Half-grown cherry, summer look. |
| `tree_apple_fruit` | 320 × 384 | 2.5 × 3 | 0.06 | 4 | Overlay: red apples only, aligned to tree_apple_*, shown when fruit is ready. |
| `tree_cherry_fruit` | 320 × 384 | 2.5 × 3 | 0.06 | 4 | Overlay: dark red cherries only, aligned to tree_cherry_*. |
| `tree_stump` | 128 × 102 | 1 × 0.8 | 0.2 | 1 | Cut tree stump with visible rings, a little moss. |
| `tree_felled` | 384 × 154 | 3 × 1.2 | 0.25 | 4 | A tree lying on the ground just after being chopped. |

## Nature props

| Name | Pixels | World size (tiles) | Anchor | Phase | Description |
|---|---|---|---|---:|---|
| `nature_bush_a` | 154 × 128 | 1.2 × 1 | 0.1 | 1 | Round leafy bush. |
| `nature_bush_b` | 166 × 115 | 1.3 × 0.9 | 0.1 | 1 | Low wide bush, slightly darker. |
| `nature_rock_small` | 102 × 77 | 0.8 × 0.6 | 0.15 | 1 | Small grey field stone. |
| `nature_rock_large` | 205 × 154 | 1.6 × 1.2 | 0.12 | 1 | Large mossy boulder. |
| `nature_grass_tuft_a` | 77 × 64 | 0.6 × 0.5 | 0.1 | 1 | Tuft of taller grass (sways). |
| `nature_grass_tuft_b` | 90 × 64 | 0.7 × 0.5 | 0.1 | 1 | Tuft of grass with a seed head. |
| `nature_flowers_yellow` | 77 × 64 | 0.6 × 0.5 | 0.1 | 1 | Cluster of small yellow wildflowers. |
| `nature_flowers_white` | 77 × 64 | 0.6 × 0.5 | 0.1 | 1 | Cluster of white daisies. |
| `nature_flowers_purple` | 77 × 64 | 0.6 × 0.5 | 0.1 | 1 | Cluster of purple wildflowers. |
| `nature_pond_small` | 435 × 307 | 3.4 × 2.4 | — | 1 | Small farm pond seen from above with soft muddy banks and a few reeds; flat. *(flat)* |
| `nature_reeds` | 128 × 154 | 1 × 1.2 | 0.1 | 3 | Clump of reeds for lake shores. |
| `nature_lily_pads` | 128 × 77 | 1 × 0.6 | — | 3 | Lily pads floating on water. *(flat)* |
| `nature_lake` | 1331 × 742 | 10.4 × 5.8 | — | 11 | Willow Lake seen from above: a big rounded lake with sandy and grassy banks and darker deep water; flat. *(flat)* |
| `nature_mushrooms` | 64 × 51 | 0.5 × 0.4 | 0.1 | 3 | Small cluster of forest mushrooms. |
| `nature_log_fallen` | 320 × 115 | 2.5 × 0.9 | 0.2 | 3 | Old mossy fallen log in the forest. |

## Buildings

| Name | Pixels | World size (tiles) | Anchor | Phase | Description |
|---|---|---|---|---:|---|
| `building_farmhouse_t0` | 640 × 640 | 5 × 5 | 0.06 | 1 | The starting farmhouse: small run-down wooden house, faded paint, patched roof, one boarded window, sagging porch. |
| `building_farmhouse_t0_lights` | 640 × 640 | 5 × 5 | — | 1 | Night overlay for building_farmhouse_t0: only the warm glow of lit windows on transparent background, pixel-aligned with the building. *(additive light)* |
| `building_farmhouse_t1` | 640 × 640 | 5 × 5 | 0.06 | 6 | Repaired cozy cottage: fresh paint, flower boxes. |
| `building_farmhouse_t1_lights` | 640 × 640 | 5 × 5 | — | 6 | Night overlay for building_farmhouse_t1: only the warm glow of lit windows on transparent background, pixel-aligned with the building. *(additive light)* |
| `building_farmhouse_t2` | 768 × 768 | 6 × 6 | 0.06 | 6 | Two-story farmhouse with a wraparound porch. |
| `building_farmhouse_t2_lights` | 768 × 768 | 6 × 6 | — | 6 | Night overlay for building_farmhouse_t2: only the warm glow of lit windows on transparent background, pixel-aligned with the building. *(additive light)* |
| `building_farmhouse_t3` | 896 × 896 | 7 × 7 | 0.06 | 6 | Grand estate farmhouse, the reward of a thriving empire. |
| `building_farmhouse_t3_lights` | 896 × 896 | 7 × 7 | — | 6 | Night overlay for building_farmhouse_t3: only the warm glow of lit windows on transparent background, pixel-aligned with the building. *(additive light)* |
| `building_barn_old` | 640 × 704 | 5 × 5.5 | 0.06 | 1 | Old weathered red barn: sagging roof, missing planks. Restorable. |
| `building_barn` | 640 × 704 | 5 × 5.5 | 0.06 | 4 | Restored red barn (cows, sheep, goats). |
| `building_barn_lights` | 640 × 704 | 5 × 5.5 | — | 4 | Night overlay for building_barn: only the warm glow of lit windows on transparent background, pixel-aligned with the building. *(additive light)* |
| `building_coop` | 384 × 384 | 3 × 3 | 0.06 | 4 | Chicken coop with a little ramp. |
| `building_pigsty` | 384 × 320 | 3 × 2.5 | 0.06 | 4 | Pigsty: low shed with a muddy yard. |
| `building_sheep_shelter` | 384 × 320 | 3 × 2.5 | 0.06 | 4 | Open-fronted sheep shelter with a sloped roof and straw inside. |
| `building_goat_shed` | 384 × 320 | 3 × 2.5 | 0.06 | 11 | Small open goat shed with a red roof and a hay rack. |
| `building_beehives` | 256 × 205 | 2 × 1.6 | 0.06 | 7 | Row of three painted beehives. |
| `building_stable` | 512 × 512 | 4 × 4 | 0.06 | 7 | Horse stable with half doors. |
| `building_storage_shed` | 384 × 384 | 3 × 3 | 0.06 | 2 | Wooden storage shed for harvested goods. |
| `building_silo` | 256 × 576 | 2 × 4.5 | 0.06 | 6 | Metal grain silo with a conical roof. |
| `building_greenhouse` | 640 × 512 | 5 × 4 | 0.06 | 6 | Glass greenhouse with visible plants inside. |
| `building_greenhouse_lights` | 640 × 512 | 5 × 4 | — | 6 | Night overlay for building_greenhouse: only the warm glow of lit windows on transparent background, pixel-aligned with the building. *(additive light)* |
| `building_garage` | 512 × 448 | 4 × 3.5 | 0.06 | 6 | Farm garage for bigger vehicles and trailers. |
| `building_mill` | 384 × 640 | 3 × 5 | 0.06 | 6 | Small wooden windmill (wheat to flour). |
| `building_dairy` | 384 × 384 | 3 × 3 | 0.06 | 6 | Dairy hut (milk to cheese), white walls. |
| `building_sawmill` | 512 × 384 | 4 × 3 | 0.06 | 6 | Open-sided sawmill with a big blade (logs to planks). |
| `building_juice_press` | 320 × 320 | 2.5 × 2.5 | 0.06 | 6 | Wooden juice press shed with barrels. |
| `building_seed_shop` | 640 × 576 | 5 × 4.5 | 0.06 | 3 | Village seed shop: green awning, seed racks outside. |
| `building_seed_shop_lights` | 640 × 576 | 5 × 4.5 | — | 3 | Night overlay for building_seed_shop: only the warm glow of lit windows on transparent background, pixel-aligned with the building. *(additive light)* |
| `building_gas_station` | 768 × 512 | 6 × 4 | 0.06 | 3 | Small old gas station with a canopy. |
| `building_gas_station_lights` | 768 × 512 | 6 × 4 | — | 3 | Night overlay for building_gas_station: only the warm glow of lit windows on transparent background, pixel-aligned with the building. *(additive light)* |
| `building_house_village_a` | 512 × 576 | 4 × 4.5 | 0.06 | 3 | Village house, cream walls, red roof. |
| `building_house_village_a_lights` | 512 × 576 | 4 × 4.5 | — | 3 | Night overlay for building_house_village_a: only the warm glow of lit windows on transparent background, pixel-aligned with the building. *(additive light)* |
| `building_house_village_b` | 512 × 576 | 4 × 4.5 | 0.06 | 3 | Village house, blue shutters, grey roof. |
| `building_house_village_b_lights` | 512 × 576 | 4 × 4.5 | — | 3 | Night overlay for building_house_village_b: only the warm glow of lit windows on transparent background, pixel-aligned with the building. *(additive light)* |
| `building_house_village_c` | 512 × 576 | 4 × 4.5 | 0.06 | 3 | Village cottage with climbing roses. |
| `building_house_village_c_lights` | 512 × 576 | 4 × 4.5 | — | 3 | Night overlay for building_house_village_c: only the warm glow of lit windows on transparent background, pixel-aligned with the building. *(additive light)* |
| `building_livestock_market` | 896 × 640 | 7 × 5 | 0.06 | 4 | Livestock market: a big open barn with a sign, pens and an auction shed. |
| `building_hardware_store` | 640 × 576 | 5 × 4.5 | 0.06 | 5 | Hardware store with tools displayed outside. |
| `building_hardware_store_lights` | 640 × 576 | 5 × 4.5 | — | 5 | Night overlay for building_hardware_store: only the warm glow of lit windows on transparent background, pixel-aligned with the building. *(additive light)* |
| `building_farmers_market_stall` | 320 × 320 | 2.5 × 2.5 | 0.06 | 3 | Farmers' market stall with striped awning. |
| `building_restaurant` | 640 × 576 | 5 × 4.5 | 0.06 | 6 | The Rusty Spoon: a cheerful diner (contract client). |
| `building_restaurant_lights` | 640 × 576 | 5 × 4.5 | — | 6 | Night overlay for building_restaurant: only the warm glow of lit windows on transparent background, pixel-aligned with the building. *(additive light)* |
| `building_bakery` | 512 × 576 | 4 × 4.5 | 0.06 | 6 | Hansen's Bakery: warm brick bakery with a bread sign (contract client). |
| `building_bakery_lights` | 512 × 576 | 4 × 4.5 | — | 6 | Night overlay for building_bakery: only the warm glow of lit windows on transparent background, pixel-aligned with the building. *(additive light)* |
| `building_bank` | 512 × 576 | 4 × 4.5 | 0.06 | 6 | Valley Savings Bank: small stone bank with columns. |
| `building_bank_lights` | 512 × 576 | 4 × 4.5 | — | 6 | Night overlay for building_bank: only the warm glow of lit windows on transparent background, pixel-aligned with the building. *(additive light)* |
| `building_wholesale_depot` | 1024 × 768 | 8 × 6 | 0.06 | 5 | Harbor wholesale depot: big warehouse with loading doors. |
| `building_wholesale_depot_lights` | 1024 × 768 | 8 × 6 | — | 5 | Night overlay for building_wholesale_depot: only the warm glow of lit windows on transparent background, pixel-aligned with the building. *(additive light)* |
| `building_harbor_warehouse` | 896 × 640 | 7 × 5 | 0.06 | 5 | Old brick harbor warehouse. |
| `building_lumber_yard` | 768 × 640 | 6 × 5 | 0.06 | 6 | North Woods Lumber: yard office with stacked timber (contract client). |
| `building_town_shop` | 512 × 576 | 4 × 4.5 | 0.06 | 6 | Player-owned shop in town (sell your own goods). |
| `building_town_shop_lights` | 512 × 576 | 4 × 4.5 | — | 6 | Night overlay for building_town_shop: only the warm glow of lit windows on transparent background, pixel-aligned with the building. *(additive light)* |
| `building_deli` | 512 × 576 | 4 × 4.5 | 0.06 | 10 | Valley Deli: striped awning, cheeses and jars in the window (client). |
| `building_deli_lights` | 512 × 576 | 4 × 4.5 | — | 10 | Night overlay for building_deli: only the warm glow of lit windows on transparent background, pixel-aligned with the building. *(additive light)* |
| `building_cabin_lakeside` | 512 × 512 | 4 × 4 | 0.06 | 6 | Lakeside log cabin with a small jetty. |
| `building_cabin_lakeside_lights` | 512 × 512 | 4 × 4 | — | 6 | Night overlay for building_cabin_lakeside: only the warm glow of lit windows on transparent background, pixel-aligned with the building. *(additive light)* |
| `building_farm_abandoned` | 768 × 768 | 6 × 6 | 0.06 | 6 | The old abandoned farmhouse, overgrown; a long-term restoration goal. |
| `building_lighthouse` | 256 × 768 | 2 × 6 | 0.06 | 8 | Harbor lighthouse, white with a red band. |
| `building_lighthouse_lights` | 256 × 768 | 2 × 6 | — | 8 | Night overlay for building_lighthouse: only the warm glow of lit windows on transparent background, pixel-aligned with the building. *(additive light)* |

## Props

| Name | Pixels | World size (tiles) | Anchor | Phase | Description |
|---|---|---|---|---:|---|
| `prop_fence_wood_h` | 134 × 115 | 1.05 × 0.9 | 0.12 | 1 | One tile of weathered wooden fence running left-right: two rails and a post on the left end. |
| `prop_fence_wood_h_broken` | 134 × 115 | 1.05 × 0.9 | 0.12 | 1 | Same fence with a broken, hanging rail. |
| `prop_fence_wood_v` | 45 × 243 | 0.35 × 1.9 | 0.03 | 1 | One tile of the same fence running away from the camera (north-south), seen in 3/4 view. |
| `prop_fence_wood_post` | 38 × 122 | 0.3 × 0.95 | 0.08 | 1 | Single fence post. |
| `prop_fence_new_h` | 134 × 115 | 1.05 × 0.9 | 0.12 | 6 | Repaired white-painted fence, left-right. |
| `prop_fence_new_v` | 45 × 243 | 0.35 × 1.9 | 0.03 | 6 | Repaired white-painted fence, north-south. |
| `prop_well` | 205 × 256 | 1.6 × 2 | 0.1 | 1 | Old stone well with a little wooden roof and bucket. |
| `prop_mailbox` | 64 × 141 | 0.5 × 1.1 | 0.05 | 1 | Rusty farm mailbox on a post. |
| `prop_log_pile` | 205 × 141 | 1.6 × 1.1 | 0.12 | 1 | Neat pile of split firewood logs. |
| `prop_crate` | 90 × 102 | 0.7 × 0.8 | 0.12 | 1 | Wooden crate. |
| `prop_hay_bale` | 141 × 115 | 1.1 × 0.9 | 0.12 | 1 | Rectangular hay bale. |
| `prop_sign_for_sale` | 115 × 166 | 0.9 × 1.3 | 0.05 | 1 | Hand-painted 'For Sale' sign on a stake. |
| `prop_sign_sold` | 115 × 166 | 0.9 × 1.3 | 0.05 | 6 | The same sign with a 'Sold' banner. |
| `prop_scarecrow` | 128 × 218 | 1 × 1.7 | 0.05 | 2 | Friendly scarecrow with a straw hat. |
| `prop_sprinkler` | 77 × 77 | 0.6 × 0.6 | 0.2 | 5 | Brass field sprinkler head. |
| `prop_sprinkler_pro` | 102 × 115 | 0.8 × 0.9 | 0.15 | 8 | Big rotating sprinkler on a green stand. |
| `prop_water_trough` | 192 × 102 | 1.5 × 0.8 | 0.15 | 4 | Animal water trough, full of fresh water. |
| `prop_water_trough_empty` | 192 × 102 | 1.5 × 0.8 | 0.15 | 4 | The same trough, empty and dry. |
| `prop_sign_repair` | 115 × 166 | 0.9 × 1.3 | 0.05 | 4 | Little wooden sign with a hammer on it: this pen can be repaired. |
| `prop_feeder` | 154 × 102 | 1.2 × 0.8 | 0.15 | 4 | Wooden animal feeder with hay. |
| `prop_notice_board` | 192 × 230 | 1.5 × 1.8 | 0.05 | 5 | Village notice board with pinned papers (contracts). |
| `prop_lamp_post` | 64 × 320 | 0.5 × 2.5 | 0.03 | 3 | Old iron street lamp. |
| `prop_lamp_post_lights` | 64 × 320 | 0.5 × 2.5 | — | 3 | Glow of the street lamp, aligned with prop_lamp_post. *(additive light)* |
| `prop_bench` | 192 × 128 | 1.5 × 1 | 0.1 | 3 | Wooden park bench (viewpoint). |
| `prop_signpost` | 102 × 230 | 0.8 × 1.8 | 0.04 | 3 | Wooden signpost with arrows. |
| `prop_for_rent_sign` | 128 × 166 | 1 × 1.3 | 0.05 | 7 | Little wooden "FOR RENT" board on a post (the corner shop, before it's rented). |
| `prop_open_sign` | 115 × 141 | 0.9 × 1.1 | 0.05 | 7 | Chalkboard A-frame sign saying "OPEN" with a drawn carrot (your shop). |
| `prop_gas_pump` | 102 × 205 | 0.8 × 1.6 | 0.05 | 3 | Vintage gas pump. |
| `prop_market_goods` | 192 × 128 | 1.5 × 1 | 0.1 | 3 | Baskets and crates of produce for the market square. |
| `prop_pier` | 256 × 768 | 2 × 6 | — | 3 | Wooden fishing pier seen from above. *(flat)* |
| `prop_rowboat` | 256 × 128 | 2 × 1 | — | 3 | Small wooden rowboat on water. *(flat)* |
| `prop_bridge_wood` | 384 × 512 | 3 × 4 | — | 3 | Wooden road bridge over a stream, seen from above. *(flat)* |
| `prop_merchant_wagon` | 384 × 320 | 3 × 2.5 | 0.08 | 5 | The traveling merchant's colorful covered wagon. |
| `prop_workshop_sawhorse` | 141 × 179 | 1.1 × 1.4 | 0.1 | 10 | Sawhorse standing on the farm: saws logs into planks. |
| `prop_workshop_mill` | 141 × 179 | 1.1 × 1.4 | 0.1 | 10 | Hand mill standing on the farm: grinds grain into flour and meal. |
| `prop_workshop_beehive` | 141 × 179 | 1.1 × 1.4 | 0.1 | 10 | Beehive standing on the farm: bees make honey by themselves every two days. |
| `prop_workshop_jam_kitchen` | 141 × 179 | 1.1 × 1.4 | 0.1 | 10 | Jam kitchen standing on the farm: cooks fruit and tomatoes into jars. |
| `prop_workshop_drying_rack` | 141 × 179 | 1.1 × 1.4 | 0.1 | 10 | Drying rack standing on the farm: dries herbs and mushrooms from the woods. |
| `prop_workshop_pickling_crock` | 141 × 179 | 1.1 × 1.4 | 0.1 | 10 | Pickling crock standing on the farm: slowly pickles vegetables. |
| `prop_workshop_cheese_press` | 141 × 179 | 1.1 × 1.4 | 0.1 | 10 | Cheese press standing on the farm: turns milk into cheese. |
| `prop_workshop_juice_press` | 141 × 179 | 1.1 × 1.4 | 0.1 | 10 | Juice press standing on the farm: presses fruit and carrots into juice. |
| `prop_workshop_oil_press` | 141 × 179 | 1.1 × 1.4 | 0.1 | 10 | Oil press standing on the farm: presses sunflowers into golden oil. |
| `prop_workshop_loom` | 141 × 179 | 1.1 × 1.4 | 0.1 | 10 | Loom standing on the farm: weaves wool into fine cloth. |
| `prop_workshop_smokehouse` | 141 × 179 | 1.1 × 1.4 | 0.1 | 10 | Smokehouse standing on the farm: smokes fish over beech wood. |

## Vehicles

| Name | Pixels | World size (tiles) | Anchor | Phase | Description |
|---|---|---|---|---:|---|
| `vehicle_truck_old_dir00` … `vehicle_truck_old_dir15` (16 frames) | 320 × 320 | 2.5 × 2.5 | 0.4 | 1–3 | The player's beat-up pickup truck: faded teal paint, rust spots, open cargo bed, 3/4 view. 16 directions, 22.5° apart; frame 00 faces east, counter-clockwise (04 = away from camera, 08 = west, 12 = toward camera). |
| `vehicle_truck_old_load1_dir00` … `vehicle_truck_old_load1_dir15` (16 frames) | 320 × 320 | 2.5 × 2.5 | 0.4 | 3 | Overlay: a few crates and sacks in the truck bed only (transparent elsewhere), aligned with vehicle_truck_old. 16 directions, 22.5° apart; frame 00 faces east, counter-clockwise (04 = away from camera, 08 = west, 12 = toward camera). |
| `vehicle_truck_old_load2_dir00` … `vehicle_truck_old_load2_dir15` (16 frames) | 320 × 320 | 2.5 × 2.5 | 0.4 | 3 | Overlay: a fully loaded truck bed, crates stacked high, aligned with vehicle_truck_old. 16 directions, 22.5° apart; frame 00 faces east, counter-clockwise (04 = away from camera, 08 = west, 12 = toward camera). |
| `vehicle_trailer_dir00` … `vehicle_trailer_dir15` (16 frames) | 282 × 282 | 2.2 × 2.2 | 0.4 | 6 | Small flatbed trailer that hitches to the truck. 16 directions, 22.5° apart; frame 00 faces east, counter-clockwise (04 = away from camera, 08 = west, 12 = toward camera). |
| `vehicle_truck_big_dir00` … `vehicle_truck_big_dir15` (16 frames) | 410 × 410 | 3.2 × 3.2 | 0.4 | 7 | Bigger farm truck with a large bed, upgrade. 16 directions, 22.5° apart; frame 00 faces east, counter-clockwise (04 = away from camera, 08 = west, 12 = toward camera). |
| `vehicle_car_npc_a_dir00` … `vehicle_car_npc_a_dir15` (16 frames) | 294 × 294 | 2.3 × 2.3 | 0.4 | 8 | Villager's small hatchback, red. 16 directions, 22.5° apart; frame 00 faces east, counter-clockwise (04 = away from camera, 08 = west, 12 = toward camera). |
| `vehicle_car_npc_b_dir00` … `vehicle_car_npc_b_dir15` (16 frames) | 294 × 294 | 2.3 × 2.3 | 0.4 | 8 | Villager's station wagon, beige. 16 directions, 22.5° apart; frame 00 faces east, counter-clockwise (04 = away from camera, 08 = west, 12 = toward camera). |
| `vehicle_cargo_crate` | 51 × 51 | 0.4 × 0.4 | 0.2 | 3 | Small crate shown in the truck bed. |
| `vehicle_cargo_sack` | 51 × 45 | 0.4 × 0.35 | 0.2 | 3 | Burlap sack shown in the truck bed. |
| `vehicle_cargo_logs` | 102 × 51 | 0.8 × 0.4 | 0.2 | 4 | Bundle of logs shown in the truck bed. |
| `vehicle_cargo_milk_can` | 38 × 51 | 0.3 × 0.4 | 0.2 | 4 | Milk can shown in the truck bed. |

## Characters

| Name | Pixels | World size (tiles) | Anchor | Phase | Description |
|---|---|---|---|---:|---|
| `character_farmer_down_idle` | 115 × 192 | 0.9 × 1.5 | 0.05 | 5 | The farmer: friendly young farmer in a straw hat, checked shirt, blue overalls and boots, facing the camera, standing relaxed. |
| `character_farmer_down_walk1` | 115 × 192 | 0.9 × 1.5 | 0.05 | 5 | The farmer: friendly young farmer in a straw hat, checked shirt, blue overalls and boots, facing the camera, walking, left foot forward. |
| `character_farmer_down_walk2` | 115 × 192 | 0.9 × 1.5 | 0.05 | 5 | The farmer: friendly young farmer in a straw hat, checked shirt, blue overalls and boots, facing the camera, walking, right foot forward. |
| `character_farmer_down_hoe1` | 115 × 192 | 0.9 × 1.5 | 0.05 | 5 | The farmer: friendly young farmer in a straw hat, checked shirt, blue overalls and boots, facing the camera, raising a hoe. |
| `character_farmer_down_hoe2` | 115 × 192 | 0.9 × 1.5 | 0.05 | 5 | The farmer: friendly young farmer in a straw hat, checked shirt, blue overalls and boots, facing the camera, striking the ground with a hoe. |
| `character_farmer_down_can1` | 115 × 192 | 0.9 × 1.5 | 0.05 | 5 | The farmer: friendly young farmer in a straw hat, checked shirt, blue overalls and boots, facing the camera, tilting a watering can. |
| `character_farmer_down_can2` | 115 × 192 | 0.9 × 1.5 | 0.05 | 5 | The farmer: friendly young farmer in a straw hat, checked shirt, blue overalls and boots, facing the camera, pouring from a watering can. |
| `character_farmer_down_hands1` | 115 × 192 | 0.9 × 1.5 | 0.05 | 5 | The farmer: friendly young farmer in a straw hat, checked shirt, blue overalls and boots, facing the camera, bending down to the ground. |
| `character_farmer_down_hands2` | 115 × 192 | 0.9 × 1.5 | 0.05 | 5 | The farmer: friendly young farmer in a straw hat, checked shirt, blue overalls and boots, facing the camera, picking something up / sowing. |
| `character_farmer_down_axe1` | 115 × 192 | 0.9 × 1.5 | 0.05 | 5 | The farmer: friendly young farmer in a straw hat, checked shirt, blue overalls and boots, facing the camera, raising an axe. |
| `character_farmer_down_axe2` | 115 × 192 | 0.9 × 1.5 | 0.05 | 5 | The farmer: friendly young farmer in a straw hat, checked shirt, blue overalls and boots, facing the camera, swinging an axe. |
| `character_farmer_down_rod1` | 115 × 192 | 0.9 × 1.5 | 0.05 | 5 | The farmer: friendly young farmer in a straw hat, checked shirt, blue overalls and boots, facing the camera, holding a fishing rod out, waiting for a bite. |
| `character_farmer_down_rod2` | 115 × 192 | 0.9 × 1.5 | 0.05 | 5 | The farmer: friendly young farmer in a straw hat, checked shirt, blue overalls and boots, facing the camera, pulling up a bent fishing rod. |
| `character_farmer_up_idle` | 115 × 192 | 0.9 × 1.5 | 0.05 | 5 | The farmer: friendly young farmer in a straw hat, checked shirt, blue overalls and boots, seen from behind, standing relaxed. |
| `character_farmer_up_walk1` | 115 × 192 | 0.9 × 1.5 | 0.05 | 5 | The farmer: friendly young farmer in a straw hat, checked shirt, blue overalls and boots, seen from behind, walking, left foot forward. |
| `character_farmer_up_walk2` | 115 × 192 | 0.9 × 1.5 | 0.05 | 5 | The farmer: friendly young farmer in a straw hat, checked shirt, blue overalls and boots, seen from behind, walking, right foot forward. |
| `character_farmer_up_hoe1` | 115 × 192 | 0.9 × 1.5 | 0.05 | 5 | The farmer: friendly young farmer in a straw hat, checked shirt, blue overalls and boots, seen from behind, raising a hoe. |
| `character_farmer_up_hoe2` | 115 × 192 | 0.9 × 1.5 | 0.05 | 5 | The farmer: friendly young farmer in a straw hat, checked shirt, blue overalls and boots, seen from behind, striking the ground with a hoe. |
| `character_farmer_up_can1` | 115 × 192 | 0.9 × 1.5 | 0.05 | 5 | The farmer: friendly young farmer in a straw hat, checked shirt, blue overalls and boots, seen from behind, tilting a watering can. |
| `character_farmer_up_can2` | 115 × 192 | 0.9 × 1.5 | 0.05 | 5 | The farmer: friendly young farmer in a straw hat, checked shirt, blue overalls and boots, seen from behind, pouring from a watering can. |
| `character_farmer_up_hands1` | 115 × 192 | 0.9 × 1.5 | 0.05 | 5 | The farmer: friendly young farmer in a straw hat, checked shirt, blue overalls and boots, seen from behind, bending down to the ground. |
| `character_farmer_up_hands2` | 115 × 192 | 0.9 × 1.5 | 0.05 | 5 | The farmer: friendly young farmer in a straw hat, checked shirt, blue overalls and boots, seen from behind, picking something up / sowing. |
| `character_farmer_up_axe1` | 115 × 192 | 0.9 × 1.5 | 0.05 | 5 | The farmer: friendly young farmer in a straw hat, checked shirt, blue overalls and boots, seen from behind, raising an axe. |
| `character_farmer_up_axe2` | 115 × 192 | 0.9 × 1.5 | 0.05 | 5 | The farmer: friendly young farmer in a straw hat, checked shirt, blue overalls and boots, seen from behind, swinging an axe. |
| `character_farmer_up_rod1` | 115 × 192 | 0.9 × 1.5 | 0.05 | 5 | The farmer: friendly young farmer in a straw hat, checked shirt, blue overalls and boots, seen from behind, holding a fishing rod out, waiting for a bite. |
| `character_farmer_up_rod2` | 115 × 192 | 0.9 × 1.5 | 0.05 | 5 | The farmer: friendly young farmer in a straw hat, checked shirt, blue overalls and boots, seen from behind, pulling up a bent fishing rod. |
| `character_farmer_side_idle` | 115 × 192 | 0.9 × 1.5 | 0.05 | 5 | The farmer: friendly young farmer in a straw hat, checked shirt, blue overalls and boots, facing left (mirrored for right), standing relaxed. |
| `character_farmer_side_walk1` | 115 × 192 | 0.9 × 1.5 | 0.05 | 5 | The farmer: friendly young farmer in a straw hat, checked shirt, blue overalls and boots, facing left (mirrored for right), walking, left foot forward. |
| `character_farmer_side_walk2` | 115 × 192 | 0.9 × 1.5 | 0.05 | 5 | The farmer: friendly young farmer in a straw hat, checked shirt, blue overalls and boots, facing left (mirrored for right), walking, right foot forward. |
| `character_farmer_side_hoe1` | 115 × 192 | 0.9 × 1.5 | 0.05 | 5 | The farmer: friendly young farmer in a straw hat, checked shirt, blue overalls and boots, facing left (mirrored for right), raising a hoe. |
| `character_farmer_side_hoe2` | 115 × 192 | 0.9 × 1.5 | 0.05 | 5 | The farmer: friendly young farmer in a straw hat, checked shirt, blue overalls and boots, facing left (mirrored for right), striking the ground with a hoe. |
| `character_farmer_side_can1` | 115 × 192 | 0.9 × 1.5 | 0.05 | 5 | The farmer: friendly young farmer in a straw hat, checked shirt, blue overalls and boots, facing left (mirrored for right), tilting a watering can. |
| `character_farmer_side_can2` | 115 × 192 | 0.9 × 1.5 | 0.05 | 5 | The farmer: friendly young farmer in a straw hat, checked shirt, blue overalls and boots, facing left (mirrored for right), pouring from a watering can. |
| `character_farmer_side_hands1` | 115 × 192 | 0.9 × 1.5 | 0.05 | 5 | The farmer: friendly young farmer in a straw hat, checked shirt, blue overalls and boots, facing left (mirrored for right), bending down to the ground. |
| `character_farmer_side_hands2` | 115 × 192 | 0.9 × 1.5 | 0.05 | 5 | The farmer: friendly young farmer in a straw hat, checked shirt, blue overalls and boots, facing left (mirrored for right), picking something up / sowing. |
| `character_farmer_side_axe1` | 115 × 192 | 0.9 × 1.5 | 0.05 | 5 | The farmer: friendly young farmer in a straw hat, checked shirt, blue overalls and boots, facing left (mirrored for right), raising an axe. |
| `character_farmer_side_axe2` | 115 × 192 | 0.9 × 1.5 | 0.05 | 5 | The farmer: friendly young farmer in a straw hat, checked shirt, blue overalls and boots, facing left (mirrored for right), swinging an axe. |
| `character_farmer_side_rod1` | 115 × 192 | 0.9 × 1.5 | 0.05 | 5 | The farmer: friendly young farmer in a straw hat, checked shirt, blue overalls and boots, facing left (mirrored for right), holding a fishing rod out, waiting for a bite. |
| `character_farmer_side_rod2` | 115 × 192 | 0.9 × 1.5 | 0.05 | 5 | The farmer: friendly young farmer in a straw hat, checked shirt, blue overalls and boots, facing left (mirrored for right), pulling up a bent fishing rod. |
| `character_worker1_down_idle` | 115 × 192 | 0.9 × 1.5 | 0.05 | 8 | Farmhand: farmhand in a green cap, red shirt and brown dungarees, facing the camera, standing relaxed. |
| `character_worker1_down_walk1` | 115 × 192 | 0.9 × 1.5 | 0.05 | 8 | Farmhand: farmhand in a green cap, red shirt and brown dungarees, facing the camera, walking, left foot forward. |
| `character_worker1_down_walk2` | 115 × 192 | 0.9 × 1.5 | 0.05 | 8 | Farmhand: farmhand in a green cap, red shirt and brown dungarees, facing the camera, walking, right foot forward. |
| `character_worker1_down_can1` | 115 × 192 | 0.9 × 1.5 | 0.05 | 8 | Farmhand: farmhand in a green cap, red shirt and brown dungarees, facing the camera, tilting a watering can. |
| `character_worker1_down_can2` | 115 × 192 | 0.9 × 1.5 | 0.05 | 8 | Farmhand: farmhand in a green cap, red shirt and brown dungarees, facing the camera, pouring from a watering can. |
| `character_worker1_down_hands1` | 115 × 192 | 0.9 × 1.5 | 0.05 | 8 | Farmhand: farmhand in a green cap, red shirt and brown dungarees, facing the camera, bending down to the ground. |
| `character_worker1_down_hands2` | 115 × 192 | 0.9 × 1.5 | 0.05 | 8 | Farmhand: farmhand in a green cap, red shirt and brown dungarees, facing the camera, picking something up / sowing. |
| `character_worker1_up_idle` | 115 × 192 | 0.9 × 1.5 | 0.05 | 8 | Farmhand: farmhand in a green cap, red shirt and brown dungarees, seen from behind, standing relaxed. |
| `character_worker1_up_walk1` | 115 × 192 | 0.9 × 1.5 | 0.05 | 8 | Farmhand: farmhand in a green cap, red shirt and brown dungarees, seen from behind, walking, left foot forward. |
| `character_worker1_up_walk2` | 115 × 192 | 0.9 × 1.5 | 0.05 | 8 | Farmhand: farmhand in a green cap, red shirt and brown dungarees, seen from behind, walking, right foot forward. |
| `character_worker1_up_can1` | 115 × 192 | 0.9 × 1.5 | 0.05 | 8 | Farmhand: farmhand in a green cap, red shirt and brown dungarees, seen from behind, tilting a watering can. |
| `character_worker1_up_can2` | 115 × 192 | 0.9 × 1.5 | 0.05 | 8 | Farmhand: farmhand in a green cap, red shirt and brown dungarees, seen from behind, pouring from a watering can. |
| `character_worker1_up_hands1` | 115 × 192 | 0.9 × 1.5 | 0.05 | 8 | Farmhand: farmhand in a green cap, red shirt and brown dungarees, seen from behind, bending down to the ground. |
| `character_worker1_up_hands2` | 115 × 192 | 0.9 × 1.5 | 0.05 | 8 | Farmhand: farmhand in a green cap, red shirt and brown dungarees, seen from behind, picking something up / sowing. |
| `character_worker1_side_idle` | 115 × 192 | 0.9 × 1.5 | 0.05 | 8 | Farmhand: farmhand in a green cap, red shirt and brown dungarees, facing left (mirrored for right), standing relaxed. |
| `character_worker1_side_walk1` | 115 × 192 | 0.9 × 1.5 | 0.05 | 8 | Farmhand: farmhand in a green cap, red shirt and brown dungarees, facing left (mirrored for right), walking, left foot forward. |
| `character_worker1_side_walk2` | 115 × 192 | 0.9 × 1.5 | 0.05 | 8 | Farmhand: farmhand in a green cap, red shirt and brown dungarees, facing left (mirrored for right), walking, right foot forward. |
| `character_worker1_side_can1` | 115 × 192 | 0.9 × 1.5 | 0.05 | 8 | Farmhand: farmhand in a green cap, red shirt and brown dungarees, facing left (mirrored for right), tilting a watering can. |
| `character_worker1_side_can2` | 115 × 192 | 0.9 × 1.5 | 0.05 | 8 | Farmhand: farmhand in a green cap, red shirt and brown dungarees, facing left (mirrored for right), pouring from a watering can. |
| `character_worker1_side_hands1` | 115 × 192 | 0.9 × 1.5 | 0.05 | 8 | Farmhand: farmhand in a green cap, red shirt and brown dungarees, facing left (mirrored for right), bending down to the ground. |
| `character_worker1_side_hands2` | 115 × 192 | 0.9 × 1.5 | 0.05 | 8 | Farmhand: farmhand in a green cap, red shirt and brown dungarees, facing left (mirrored for right), picking something up / sowing. |
| `character_worker2_down_idle` | 115 × 192 | 0.9 × 1.5 | 0.05 | 8 | Farmhand: farmhand with a blond ponytail, blue shirt and green dungarees, facing the camera, standing relaxed. |
| `character_worker2_down_walk1` | 115 × 192 | 0.9 × 1.5 | 0.05 | 8 | Farmhand: farmhand with a blond ponytail, blue shirt and green dungarees, facing the camera, walking, left foot forward. |
| `character_worker2_down_walk2` | 115 × 192 | 0.9 × 1.5 | 0.05 | 8 | Farmhand: farmhand with a blond ponytail, blue shirt and green dungarees, facing the camera, walking, right foot forward. |
| `character_worker2_down_can1` | 115 × 192 | 0.9 × 1.5 | 0.05 | 8 | Farmhand: farmhand with a blond ponytail, blue shirt and green dungarees, facing the camera, tilting a watering can. |
| `character_worker2_down_can2` | 115 × 192 | 0.9 × 1.5 | 0.05 | 8 | Farmhand: farmhand with a blond ponytail, blue shirt and green dungarees, facing the camera, pouring from a watering can. |
| `character_worker2_down_hands1` | 115 × 192 | 0.9 × 1.5 | 0.05 | 8 | Farmhand: farmhand with a blond ponytail, blue shirt and green dungarees, facing the camera, bending down to the ground. |
| `character_worker2_down_hands2` | 115 × 192 | 0.9 × 1.5 | 0.05 | 8 | Farmhand: farmhand with a blond ponytail, blue shirt and green dungarees, facing the camera, picking something up / sowing. |
| `character_worker2_up_idle` | 115 × 192 | 0.9 × 1.5 | 0.05 | 8 | Farmhand: farmhand with a blond ponytail, blue shirt and green dungarees, seen from behind, standing relaxed. |
| `character_worker2_up_walk1` | 115 × 192 | 0.9 × 1.5 | 0.05 | 8 | Farmhand: farmhand with a blond ponytail, blue shirt and green dungarees, seen from behind, walking, left foot forward. |
| `character_worker2_up_walk2` | 115 × 192 | 0.9 × 1.5 | 0.05 | 8 | Farmhand: farmhand with a blond ponytail, blue shirt and green dungarees, seen from behind, walking, right foot forward. |
| `character_worker2_up_can1` | 115 × 192 | 0.9 × 1.5 | 0.05 | 8 | Farmhand: farmhand with a blond ponytail, blue shirt and green dungarees, seen from behind, tilting a watering can. |
| `character_worker2_up_can2` | 115 × 192 | 0.9 × 1.5 | 0.05 | 8 | Farmhand: farmhand with a blond ponytail, blue shirt and green dungarees, seen from behind, pouring from a watering can. |
| `character_worker2_up_hands1` | 115 × 192 | 0.9 × 1.5 | 0.05 | 8 | Farmhand: farmhand with a blond ponytail, blue shirt and green dungarees, seen from behind, bending down to the ground. |
| `character_worker2_up_hands2` | 115 × 192 | 0.9 × 1.5 | 0.05 | 8 | Farmhand: farmhand with a blond ponytail, blue shirt and green dungarees, seen from behind, picking something up / sowing. |
| `character_worker2_side_idle` | 115 × 192 | 0.9 × 1.5 | 0.05 | 8 | Farmhand: farmhand with a blond ponytail, blue shirt and green dungarees, facing left (mirrored for right), standing relaxed. |
| `character_worker2_side_walk1` | 115 × 192 | 0.9 × 1.5 | 0.05 | 8 | Farmhand: farmhand with a blond ponytail, blue shirt and green dungarees, facing left (mirrored for right), walking, left foot forward. |
| `character_worker2_side_walk2` | 115 × 192 | 0.9 × 1.5 | 0.05 | 8 | Farmhand: farmhand with a blond ponytail, blue shirt and green dungarees, facing left (mirrored for right), walking, right foot forward. |
| `character_worker2_side_can1` | 115 × 192 | 0.9 × 1.5 | 0.05 | 8 | Farmhand: farmhand with a blond ponytail, blue shirt and green dungarees, facing left (mirrored for right), tilting a watering can. |
| `character_worker2_side_can2` | 115 × 192 | 0.9 × 1.5 | 0.05 | 8 | Farmhand: farmhand with a blond ponytail, blue shirt and green dungarees, facing left (mirrored for right), pouring from a watering can. |
| `character_worker2_side_hands1` | 115 × 192 | 0.9 × 1.5 | 0.05 | 8 | Farmhand: farmhand with a blond ponytail, blue shirt and green dungarees, facing left (mirrored for right), bending down to the ground. |
| `character_worker2_side_hands2` | 115 × 192 | 0.9 × 1.5 | 0.05 | 8 | Farmhand: farmhand with a blond ponytail, blue shirt and green dungarees, facing left (mirrored for right), picking something up / sowing. |
| `character_worker3_down_idle` | 115 × 192 | 0.9 × 1.5 | 0.05 | 8 | Farmhand: farmhand with a beard, straw hat, white shirt and denim dungarees, facing the camera, standing relaxed. |
| `character_worker3_down_walk1` | 115 × 192 | 0.9 × 1.5 | 0.05 | 8 | Farmhand: farmhand with a beard, straw hat, white shirt and denim dungarees, facing the camera, walking, left foot forward. |
| `character_worker3_down_walk2` | 115 × 192 | 0.9 × 1.5 | 0.05 | 8 | Farmhand: farmhand with a beard, straw hat, white shirt and denim dungarees, facing the camera, walking, right foot forward. |
| `character_worker3_down_can1` | 115 × 192 | 0.9 × 1.5 | 0.05 | 8 | Farmhand: farmhand with a beard, straw hat, white shirt and denim dungarees, facing the camera, tilting a watering can. |
| `character_worker3_down_can2` | 115 × 192 | 0.9 × 1.5 | 0.05 | 8 | Farmhand: farmhand with a beard, straw hat, white shirt and denim dungarees, facing the camera, pouring from a watering can. |
| `character_worker3_down_hands1` | 115 × 192 | 0.9 × 1.5 | 0.05 | 8 | Farmhand: farmhand with a beard, straw hat, white shirt and denim dungarees, facing the camera, bending down to the ground. |
| `character_worker3_down_hands2` | 115 × 192 | 0.9 × 1.5 | 0.05 | 8 | Farmhand: farmhand with a beard, straw hat, white shirt and denim dungarees, facing the camera, picking something up / sowing. |
| `character_worker3_up_idle` | 115 × 192 | 0.9 × 1.5 | 0.05 | 8 | Farmhand: farmhand with a beard, straw hat, white shirt and denim dungarees, seen from behind, standing relaxed. |
| `character_worker3_up_walk1` | 115 × 192 | 0.9 × 1.5 | 0.05 | 8 | Farmhand: farmhand with a beard, straw hat, white shirt and denim dungarees, seen from behind, walking, left foot forward. |
| `character_worker3_up_walk2` | 115 × 192 | 0.9 × 1.5 | 0.05 | 8 | Farmhand: farmhand with a beard, straw hat, white shirt and denim dungarees, seen from behind, walking, right foot forward. |
| `character_worker3_up_can1` | 115 × 192 | 0.9 × 1.5 | 0.05 | 8 | Farmhand: farmhand with a beard, straw hat, white shirt and denim dungarees, seen from behind, tilting a watering can. |
| `character_worker3_up_can2` | 115 × 192 | 0.9 × 1.5 | 0.05 | 8 | Farmhand: farmhand with a beard, straw hat, white shirt and denim dungarees, seen from behind, pouring from a watering can. |
| `character_worker3_up_hands1` | 115 × 192 | 0.9 × 1.5 | 0.05 | 8 | Farmhand: farmhand with a beard, straw hat, white shirt and denim dungarees, seen from behind, bending down to the ground. |
| `character_worker3_up_hands2` | 115 × 192 | 0.9 × 1.5 | 0.05 | 8 | Farmhand: farmhand with a beard, straw hat, white shirt and denim dungarees, seen from behind, picking something up / sowing. |
| `character_worker3_side_idle` | 115 × 192 | 0.9 × 1.5 | 0.05 | 8 | Farmhand: farmhand with a beard, straw hat, white shirt and denim dungarees, facing left (mirrored for right), standing relaxed. |
| `character_worker3_side_walk1` | 115 × 192 | 0.9 × 1.5 | 0.05 | 8 | Farmhand: farmhand with a beard, straw hat, white shirt and denim dungarees, facing left (mirrored for right), walking, left foot forward. |
| `character_worker3_side_walk2` | 115 × 192 | 0.9 × 1.5 | 0.05 | 8 | Farmhand: farmhand with a beard, straw hat, white shirt and denim dungarees, facing left (mirrored for right), walking, right foot forward. |
| `character_worker3_side_can1` | 115 × 192 | 0.9 × 1.5 | 0.05 | 8 | Farmhand: farmhand with a beard, straw hat, white shirt and denim dungarees, facing left (mirrored for right), tilting a watering can. |
| `character_worker3_side_can2` | 115 × 192 | 0.9 × 1.5 | 0.05 | 8 | Farmhand: farmhand with a beard, straw hat, white shirt and denim dungarees, facing left (mirrored for right), pouring from a watering can. |
| `character_worker3_side_hands1` | 115 × 192 | 0.9 × 1.5 | 0.05 | 8 | Farmhand: farmhand with a beard, straw hat, white shirt and denim dungarees, facing left (mirrored for right), bending down to the ground. |
| `character_worker3_side_hands2` | 115 × 192 | 0.9 × 1.5 | 0.05 | 8 | Farmhand: farmhand with a beard, straw hat, white shirt and denim dungarees, facing left (mirrored for right), picking something up / sowing. |
| `character_villager1_down_idle` | 115 × 192 | 0.9 × 1.5 | 0.05 | 7 | Villager: young woman with dark hair in a teal blouse and brown trousers, facing the camera, standing relaxed. |
| `character_villager1_down_walk1` | 115 × 192 | 0.9 × 1.5 | 0.05 | 7 | Villager: young woman with dark hair in a teal blouse and brown trousers, facing the camera, walking, left foot forward. |
| `character_villager1_down_walk2` | 115 × 192 | 0.9 × 1.5 | 0.05 | 7 | Villager: young woman with dark hair in a teal blouse and brown trousers, facing the camera, walking, right foot forward. |
| `character_villager1_up_idle` | 115 × 192 | 0.9 × 1.5 | 0.05 | 7 | Villager: young woman with dark hair in a teal blouse and brown trousers, seen from behind, standing relaxed. |
| `character_villager1_up_walk1` | 115 × 192 | 0.9 × 1.5 | 0.05 | 7 | Villager: young woman with dark hair in a teal blouse and brown trousers, seen from behind, walking, left foot forward. |
| `character_villager1_up_walk2` | 115 × 192 | 0.9 × 1.5 | 0.05 | 7 | Villager: young woman with dark hair in a teal blouse and brown trousers, seen from behind, walking, right foot forward. |
| `character_villager1_side_idle` | 115 × 192 | 0.9 × 1.5 | 0.05 | 7 | Villager: young woman with dark hair in a teal blouse and brown trousers, facing left (mirrored for right), standing relaxed. |
| `character_villager1_side_walk1` | 115 × 192 | 0.9 × 1.5 | 0.05 | 7 | Villager: young woman with dark hair in a teal blouse and brown trousers, facing left (mirrored for right), walking, left foot forward. |
| `character_villager1_side_walk2` | 115 × 192 | 0.9 × 1.5 | 0.05 | 7 | Villager: young woman with dark hair in a teal blouse and brown trousers, facing left (mirrored for right), walking, right foot forward. |
| `character_villager2_down_idle` | 115 × 192 | 0.9 × 1.5 | 0.05 | 7 | Villager: man in a red cap, mustard shirt and blue jeans, facing the camera, standing relaxed. |
| `character_villager2_down_walk1` | 115 × 192 | 0.9 × 1.5 | 0.05 | 7 | Villager: man in a red cap, mustard shirt and blue jeans, facing the camera, walking, left foot forward. |
| `character_villager2_down_walk2` | 115 × 192 | 0.9 × 1.5 | 0.05 | 7 | Villager: man in a red cap, mustard shirt and blue jeans, facing the camera, walking, right foot forward. |
| `character_villager2_up_idle` | 115 × 192 | 0.9 × 1.5 | 0.05 | 7 | Villager: man in a red cap, mustard shirt and blue jeans, seen from behind, standing relaxed. |
| `character_villager2_up_walk1` | 115 × 192 | 0.9 × 1.5 | 0.05 | 7 | Villager: man in a red cap, mustard shirt and blue jeans, seen from behind, walking, left foot forward. |
| `character_villager2_up_walk2` | 115 × 192 | 0.9 × 1.5 | 0.05 | 7 | Villager: man in a red cap, mustard shirt and blue jeans, seen from behind, walking, right foot forward. |
| `character_villager2_side_idle` | 115 × 192 | 0.9 × 1.5 | 0.05 | 7 | Villager: man in a red cap, mustard shirt and blue jeans, facing left (mirrored for right), standing relaxed. |
| `character_villager2_side_walk1` | 115 × 192 | 0.9 × 1.5 | 0.05 | 7 | Villager: man in a red cap, mustard shirt and blue jeans, facing left (mirrored for right), walking, left foot forward. |
| `character_villager2_side_walk2` | 115 × 192 | 0.9 × 1.5 | 0.05 | 7 | Villager: man in a red cap, mustard shirt and blue jeans, facing left (mirrored for right), walking, right foot forward. |
| `character_villager3_down_idle` | 115 × 192 | 0.9 × 1.5 | 0.05 | 7 | Villager: white-haired grandmother in a lavender cardigan and grey skirt, facing the camera, standing relaxed. |
| `character_villager3_down_walk1` | 115 × 192 | 0.9 × 1.5 | 0.05 | 7 | Villager: white-haired grandmother in a lavender cardigan and grey skirt, facing the camera, walking, left foot forward. |
| `character_villager3_down_walk2` | 115 × 192 | 0.9 × 1.5 | 0.05 | 7 | Villager: white-haired grandmother in a lavender cardigan and grey skirt, facing the camera, walking, right foot forward. |
| `character_villager3_up_idle` | 115 × 192 | 0.9 × 1.5 | 0.05 | 7 | Villager: white-haired grandmother in a lavender cardigan and grey skirt, seen from behind, standing relaxed. |
| `character_villager3_up_walk1` | 115 × 192 | 0.9 × 1.5 | 0.05 | 7 | Villager: white-haired grandmother in a lavender cardigan and grey skirt, seen from behind, walking, left foot forward. |
| `character_villager3_up_walk2` | 115 × 192 | 0.9 × 1.5 | 0.05 | 7 | Villager: white-haired grandmother in a lavender cardigan and grey skirt, seen from behind, walking, right foot forward. |
| `character_villager3_side_idle` | 115 × 192 | 0.9 × 1.5 | 0.05 | 7 | Villager: white-haired grandmother in a lavender cardigan and grey skirt, facing left (mirrored for right), standing relaxed. |
| `character_villager3_side_walk1` | 115 × 192 | 0.9 × 1.5 | 0.05 | 7 | Villager: white-haired grandmother in a lavender cardigan and grey skirt, facing left (mirrored for right), walking, left foot forward. |
| `character_villager3_side_walk2` | 115 × 192 | 0.9 × 1.5 | 0.05 | 7 | Villager: white-haired grandmother in a lavender cardigan and grey skirt, facing left (mirrored for right), walking, right foot forward. |

## Animals

| Name | Pixels | World size (tiles) | Anchor | Phase | Description |
|---|---|---|---|---:|---|
| `animal_chicken_idle` | 77 × 77 | 0.6 × 0.6 | 0.1 | 4 | Brown hen, idle, facing left (mirrored in code for right). |
| `animal_chicken_walk1` | 77 × 77 | 0.6 × 0.6 | 0.1 | 4 | Brown hen, walk1, facing left (mirrored in code for right). |
| `animal_chicken_walk2` | 77 × 77 | 0.6 × 0.6 | 0.1 | 4 | Brown hen, walk2, facing left (mirrored in code for right). |
| `animal_chicken_eat` | 77 × 77 | 0.6 × 0.6 | 0.1 | 4 | Brown hen, eat, facing left (mirrored in code for right). |
| `animal_chicken_sleep` | 77 × 77 | 0.6 × 0.6 | 0.1 | 4 | Brown hen, sleep, facing left (mirrored in code for right). |
| `animal_chick_idle` | 45 × 45 | 0.35 × 0.35 | 0.1 | 4 | Fluffy yellow chick, idle, facing left (mirrored in code for right). |
| `animal_chick_walk1` | 45 × 45 | 0.35 × 0.35 | 0.1 | 4 | Fluffy yellow chick, walk1, facing left (mirrored in code for right). |
| `animal_chick_walk2` | 45 × 45 | 0.35 × 0.35 | 0.1 | 4 | Fluffy yellow chick, walk2, facing left (mirrored in code for right). |
| `animal_chick_eat` | 45 × 45 | 0.35 × 0.35 | 0.1 | 4 | Fluffy yellow chick, eat, facing left (mirrored in code for right). |
| `animal_chick_sleep` | 45 × 45 | 0.35 × 0.35 | 0.1 | 4 | Fluffy yellow chick, sleep, facing left (mirrored in code for right). |
| `animal_cow_idle` | 256 × 205 | 2 × 1.6 | 0.1 | 4 | Brown and white dairy cow, idle, facing left (mirrored in code for right). |
| `animal_cow_walk1` | 256 × 205 | 2 × 1.6 | 0.1 | 4 | Brown and white dairy cow, walk1, facing left (mirrored in code for right). |
| `animal_cow_walk2` | 256 × 205 | 2 × 1.6 | 0.1 | 4 | Brown and white dairy cow, walk2, facing left (mirrored in code for right). |
| `animal_cow_eat` | 256 × 205 | 2 × 1.6 | 0.1 | 4 | Brown and white dairy cow, eat, facing left (mirrored in code for right). |
| `animal_cow_sleep` | 256 × 205 | 2 × 1.6 | 0.1 | 4 | Brown and white dairy cow, sleep, facing left (mirrored in code for right). |
| `animal_calf_idle` | 166 × 141 | 1.3 × 1.1 | 0.1 | 4 | Calf, idle, facing left (mirrored in code for right). |
| `animal_calf_walk1` | 166 × 141 | 1.3 × 1.1 | 0.1 | 4 | Calf, walk1, facing left (mirrored in code for right). |
| `animal_calf_walk2` | 166 × 141 | 1.3 × 1.1 | 0.1 | 4 | Calf, walk2, facing left (mirrored in code for right). |
| `animal_calf_eat` | 166 × 141 | 1.3 × 1.1 | 0.1 | 4 | Calf, eat, facing left (mirrored in code for right). |
| `animal_calf_sleep` | 166 × 141 | 1.3 × 1.1 | 0.1 | 4 | Calf, sleep, facing left (mirrored in code for right). |
| `animal_sheep_idle` | 166 × 141 | 1.3 × 1.1 | 0.1 | 4 | Woolly cream sheep, idle, facing left (mirrored in code for right). |
| `animal_sheep_walk1` | 166 × 141 | 1.3 × 1.1 | 0.1 | 4 | Woolly cream sheep, walk1, facing left (mirrored in code for right). |
| `animal_sheep_walk2` | 166 × 141 | 1.3 × 1.1 | 0.1 | 4 | Woolly cream sheep, walk2, facing left (mirrored in code for right). |
| `animal_sheep_eat` | 166 × 141 | 1.3 × 1.1 | 0.1 | 4 | Woolly cream sheep, eat, facing left (mirrored in code for right). |
| `animal_sheep_sleep` | 166 × 141 | 1.3 × 1.1 | 0.1 | 4 | Woolly cream sheep, sleep, facing left (mirrored in code for right). |
| `animal_sheep_sheared_idle` | 154 × 128 | 1.2 × 1 | 0.1 | 4 | Freshly sheared sheep, slim, idle, facing left (mirrored in code for right). |
| `animal_sheep_sheared_walk1` | 154 × 128 | 1.2 × 1 | 0.1 | 4 | Freshly sheared sheep, slim, walk1, facing left (mirrored in code for right). |
| `animal_sheep_sheared_walk2` | 154 × 128 | 1.2 × 1 | 0.1 | 4 | Freshly sheared sheep, slim, walk2, facing left (mirrored in code for right). |
| `animal_sheep_sheared_eat` | 154 × 128 | 1.2 × 1 | 0.1 | 4 | Freshly sheared sheep, slim, eat, facing left (mirrored in code for right). |
| `animal_sheep_sheared_sleep` | 154 × 128 | 1.2 × 1 | 0.1 | 4 | Freshly sheared sheep, slim, sleep, facing left (mirrored in code for right). |
| `animal_lamb_idle` | 115 × 102 | 0.9 × 0.8 | 0.1 | 4 | Lamb, idle, facing left (mirrored in code for right). |
| `animal_lamb_walk1` | 115 × 102 | 0.9 × 0.8 | 0.1 | 4 | Lamb, walk1, facing left (mirrored in code for right). |
| `animal_lamb_walk2` | 115 × 102 | 0.9 × 0.8 | 0.1 | 4 | Lamb, walk2, facing left (mirrored in code for right). |
| `animal_lamb_eat` | 115 × 102 | 0.9 × 0.8 | 0.1 | 4 | Lamb, eat, facing left (mirrored in code for right). |
| `animal_lamb_sleep` | 115 × 102 | 0.9 × 0.8 | 0.1 | 4 | Lamb, sleep, facing left (mirrored in code for right). |
| `animal_pig_idle` | 166 × 128 | 1.3 × 1 | 0.1 | 4 | Pink pig with a muddy belly, idle, facing left (mirrored in code for right). |
| `animal_pig_walk1` | 166 × 128 | 1.3 × 1 | 0.1 | 4 | Pink pig with a muddy belly, walk1, facing left (mirrored in code for right). |
| `animal_pig_walk2` | 166 × 128 | 1.3 × 1 | 0.1 | 4 | Pink pig with a muddy belly, walk2, facing left (mirrored in code for right). |
| `animal_pig_eat` | 166 × 128 | 1.3 × 1 | 0.1 | 4 | Pink pig with a muddy belly, eat, facing left (mirrored in code for right). |
| `animal_pig_sleep` | 166 × 128 | 1.3 × 1 | 0.1 | 4 | Pink pig with a muddy belly, sleep, facing left (mirrored in code for right). |
| `animal_piglet_idle` | 90 × 70 | 0.7 × 0.55 | 0.1 | 4 | Piglet, idle, facing left (mirrored in code for right). |
| `animal_piglet_walk1` | 90 × 70 | 0.7 × 0.55 | 0.1 | 4 | Piglet, walk1, facing left (mirrored in code for right). |
| `animal_piglet_walk2` | 90 × 70 | 0.7 × 0.55 | 0.1 | 4 | Piglet, walk2, facing left (mirrored in code for right). |
| `animal_piglet_eat` | 90 × 70 | 0.7 × 0.55 | 0.1 | 4 | Piglet, eat, facing left (mirrored in code for right). |
| `animal_piglet_sleep` | 90 × 70 | 0.7 × 0.55 | 0.1 | 4 | Piglet, sleep, facing left (mirrored in code for right). |
| `animal_goat_idle` | 154 × 141 | 1.2 × 1.1 | 0.1 | 7 | White goat with small horns, idle, facing left (mirrored in code for right). |
| `animal_goat_walk1` | 154 × 141 | 1.2 × 1.1 | 0.1 | 7 | White goat with small horns, walk1, facing left (mirrored in code for right). |
| `animal_goat_walk2` | 154 × 141 | 1.2 × 1.1 | 0.1 | 7 | White goat with small horns, walk2, facing left (mirrored in code for right). |
| `animal_goat_eat` | 154 × 141 | 1.2 × 1.1 | 0.1 | 7 | White goat with small horns, eat, facing left (mirrored in code for right). |
| `animal_goat_sleep` | 154 × 141 | 1.2 × 1.1 | 0.1 | 7 | White goat with small horns, sleep, facing left (mirrored in code for right). |
| `animal_goat_kid_idle` | 102 × 90 | 0.8 × 0.7 | 0.1 | 7 | Goat kid, idle, facing left (mirrored in code for right). |
| `animal_goat_kid_walk1` | 102 × 90 | 0.8 × 0.7 | 0.1 | 7 | Goat kid, walk1, facing left (mirrored in code for right). |
| `animal_goat_kid_walk2` | 102 × 90 | 0.8 × 0.7 | 0.1 | 7 | Goat kid, walk2, facing left (mirrored in code for right). |
| `animal_goat_kid_eat` | 102 × 90 | 0.8 × 0.7 | 0.1 | 7 | Goat kid, eat, facing left (mirrored in code for right). |
| `animal_goat_kid_sleep` | 102 × 90 | 0.8 × 0.7 | 0.1 | 7 | Goat kid, sleep, facing left (mirrored in code for right). |
| `animal_horse_idle` | 282 × 256 | 2.2 × 2 | 0.1 | 7 | Chestnut horse, idle, facing left (mirrored in code for right). |
| `animal_horse_walk1` | 282 × 256 | 2.2 × 2 | 0.1 | 7 | Chestnut horse, walk1, facing left (mirrored in code for right). |
| `animal_horse_walk2` | 282 × 256 | 2.2 × 2 | 0.1 | 7 | Chestnut horse, walk2, facing left (mirrored in code for right). |
| `animal_horse_eat` | 282 × 256 | 2.2 × 2 | 0.1 | 7 | Chestnut horse, eat, facing left (mirrored in code for right). |
| `animal_horse_sleep` | 282 × 256 | 2.2 × 2 | 0.1 | 7 | Chestnut horse, sleep, facing left (mirrored in code for right). |
| `animal_foal_idle` | 179 × 166 | 1.4 × 1.3 | 0.1 | 7 | Foal, idle, facing left (mirrored in code for right). |
| `animal_foal_walk1` | 179 × 166 | 1.4 × 1.3 | 0.1 | 7 | Foal, walk1, facing left (mirrored in code for right). |
| `animal_foal_walk2` | 179 × 166 | 1.4 × 1.3 | 0.1 | 7 | Foal, walk2, facing left (mirrored in code for right). |
| `animal_foal_eat` | 179 × 166 | 1.4 × 1.3 | 0.1 | 7 | Foal, eat, facing left (mirrored in code for right). |
| `animal_foal_sleep` | 179 × 166 | 1.4 × 1.3 | 0.1 | 7 | Foal, sleep, facing left (mirrored in code for right). |
| `animal_dog_idle` | 115 × 102 | 0.9 × 0.8 | 0.1 | 8 | The farm dog, a scruffy friendly mutt, idle, facing left (mirrored in code for right). |
| `animal_dog_walk1` | 115 × 102 | 0.9 × 0.8 | 0.1 | 8 | The farm dog, a scruffy friendly mutt, walk1, facing left (mirrored in code for right). |
| `animal_dog_walk2` | 115 × 102 | 0.9 × 0.8 | 0.1 | 8 | The farm dog, a scruffy friendly mutt, walk2, facing left (mirrored in code for right). |
| `animal_dog_eat` | 115 × 102 | 0.9 × 0.8 | 0.1 | 8 | The farm dog, a scruffy friendly mutt, eat, facing left (mirrored in code for right). |
| `animal_dog_sleep` | 115 × 102 | 0.9 × 0.8 | 0.1 | 8 | The farm dog, a scruffy friendly mutt, sleep, facing left (mirrored in code for right). |

## Item icons

| Name | Pixels | World size (tiles) | Anchor | Phase | Description |
|---|---|---|---|---:|---|
| `item_wheat` | 132 × 132 | UI | — | 2 | A bundle of golden wheat ears tied with twine. Inventory icon. |
| `item_seeds_wheat` | 132 × 132 | UI | — | 2 | Paper seed packet with a picture of wheat on it. |
| `item_carrot` | 132 × 132 | UI | — | 2 | Two fresh carrots with green tops. Inventory icon. |
| `item_seeds_carrot` | 132 × 132 | UI | — | 2 | Paper seed packet with a picture of carrots on it. |
| `item_potato` | 132 × 132 | UI | — | 2 | Three earthy potatoes. Inventory icon. |
| `item_seeds_potato` | 132 × 132 | UI | — | 2 | Paper seed packet with a picture of potatoes on it. |
| `item_strawberry` | 132 × 132 | UI | — | 2 | Two glossy red strawberries. Inventory icon. |
| `item_seeds_strawberry` | 132 × 132 | UI | — | 2 | Paper seed packet with a picture of strawberries on it. |
| `item_corn` | 132 × 132 | UI | — | 2 | An ear of corn with the husk pulled back. Inventory icon. |
| `item_seeds_corn` | 132 × 132 | UI | — | 2 | Paper seed packet with a picture of corn on it. |
| `item_pumpkin` | 132 × 132 | UI | — | 2 | A round orange pumpkin with a curly stem. Inventory icon. |
| `item_seeds_pumpkin` | 132 × 132 | UI | — | 2 | Paper seed packet with a picture of pumpkins on it. |
| `item_lettuce` | 132 × 132 | UI | — | 2 | A crisp green lettuce head. Inventory icon. |
| `item_seeds_lettuce` | 132 × 132 | UI | — | 2 | Paper seed packet with a picture of lettuce on it. |
| `item_onion` | 132 × 132 | UI | — | 2 | Two golden onions with papery skins. Inventory icon. |
| `item_seeds_onion` | 132 × 132 | UI | — | 2 | Paper seed packet with a picture of onions on it. |
| `item_kale` | 132 × 132 | UI | — | 2 | A bunch of curly dark-green kale. Inventory icon. |
| `item_seeds_kale` | 132 × 132 | UI | — | 2 | Paper seed packet with a picture of kale on it. |
| `item_tomato` | 132 × 132 | UI | — | 2 | Two ripe red tomatoes. Inventory icon. |
| `item_seeds_tomato` | 132 × 132 | UI | — | 2 | Paper seed packet with a picture of tomatoes on it. |
| `item_garlic` | 132 × 132 | UI | — | 2 | A plump white garlic bulb. Inventory icon. |
| `item_seeds_garlic` | 132 × 132 | UI | — | 2 | Paper seed packet with a picture of garlic on it. |
| `item_sunflower` | 132 × 132 | UI | — | 2 | A sunflower head, bright petals around dark seeds. Inventory icon. |
| `item_seeds_sunflower` | 132 × 132 | UI | — | 2 | Paper seed packet with a picture of sunflowers on it. |
| `item_blueberry` | 132 × 132 | UI | — | 2 | A cluster of dusty blue blueberries. Inventory icon. |
| `item_seeds_blueberry` | 132 × 132 | UI | — | 2 | Paper seed packet with a picture of blueberries on it. |
| `item_cabbage` | 132 × 132 | UI | — | 2 | A round pale-green cabbage. Inventory icon. |
| `item_seeds_cabbage` | 132 × 132 | UI | — | 2 | Paper seed packet with a picture of cabbages on it. |
| `item_melon` | 132 × 132 | UI | — | 2 | A striped green melon with a juicy slice. Inventory icon. |
| `item_seeds_melon` | 132 × 132 | UI | — | 2 | Paper seed packet with a picture of melons on it. |
| `item_egg` | 132 × 132 | UI | — | 4 | Brown egg, inventory icon. |
| `item_milk` | 132 × 132 | UI | — | 4 | Glass bottle of milk, inventory icon. |
| `item_wool` | 132 × 132 | UI | — | 4 | Ball of cream wool, inventory icon. |
| `item_truffle` | 132 × 132 | UI | — | 4 | Black truffle (pigs dig them up), inventory icon. |
| `item_honey` | 132 × 132 | UI | — | 7 | Jar of golden honey, inventory icon. |
| `item_goat_milk` | 132 × 132 | UI | — | 7 | Small jug of goat milk, inventory icon. |
| `item_log` | 132 × 132 | UI | — | 4 | Cut log, inventory icon. |
| `item_log_maple` | 132 × 132 | UI | — | 6 | Rare maple log, reddish, inventory icon. |
| `item_plank` | 132 × 132 | UI | — | 6 | Stack of planks, inventory icon. |
| `item_flour` | 132 × 132 | UI | — | 6 | Sack of flour, inventory icon. |
| `item_cheese` | 132 × 132 | UI | — | 6 | Wheel of cheese, inventory icon. |
| `item_juice` | 132 × 132 | UI | — | 6 | Bottle of juice, inventory icon. |
| `item_apple` | 132 × 132 | UI | — | 4 | Red apple, inventory icon. |
| `item_cherry` | 132 × 132 | UI | — | 4 | Pair of cherries, inventory icon. |
| `item_fertilizer` | 132 × 132 | UI | — | 7 | Bag of fertilizer, inventory icon. |
| `item_animal_feed` | 132 × 132 | UI | — | 4 | Sack of animal feed, inventory icon. |
| `item_sprinkler` | 132 × 132 | UI | — | 8 | Brass sprinkler head on a short stake, inventory icon. |
| `item_sprinkler_pro` | 132 × 132 | UI | — | 8 | Big rotating sprinkler, green and brass, inventory icon. |
| `item_cornmeal` | 132 × 132 | UI | — | 10 | Cornmeal, inventory icon. |
| `item_strawberry_jam` | 132 × 132 | UI | — | 10 | Strawberry jam, inventory icon. |
| `item_tomato_sauce` | 132 × 132 | UI | — | 10 | Tomato sauce, inventory icon. |
| `item_blueberry_jam` | 132 × 132 | UI | — | 10 | Blueberry jam, inventory icon. |
| `item_blackberry_jam` | 132 × 132 | UI | — | 10 | Blackberry jam, inventory icon. |
| `item_elderflower_cordial` | 132 × 132 | UI | — | 10 | Elderflower cordial, inventory icon. |
| `item_chamomile_tea` | 132 × 132 | UI | — | 10 | Chamomile tea, inventory icon. |
| `item_dried_mushrooms` | 132 × 132 | UI | — | 10 | Dried mushrooms, inventory icon. |
| `item_pickled_onions` | 132 × 132 | UI | — | 10 | Pickled onions, inventory icon. |
| `item_sauerkraut` | 132 × 132 | UI | — | 10 | Sauerkraut, inventory icon. |
| `item_goat_cheese` | 132 × 132 | UI | — | 10 | Goat cheese, inventory icon. |
| `item_apple_juice` | 132 × 132 | UI | — | 10 | Apple juice, inventory icon. |
| `item_carrot_juice` | 132 × 132 | UI | — | 10 | Carrot juice, inventory icon. |
| `item_cherry_juice` | 132 × 132 | UI | — | 10 | Cherry juice, inventory icon. |
| `item_sunflower_oil` | 132 × 132 | UI | — | 10 | Sunflower oil, inventory icon. |
| `item_cloth` | 132 × 132 | UI | — | 10 | Cloth, inventory icon. |
| `item_smoked_trout` | 132 × 132 | UI | — | 10 | Smoked trout, inventory icon. |
| `item_smoked_salmon` | 132 × 132 | UI | — | 10 | Smoked salmon, inventory icon. |
| `item_smoked_eel` | 132 × 132 | UI | — | 10 | Smoked eel, inventory icon. |
| `item_sawhorse` | 132 × 132 | UI | — | 10 | Sawhorse (workshop), inventory icon. |
| `item_mill` | 132 × 132 | UI | — | 10 | Hand mill (workshop), inventory icon. |
| `item_beehive` | 132 × 132 | UI | — | 10 | Beehive (workshop), inventory icon. |
| `item_jam_kitchen` | 132 × 132 | UI | — | 10 | Jam kitchen (workshop), inventory icon. |
| `item_drying_rack` | 132 × 132 | UI | — | 10 | Drying rack (workshop), inventory icon. |
| `item_pickling_crock` | 132 × 132 | UI | — | 10 | Pickling crock (workshop), inventory icon. |
| `item_cheese_press` | 132 × 132 | UI | — | 10 | Cheese press (workshop), inventory icon. |
| `item_juice_press` | 132 × 132 | UI | — | 10 | Juice press (workshop), inventory icon. |
| `item_oil_press` | 132 × 132 | UI | — | 10 | Oil press (workshop), inventory icon. |
| `item_loom` | 132 × 132 | UI | — | 10 | Loom (workshop), inventory icon. |
| `item_smokehouse` | 132 × 132 | UI | — | 10 | Smokehouse (workshop), inventory icon. |
| `item_sunfish` | 132 × 132 | UI | — | 11 | Sunfish (fish), side view, inventory icon. |
| `item_carp` | 132 × 132 | UI | — | 11 | Carp (fish), side view, inventory icon. |
| `item_perch` | 132 × 132 | UI | — | 11 | Perch (fish), side view, inventory icon. |
| `item_catfish` | 132 × 132 | UI | — | 11 | Catfish (fish), side view, inventory icon. |
| `item_golden_koi` | 132 × 132 | UI | — | 11 | Golden koi (fish), side view, inventory icon. |
| `item_trout` | 132 × 132 | UI | — | 11 | Trout (fish), side view, inventory icon. |
| `item_bass` | 132 × 132 | UI | — | 11 | Bass (fish), side view, inventory icon. |
| `item_whitefish` | 132 × 132 | UI | — | 11 | Whitefish (fish), side view, inventory icon. |
| `item_pike` | 132 × 132 | UI | — | 11 | Pike (fish), side view, inventory icon. |
| `item_salmon` | 132 × 132 | UI | — | 11 | Salmon (fish), side view, inventory icon. |
| `item_eel` | 132 × 132 | UI | — | 11 | Eel (fish), side view, inventory icon. |
| `item_sturgeon` | 132 × 132 | UI | — | 11 | Sturgeon (fish), side view, inventory icon. |
| `item_wild_garlic` | 132 × 132 | UI | — | 11 | Wild garlic (wild find), inventory icon. |
| `item_daffodil` | 132 × 132 | UI | — | 11 | Daffodil (wild find), inventory icon. |
| `item_morel` | 132 × 132 | UI | — | 11 | Morel (wild find), inventory icon. |
| `item_blackberry` | 132 × 132 | UI | — | 11 | Blackberries (wild find), inventory icon. |
| `item_chamomile` | 132 × 132 | UI | — | 11 | Chamomile (wild find), inventory icon. |
| `item_elderflower` | 132 × 132 | UI | — | 11 | Elderflower (wild find), inventory icon. |
| `item_chanterelle` | 132 × 132 | UI | — | 11 | Chanterelle (wild find), inventory icon. |
| `item_hazelnut` | 132 × 132 | UI | — | 11 | Hazelnuts (wild find), inventory icon. |
| `item_holly` | 132 × 132 | UI | — | 11 | Holly (wild find), inventory icon. |
| `item_pinecone` | 132 × 132 | UI | — | 11 | Pinecone (wild find), inventory icon. |
| `item_snowdrop` | 132 × 132 | UI | — | 11 | Snowdrop (wild find), inventory icon. |
| `item_sapling_oak` | 132 × 132 | UI | — | 4 | Oak sapling in a pot. |
| `item_sapling_birch` | 132 × 132 | UI | — | 4 | Birch sapling in a pot. |
| `item_sapling_pine` | 132 × 132 | UI | — | 4 | Pine sapling in a pot. |
| `item_sapling_maple` | 132 × 132 | UI | — | 4 | Maple sapling in a pot. |
| `item_sapling_apple` | 132 × 132 | UI | — | 4 | Apple sapling in a pot. |
| `item_sapling_cherry` | 132 × 132 | UI | — | 4 | Cherry sapling in a pot. |

## Effects & particles

| Name | Pixels | World size (tiles) | Anchor | Phase | Description |
|---|---|---|---|---:|---|
| `fx_shadow_soft` | 128 × 64 | 1 × 0.5 | — | 1 | Soft black ellipse with blurred edges (used at ~30% opacity under objects). *(flat)* |
| `fx_smoke_puff` | 64 × 64 | 0.5 × 0.5 | — | 1 | Soft grey-white smoke puff (chimneys). |
| `fx_window_glow` | 64 × 64 | 0.5 × 0.5 | — | 1 | Soft warm radial glow. *(additive light)* |
| `fx_tile_highlight` | 128 × 128 | 1 × 1 | — | 1 | Rounded square outline with soft glow: tapped tile. *(flat)* |
| `fx_sparkle` | 38 × 38 | 0.3 × 0.3 | — | 2 | Four-point sparkle (crop ready). |
| `fx_coin` | 38 × 38 | 0.3 × 0.3 | — | 2 | Gold coin that flies to the money counter. |
| `fx_harvest_pop` | 77 × 77 | 0.6 × 0.6 | — | 2 | Burst of leaves and soil when harvesting. |
| `fx_water_drops` | 77 × 77 | 0.6 × 0.6 | — | 2 | Water droplets when watering. |
| `fx_dust_puff` | 64 × 64 | 0.5 × 0.5 | — | 2 | Beige dust puff: plowing, and behind the truck on dirt roads. |
| `fx_guide_arrow` | 102 × 102 | 0.8 × 0.8 | — | 3 | Chunky friendly arrow pointing right (rotated in code): points the way to the next goal. |
| `fx_headlight_cone` | 256 × 384 | 2 × 3 | — | 3 | Soft headlight beam, pointing up, additive. *(additive light)* |
| `fx_wood_chip` | 19 × 19 | 0.15 × 0.15 | — | 4 | Wood chip flying off when chopping. |
| `fx_feather` | 19 × 19 | 0.15 × 0.15 | — | 4 | Small feather. |
| `fx_job_marker` | 64 × 64 | 0.5 × 0.5 | — | 5 | Small round marker with a soft glow: a job the farmer has lined up. |
| `fx_bubble` | 90 × 90 | 0.7 × 0.7 | — | 4 | Round white speech bubble with a small tail at the bottom: shows what an animal has or wants. |
| `fx_bobber` | 38 × 38 | 0.3 × 0.3 | — | 11 | Red and white fishing bobber. |
| `fx_exclaim` | 64 × 64 | 0.5 × 0.5 | — | 11 | Bold '!' in a white speech bubble: a fish bites. |
| `fx_heart` | 38 × 38 | 0.3 × 0.3 | — | 4 | Small heart over a happy animal. |
| `fx_zzz` | 38 × 38 | 0.3 × 0.3 | — | 4 | 'z' for sleeping animals. |
| `fx_bee` | 15 × 15 | 0.12 × 0.12 | — | 7 | Tiny bee. |
| `fx_leaf_green` | 19 × 19 | 0.15 × 0.15 | — | 8 | Falling leaf, green. |
| `fx_leaf_orange` | 19 × 19 | 0.15 × 0.15 | — | 8 | Falling leaf, autumn orange. |
| `fx_blossom_petal` | 13 × 13 | 0.1 × 0.1 | — | 8 | Pink blossom petal (spring). |
| `fx_raindrop` | 6 × 38 | 0.05 × 0.3 | — | 8 | Rain streak. |
| `fx_splash` | 26 × 19 | 0.2 × 0.15 | — | 8 | Tiny rain splash ring. |
| `fx_puddle` | 256 × 128 | 2 × 1 | — | 8 | Rain puddle with sky reflection. *(flat)* |
| `fx_snowflake` | 13 × 13 | 0.1 × 0.1 | — | 8 | Snowflake. |
| `fx_bird_fly1` | 64 × 45 | 0.5 × 0.35 | — | 8 | Small songbird flying, wings up. |
| `fx_bird_fly2` | 64 × 45 | 0.5 × 0.35 | — | 8 | Small songbird flying, wings down. |
| `fx_bird_sit` | 38 × 38 | 0.3 × 0.3 | — | 8 | Small songbird sitting on the ground. |
| `fx_butterfly1` | 26 × 26 | 0.2 × 0.2 | — | 8 | Butterfly, wings open. |
| `fx_butterfly2` | 26 × 26 | 0.2 × 0.2 | — | 8 | Butterfly, wings closed. |
| `fx_firefly` | 13 × 13 | 0.1 × 0.1 | — | 8 | Firefly glow dot (summer nights). *(additive light)* |
| `fx_cloud_shadow` | 1536 × 1024 | 12 × 8 | — | 8 | Very soft cloud shadow drifting over the land. *(flat)* |
| `fx_water_ripple` | 128 × 64 | 1 × 0.5 | — | 8 | Expanding ripple ring on water. *(flat)* |

## User interface

| Name | Pixels | World size (tiles) | Anchor | Phase | Description |
|---|---|---|---|---:|---|
| `ui_app_icon` | 1024 × 1024 | UI | — | 1 | App icon: the little farm at golden hour, truck in front. No transparency. |
| `ui_icon_coin` | 72 × 72 | UI | — | 1 | Gold coin, HUD money counter. |
| `ui_icon_level` | 72 × 72 | UI | — | 1 | Wheat-ear badge for the farmer level. |
| `ui_icon_season_spring` | 72 × 72 | UI | — | 1 | Blossom. |
| `ui_icon_season_summer` | 72 × 72 | UI | — | 1 | Sun. |
| `ui_icon_season_autumn` | 72 × 72 | UI | — | 1 | Maple leaf. |
| `ui_icon_season_winter` | 72 × 72 | UI | — | 1 | Snowflake. |
| `ui_icon_time_morning` | 60 × 60 | UI | — | 1 | Sunrise. |
| `ui_icon_time_day` | 60 × 60 | UI | — | 1 | Sun. |
| `ui_icon_time_evening` | 60 × 60 | UI | — | 1 | Sunset. |
| `ui_icon_time_night` | 60 × 60 | UI | — | 1 | Moon. |
| `ui_icon_inventory` | 96 × 96 | UI | — | 1 | Woven basket (inventory button). |
| `ui_icon_settings` | 84 × 84 | UI | — | 1 | Gear. |
| `ui_icon_hoe` | 96 × 96 | UI | — | 2 | Hoe (plow action). |
| `ui_icon_watering_can` | 96 × 96 | UI | — | 2 | Watering can. |
| `ui_icon_basket` | 96 × 96 | UI | — | 2 | Harvest basket. |
| `ui_icon_hand` | 96 × 96 | UI | — | 8 | Work glove (the bare-hand tool: walk, pick, tend animals). |
| `ui_icon_sickle` | 96 × 96 | UI | — | 8 | Sickle with a wooden handle (harvest tool). |
| `ui_icon_axe` | 96 × 96 | UI | — | 8 | Wood axe (chop trees, clear stumps). |
| `ui_icon_rod` | 96 × 96 | UI | — | 11 | Bamboo fishing rod with a red and white bobber. |
| `ui_icon_map` | 96 × 96 | UI | — | 3 | Folded map. |
| `ui_icon_fuel` | 72 × 72 | UI | — | 3 | Jerry can (fuel gauge). |
| `ui_icon_truck` | 96 × 96 | UI | — | 3 | Pickup truck (drive button). |
| `ui_icon_energy` | 72 × 72 | UI | — | 5 | Little sun / lightning badge for the farmer's energy. |
| `ui_icon_goals` | 96 × 96 | UI | — | 5 | Rolled-up checklist with a ribbon (goals). |
| `ui_icon_bed` | 96 × 96 | UI | — | 5 | Cozy bed with a moon (go to bed). |
| `ui_icon_contracts` | 96 × 96 | UI | — | 5 | Pinned note (contracts board). |
| `ui_icon_phone` | 96 × 96 | UI | — | 6 | Chunky flip phone (business phone: orders and money). |
| `ui_icon_worker` | 96 × 96 | UI | — | 6 | Farmhand in a straw hat. |
| `ui_icon_collection` | 96 × 96 | UI | — | 7 | Leather-bound book (collection). |
| `ui_joystick_base` | 420 × 420 | UI | — | 3 | Joystick ring, soft translucent. |
| `ui_joystick_knob` | 192 × 192 | UI | — | 3 | Joystick knob. |
| `ui_panel_parchment` | 288 × 288 | UI | — | 1 | 9-slice panel: warm parchment with a subtle hand-drawn border (slice 32 pt). |
| `ui_button_primary` | 288 × 144 | UI | — | 1 | 9-slice button: warm green, soft bevel (slice 20 pt). |

## Audio

### Music

| Name | Loop | Length | Phase | Description |
|---|---|---|---:|---|
| `music_title` | yes | 1:30 | 8 | Title theme: warm acoustic guitar and soft piano, hopeful. |
| `music_spring_day` | yes | 3:00 | 8 | Light fingerpicked guitar, flute, birdsong feel. |
| `music_spring_evening` | yes | 3:00 | 8 | Gentle, slower variant of the spring theme. |
| `music_summer_day` | yes | 3:00 | 8 | Sunny, lazy: ukulele or mandolin, light percussion. |
| `music_summer_evening` | yes | 3:00 | 8 | Warm golden-hour guitar, cicadas feel. |
| `music_autumn_day` | yes | 3:00 | 8 | Cozy, slightly melancholic: cello and guitar. |
| `music_autumn_evening` | yes | 3:00 | 8 | Quiet piano and cello. |
| `music_winter_day` | yes | 3:00 | 8 | Sparse piano, glockenspiel, crisp and calm. |
| `music_winter_evening` | yes | 3:00 | 8 | Very soft piano by the fireplace. |
| `music_night` | yes | 3:00 | 8 | Minimal, sleepy: soft pads and occasional piano notes (all seasons). |
| `music_rain` | yes | 3:00 | 8 | Mellow rainy-day piece, Rhodes piano. |
| `music_town` | yes | 2:30 | 8 | Livelier market-day tune: accordion, guitar. |
| `music_harvest_fair` | yes | 2:30 | 8 | Festive folk tune for the yearly harvest fair: fiddle, claps. |

### Ambience loops

| Name | Loop | Length | Phase | Description |
|---|---|---|---:|---|
| `amb_birds_morning` | yes | 0:30–1:00 | 8 | Morning birdsong chorus. |
| `amb_meadow_day` | yes | 0:30–1:00 | 8 | Light breeze, distant birds, insects. |
| `amb_night_crickets` | yes | 0:30–1:00 | 8 | Crickets and an occasional owl. |
| `amb_wind_soft` | yes | 0:30–1:00 | 8 | Soft wind through grass and leaves. |
| `amb_wind_winter` | yes | 0:30–1:00 | 8 | Colder, hollow wind. |
| `amb_rain_light` | yes | 0:30–1:00 | 8 | Light rain on leaves. |
| `amb_rain_heavy` | yes | 0:30–1:00 | 8 | Steady rain, distant thunder. |
| `amb_forest` | yes | 0:30–1:00 | 8 | Rustling forest canopy, woodpecker. |
| `amb_lake` | yes | 0:30–1:00 | 8 | Water lapping, ducks. |
| `amb_town` | yes | 0:30–1:00 | 8 | Distant chatter, footsteps, a bicycle bell. |
| `amb_harbor` | yes | 0:30–1:00 | 8 | Gulls, creaking ropes, water against piers. |

### Sound effects

| Name | Loop | Length | Phase | Description |
|---|---|---|---:|---|
| `sfx_ui_tap` | no | < 2 s | 8 | Soft wooden click. |
| `sfx_ui_open` | no | < 2 s | 8 | Paper unfold / panel open. |
| `sfx_ui_close` | no | < 2 s | 8 | Paper fold / panel close. |
| `sfx_plow` | no | < 2 s | 8 | Hoe into soil. |
| `sfx_plant` | no | < 2 s | 8 | Seeds dropped, soft pat of soil. |
| `sfx_water` | no | < 2 s | 8 | Short watering-can pour. |
| `sfx_harvest_pop` | no | < 2 s | 8 | Satisfying pluck/pop. |
| `sfx_coin` | no | < 2 s | 8 | Single bright coin. |
| `sfx_coins_many` | no | < 2 s | 8 | Handful of coins (big sale). |
| `sfx_cash_register` | no | < 2 s | 8 | Old cash register ding. |
| `sfx_level_up` | no | < 2 s | 8 | Short warm fanfare (guitar strum + chime). |
| `sfx_achievement` | no | < 2 s | 8 | Gentle chime. |
| `sfx_axe_chop` | no | < 2 s | 8 | Axe into wood. |
| `sfx_tree_fall` | no | < 2 s | 8 | Creak and soft thud of a falling tree. |
| `sfx_saw` | no | < 2 s | 8 | Hand saw / sawmill blade. |
| `sfx_chicken` | no | < 2 s | 8 | Hen cluck. |
| `sfx_cow` | no | < 2 s | 8 | Soft moo. |
| `sfx_sheep` | no | < 2 s | 8 | Baa. |
| `sfx_pig` | no | < 2 s | 8 | Oink. |
| `sfx_goat` | no | < 2 s | 8 | Bleat. |
| `sfx_horse` | no | < 2 s | 8 | Nicker. |
| `sfx_dog` | no | < 2 s | 8 | Friendly woof. |
| `sfx_truck_door` | no | < 2 s | 8 | Old truck door slam. |
| `sfx_engine_start` | no | < 2 s | 8 | Old engine cranking and starting. |
| `sfx_engine_loop` | yes | 2–5 s loop | 8 | Engine hum; pitch and volume follow speed. |
| `sfx_tires_gravel` | yes | 2–5 s loop | 8 | Tires crunching on gravel/dirt. |
| `sfx_tires_asphalt` | yes | 2–5 s loop | 8 | Tires rolling on asphalt. |
| `sfx_horn` | no | < 2 s | 8 | Friendly old horn. |
| `sfx_bump` | no | < 2 s | 8 | Suspension thump over a bump. |
| `sfx_fuel_pump` | no | < 2 s | 8 | Fuel nozzle click and pour. |
| `sfx_birds_flyoff` | no | < 2 s | 8 | Flutter of wings. |
| `sfx_mill` | yes | 2–5 s loop | 8 | Creaking windmill / millstone. |
| `sfx_notification` | no | < 2 s | 8 | Soft bell for 'ready' notifications. |
| `sfx_refuse` | no | < 2 s | 8 | Soft low two-note 'nope' when something can't be done. |

