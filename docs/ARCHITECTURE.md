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
│  AssetManifest / AudioManifest   DayNightCurve                           │
│  Foundation only: builds and tests on macOS and Linux                    │
└──────────────────────────────────────────────────────────────────────────┘
```

**Rule:** game rules live in `AcresCore`. The app layer draws the state and turns input into
calls on the simulation. That keeps the rules unit-testable and lets the simulation
fast-forward days in milliseconds.

## Time: two clocks

Decided in Phase 1 planning. A 20-minute day means one night's sleep would be ~24 in-game days if
the calendar ran while the app is closed. So there are two clocks:

| | Growth clock (`GameState.worldTime`) | Calendar (`GameState.clock`) |
|---|---|---|
| Measures | Real seconds the world has been simulated | In-game minutes since Year 1, Spring 1, 06:00 |
| While playing | Runs | Runs (1 day = 20 min, `Balance.realSecondsPerGameDay`) |
| While closed | Runs for the whole absence, capped at 3 days | Frozen; absences ≥ 1 h wake you at 06:00 next morning |
| Drives | Crops, animal products, trees, machines, workers | Time of day, lighting, seasons, prices, deadlines |

Consequences:
- Growth durations are **real time** (e.g. wheat: minutes, pumpkins: hours), so coming back is
  always rewarding.
- Seasons pass through **play** (≈ 2h 20m per season), never by the wall clock, and at most one
  day is skipped per absence, so day-based contracts stay fair.
- A crop planted in season always finishes, even if the season changes (Phase 2).
- Changing the device clock can't hurt: going backwards simulates nothing, going forwards is
  bounded by the 3-day cap.

All rules live in `OfflineCatchUp.swift` and are covered by `OfflineCatchUpTests`.

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

## Input model (decided in Phase 1 planning)

No walking avatar. The player touches their land directly (1–2 taps per action), but only on the
property where the **truck is parked**. That gives driving a purpose and makes workers valuable on
far-away properties. Camera: free pan/zoom when parked; follows the truck when driving (Phase 3).
Planned for Phase 2: a one-finger drag that *starts on a field* paints actions across tiles; a
drag anywhere else pans; two fingers always pan and zoom.

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
- Seeds can't be bought yet (the seed shop comes with the village in Phase 3); the debug panel
  can add them.
