# Acres: Architecture

## Layers

```
┌──────────────────────────── Acres (iOS app) ────────────────────────────┐
│  SwiftUI: HUD, Welcome back, menus  ◄── observes ──┐                    │
│                                                   │                    │
│  GameController (@Observable, main actor)  ───────┘                    │
│    owns Simulation, SaveSystem; runs autosave and offline catch-up     │
│        ▲ update(dt) every frame                                        │
│  SpriteKit: GameScene, CameraController, ChunkManager, TerrainRenderer │
│        │ reads state, never changes rules                              │
│  AssetCatalog → real art (Assets.xcassets) or PlaceholderPainter       │
└────────────────────────────────┬───────────────────────────────────────┘
                                 │ import AcresCore
┌────────────────────── AcresCore (Swift package) ─────────────────────────┐
│  GameState (Codable)  Simulation + systems  OfflineCatchUp  Balance      │
│  SaveFile / SaveMigrator / SaveStore   WorldMap / MapBuilder             │
│  AssetManifest / AudioManifest   DayNightCurve   Tutorial                │
│  TruckPhysics / Pathfinder   Trading / ShopCatalog / MarketPricing       │
│  AnimalSystem / Ranching   TreeSystem / Forestry   Obstacles             │
│  Foundation only: builds and tests on macOS and Linux                    │
└──────────────────────────────────────────────────────────────────────────┘
```

**Rule:** game rules live in `AcresCore`. The app layer draws the state and turns input into
calls on the simulation. That keeps the rules unit-testable and lets the simulation
fast-forward days in milliseconds.

## Time: a clock and days (Phase 5)

The game is a farmer's version of Big Ambitions, so it runs on a visible clock again (Phase 3
had tried "no clock, just timers"; the direction changed in Phase 5). One game day is 24 real
minutes: one game minute per real second. There are still two clocks:

| | Growth clock (`GameState.worldTime`) | Calendar (`GameState.clock`) |
|---|---|---|
| Measures | Real seconds the world has been simulated | In-game minutes since Monday, Week 1, 06:00 |
| While playing | Runs | Runs (1 game minute per real second) |
| While sleeping | Runs through the night (`Simulation.sleep`) | Jumps to 06:00 |
| While closed | Runs for the whole absence, capped at 3 days | Frozen; absences ≥ 1 h start a fresh morning |
| Drives | Crops, animals, trees | Clock, weekdays, opening hours, lighting, seasons, energy |

Consequences:
- Content durations are game days (`GameTime.days(n)`): wheat 1 day, pumpkins 6, eggs daily,
  trees 3–9 days. Watering and troughs last a day.
- A season is one week (7 days ≈ 2 h 50 min of play). Weekly bills arrive in Phase 6.
- Absences are sleep: the farmer wakes rested at 06:00, and weekly deadlines can't be missed
  by closing the app.

All rules live in `OfflineCatchUp.swift` and `FarmerSystem.swift`, with tests.

## The simulation

- `Simulation.advance(by:mode:)` is the only way time passes. The same code path handles a 16 ms
  frame and a 3-day catch-up: long spans are cut into steps of at most
  `Balance.simulationMaxStep` (60 s), so a 3-day catch-up is about 4,300 steps and takes a few ms.
- Each `SimulationSystem` (clock now; crops, animals, trees, machines, workers later) must give the
  same result however time is chopped up. `SimulationTests.testOneBigAdvanceEqualsManySmallOnes`
  enforces this, including storage caps ("production stops when storage is full").
- Randomness comes only from `GameState.rng` (a seeded SplitMix64), so the simulation is
  deterministic and testable.
- Timestamps in state are `worldTime` seconds, never wall-clock `Date`s.

## Farming (Phase 2)

- **Content:** `CropCatalog` (growth time, seasons, seed cost, price range, yield, XP, unlock
  level, art notes). Items and seed packets are derived from it (`ItemCatalog`), and so are the
  crop and item entries in the asset manifest. A new crop is one entry.
- **State:** `GameState.plots` (tilled tiles: `wetUntil`, planted crop with accumulated `growth`),
  `inventory` (storage + seed pouch), `ownedProperties`.
- **Growth** (`CropSystem`): full speed while `worldTime < wetUntil`, `Balance.dryGrowthRate` (½)
  when dry, so crops never stop. The wet part of any time span is computed exactly, so the
  system opts into `handlesAnyStepSize` and runs once per advance: a 3-day catch-up of a full
  farm takes ~2 ms. Ripe crops never rot.
- **Rules** (`Farming`): plow only on owned land, with the truck parked there, on grass or dirt,
  not under buildings, trees or the truck (`WorldMap.blockedTiles` from `ObjectFootprint`). Weeds,
  flowers and pebbles are cleared by plowing. Planting needs a seed and the right season.
  Harvest needs storage room: the yield is rolled on a copy of the RNG, so a refused harvest
  doesn't change luck.
- **Input:** `Farming.suggestedAction` picks the one sensible action for a tap. Drag-painting
  repeats the first tile's action kind along the stroke (Bresenham, so fast strokes don't skip
  tiles).
- **Forecast** (`FarmForecast`): time until ripe, given the current wetness. Used for tile info,
  the away summary and harvest reminders (local notifications, device setting).
- **XP** (`Progression`): harvests give XP; `Balance.xpToNextLevel` is the curve. Unlocks come in
  Phase 7.

## Truck, village and trade (Phase 3)

- **Driving** (`TruckPhysics`, core, tested): arcade physics in tile units. The truck turns toward
  the stick direction at `turnRate`, accelerates to a surface-dependent top speed (asphalt >
  gravel > dirt > grass), and its velocity bends toward its heading at a surface-dependent grip,
  so gravel and dirt drift a little. Collisions are a circle against blocked tiles
  (`WorldMap.blockedTiles`): the truck slides along walls and reports a bump (haptic). Fuel drains
  per tile; an empty tank limps along at 35 % speed, so the player is never stranded.
- **Controls:** tap to drive (A* over drivable tiles, `Pathfinder`, followed by an `Autopilot`
  that produces `DriveInput`s). Phase 3 also had a joystick; Phase 5 removed it. The camera follows
  the truck with a little look-ahead.
- **A driving truck is never saved.** Physics state (`TruckMotion`) lives in the app; the save
  holds the truck's position, heading, fuel and cargo. Backgrounding the app parks the truck.
- **The village** (east of the farm, `HomeValleyMap.buildVillageAndBeyond`): gas station, seed
  shop, market square, cottages, lamps. The map grew to 144 × 96 tiles; the original farm is
  unchanged (same seed, same objects).
- **Shops** (`ShopCatalog`, `Trading`): each shop is a stop zone. When the truck is stopped
  inside one, a button opens the shop sheet. Buying seeds needs the level; selling happens from
  the **truck bed** (30 items), so harvest has to be loaded at the farm and driven to market.
  Prices drift daily inside each crop's range (`MarketPricing`, deterministic per day). Every
  trade is a typed `TradeFailure` or success, applied atomically through `Simulation.trade`.
- **Tutorial** (`TutorialState`, saved): plow → plow a row → plant → water → harvest → load →
  drive → sell → buy seeds. Steps advance from game events, can be skipped, and can be restarted
  from Settings. The scene highlights a target tile, the HUD pulses the right button and a guide
  arrow points the way while driving.

## Animals and trees (Phase 4)

- **Content:** `AnimalCatalog` (product, timings, food preferences, price, level, names),
  `PenCatalog` (the four pens behind the farmhouse: yard, shelter, trough, capacity, repair
  cost), `TreeCatalog` (growth, logs, sapling price, fruit). Items gained categories (fruit,
  animal products, wood, feed, saplings) with `isSellable` and `usesStorage`.
- **State:** `GameState.ranch` (pens: repaired, `waterUntil`, animals with `age`,
  `production`, `happiness`) and `GameState.woodland` (tree records by trunk tile, plus
  `hiddenMapTrees`). Wild map trees are *content*; the player's changes are an overlay, like
  plots: chopping a wild tree hides it and a record (a stump) takes its place. A record is
  self-contained, so even if the map changes later it still draws and behaves correctly.
- **Simulation:** `AnimalSystem` and `TreeSystem` are exact for any step size (they opt into
  `handlesAnyStepSize`): the watered part of a step comes from `waterUntil`, growing up and
  sprouting split the step at the exact moment, happiness changes linearly. Tests compare one
  big advance with thousands of small ones.
- **Rules:** `Ranching` (one tap per pen: collect → water → feed; repairs are a deliberate
  button on the pen's card because they cost coins) and `Forestry` (chop full-grown wood trees,
  clear stumps, pick fruit, plant saplings on plowed soil; fruit trees are only chopped from
  their card). Both follow "you work where your truck is parked". Products and logs are rolled
  on a copy of the RNG, so a refusal (full storage) never changes luck.
- **Obstacles:** `WorldMap` now separates solid tiles (buildings, rocks, *pens*) from what wild
  trees cover. `Obstacles` combines them with the woodland for plowing, truck collisions and
  route planning, so a cleared stump really frees the ground.
- **Rendering:** `TreeRenderer` draws records (sapling, young, full-grown, stump, fruit
  overlay); the chunk manager skips hidden wild trees. `RanchRenderer` draws pens from state
  (broken fences and a repair sign until fixed, the trough full or dry) and the animals, which
  wander, graze and sleep at night on their own (presentation only, never saved). Bubbles show
  a waiting product or the food a hungry animal wants.
- **Map:** the home farm now includes the backyard (pens and a woodlot, y 41–57). The Phase 4
  additions are appended after the Phase 3 ones and only remove objects inside the new pens, so
  existing fields never end up under something new.

## The farmer (Phase 5)

- **State:** `GameState.farmer` (position, energy, in the truck). Where the farmer is decides what
  can be worked: every farming, pen and tree rule checks reach (`Balance.workReach`) and energy;
  planning a job skips the reach check (`checkReach: false`), because the farmer walks over first.
- **Jobs** (app side, not saved): a tap lines up a job (`FarmerJob`), a drag lines up a row. The
  controller walks the farmer along an A* path, plays a work animation for the job's duration,
  then performs the core action (re-checked on arrival, since the tile may have changed).
- **Energy:** drains per game hour awake (`FarmerSystem`, play only) and per job
  (`Balance.energyCost`). Sleep (`Simulation.sleep`) runs the world to 06:00 and refills energy per
  hour slept; past 02:00 the farmer passes out.
- **Driving:** tap-only. Tap the truck (the farmer walks over and gets in), tap a spot or pick a
  place from the map menu; the autopilot drives. Shops are used where the farmer is; the market
  and the gas station also need the truck. Shops keep opening hours.
- **Goals** (`GoalCatalog`, `GoalState`): a ladder of goals, three open at a time. Actions count
  toward them in the core (`GoalCounter`); rewards are claimed from the goals sheet.

## Saves

- File: `Application Support/Saves/farm.json` plus `farm.backup.json` (the previous save).
  Writes are atomic; a crash can never lose both.
- Envelope (`SaveFile`): `version`, `revision` (increments every save), `deviceID`, `createdAt`,
  `savedAt`, `state`, `presentation` (camera). The metadata is what a future iCloud sync needs to
  resolve conflicts; storage sits behind the `SaveStore` protocol, so iCloud is a new store.
- **Versioning from day one.** Changing any stored type means:
  1. bump `SaveFile.currentVersion`,
  2. add a migration (on raw JSON) to `SaveMigrator.standard`,
  3. add a frozen fixture to `SaveTests` (`SaveFixtures`).
  `testCurrentFormatMatchesLatestFixture` fails if the format changes without a version bump, and
  `testEveryOldFixtureStillLoads` proves old saves still load.
- Recovery: a damaged main file falls back to the backup. A save from a *newer* app version is
  never overwritten (saving pauses, the player is asked to update). Damaged files are moved
  aside, never deleted.
- Autosave every 30 s and when the app goes to the background.
- History: v1 (Phase 1), v2 (Phase 2: plots, inventory, properties), v3 (Phase 3: truck fuel and
  cargo, tutorial). A migrated save starts the tutorial too, because the loop it teaches (load,
  drive, sell) is new to existing players; it can be skipped in one tap. v4 (Phase 4: `ranch`,
  `woodland`). v5 (Phase 5: `farmer`, `goals`).

## Rendering

- **3/4 view** in 2D: the ground is a flat top-down grid; standing sprites show their front and
  top, are anchored at their foot point, and are depth-sorted by y (`World.depth(forY:)`).
  Soft contact shadows are separate sprites on the ground.
- **Chunks:** the world is 16 × 16-tile chunks (`ChunkManager`). Chunks on screen load
  immediately; nearby ones trickle in one per frame; far ones unload (with hysteresis). The map can
  grow large without more nodes on screen.
- **Terrain:** one sprite per chunk. Its texture is a tiny splat map (dirt/gravel/asphalt
  weights). A fragment shader blends seamless detail textures and pushes the edges through noise,
  so borders look organic rather than tiled. One draw call per chunk.
- **Draw order** (`ZLayer`): ground → flat things/shadows → standing objects → day/night grade
  (a multiply overlay) → additive night lights (windows) → debug.
- **Day/night:** `DayNightCurve` (core, tested) gives a tint and a night-light strength per hour.
- **Frame rate:** capped at 60 fps (also on ProMotion screens) for battery life and consistent
  behavior.

## Art pipeline

1. `AssetManifest` lists every asset: name, world size in tiles, recommended pixels, anchor, phase
   and art notes. `docs/ASSETS.md` is generated from it (`swift run acres-tools assets`), and a
   test fails if the doc is stale.
2. `AssetCatalog.texture(name)` looks for real art in `Assets.xcassets`, then a procedural
   placeholder (`PlaceholderPainter`), then shows a magenta checkerboard.
3. Sprites are sized from the manifest, not from the image, so art at any resolution drops in.

## Input model (Phase 5)

Tap to walk and work: the farmer walks to what you tap and does the job there. A one-finger drag
that *starts on a field* lines up a row of jobs; a drag anywhere else pans; two fingers always pan
and zoom. While driving, taps set the destination and drags look around. (Phases 1–4 had no
avatar and farmed wherever the truck was parked; Phase 5 replaced that with the farmer.)

## Adding content

- **Map objects:** `HomeValleyMap.swift` (`place` for landmarks, `scatter` for nature). Every
  object kind needs a manifest entry (a test checks this).
- **Art:** add a manifest entry, then either a painter case or a real PNG.
- **Numbers:** `Balance.swift`.

## Known limitations

- The iOS app code has not been compiled by Xcode yet (see the README); the core is compiled and
  tested on Linux.
- Placeholder art is drawn procedurally at startup (well under a second). If that grows, it can
  be cached to disk or moved off the main thread.
- Seasonal visuals (trees, grass, snow) are listed in the manifest but arrive in Phase 7; the
  world currently always renders summer foliage.
- Crop sprites use individual textures. Big fields may want a runtime texture atlas so SpriteKit
  can batch them (Phase 8 performance pass).
- There is one market with one price per item per day. Several markets, supply and demand and
  contracts come in Phase 5.
- Animals are delivered straight to their pen; carrying them home in the truck could come later.
- Old wooden fences don't block the truck (they run along tile edges); pens, trees and
  buildings do.
