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
- **Shops** (`ShopCatalog`, `Trading`): each shop is a stop zone. When the truck stops (or the
  farmer walks) within a tile of one, a button opens the shop sheet. Buying seeds needs the
  level. Selling, deliveries and stocking your own shop take **goods on hand** (`Goods`): the
  farmer's **bag** (`FarmerState.bag`, 10 goods, filled from storage anywhere on the farm),
  then the **truck bed** (30) if the truck stands within `Goods.truckReach` (2 tiles) of the
  place. The rule is one place, so a place's button and its trades agree.
  Prices drift daily inside each crop's range (`MarketPricing`, deterministic per day), and fall
  as you sell (`Market`, see "The long game"). Every trade is a typed `TradeFailure` or success,
  applied atomically through `Simulation.trade`.
- **Arne** (`TutorialState`, saved; `GameController+Guide.swift`): not a tutorial but an old
  farmer at the side of the screen. He walks a whole first loop: plow → plow a row → plant →
  water → sleep → harvest → claim a goal → load → drive → sell → buy seeds → drive home →
  replant → open the journal → take an order → fields. Saved step numbers never change; the play
  order is `TutorialState.order`. Steps advance from game events (an event can complete a step up
  to two ahead, so doing things early counts); his introduction, "Will do" and goodbye advance
  with a reply. What he says fades (`TutorialStep.detail`): **walkthrough** (the first day: every
  move, the target glows), **pointer** (a line; the glow, the ring and the details only when the
  player taps *Show me* or makes no progress for 25 s of quiet play), **nudge** (a word in
  passing, then he tucks himself away; the button pulses). After the loop he drops by with
  `GuideTopic`s (chores, axe, coop, workshop, fishing, foraging, shop, almanac, farmhand) as
  they open up, one at a time after two minutes of quiet play, skipping what the player already
  found (`isMoot`), then says goodbye (`farewell`, `isRetired`); `told` records them (v14).
  The player can tuck him away at any time: he stays tucked and news lights a dot on his
  portrait; tapped with nothing to say, he names the next goal. Settings: *Show me around
  again* (restart) and *I'll manage* (`skip`, retire). His name is `Mentor.name`.

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

## Business (Phase 6)

- **Places** (`Place`): shops and clients, each with a stopping zone on the map. Zones never
  overlap (a test checks); where their one-tile margins do, the closest zone wins.
- **Contracts** (`Contracts`, `ContractBoard`): clients (`ClientCatalog`) order goods the farm can
  make at its level. Order size follows level and reputation; the reward is the goods' average
  value plus a bonus (`Balance.contractBonus`, more with reputation). Accepting restarts the
  deadline from today. Delivering hands over matching truck cargo, earliest deadline first, and
  needs the farmer and the truck at the client during opening hours. Late orders fail and cost
  reputation.
- **The books** (`Finance`, `Ledger`): every coin in or out is booked under a category for the
  current week. `Bank.weeklyBills` lists what's due on Mondays (property tax per property, the
  loan instalment); money may go negative (debt), which blocks buying.
- **`BusinessSystem`** runs each game morning once, in order, for every day the calendar passed
  (`Finance.lastProcessedDay`): fail late orders, pay bills on Mondays (closing the week's books),
  refresh the order board. It's deterministic (the order board draws from the seeded RNG).
- **Loans** (`Bank.offers`): flat interest, equal weekly instalments, one at a time, repayable
  early at the bank.

## Your shop (Phase 7)

- **State** (`StoreState`): rented or not, six `Shelf`s (item, stock, price factor, demand
  progress), today's takings. Rules live in `Storekeeping`: renting (level, first payment pro-rated
  to Monday), stocking from the truck (shelves holding the item first, then empty ones), taking
  back, prices in 5% steps within `Balance.storePriceFactorRange`, ending the lease.
- **Customers** (`StoreSystem`): while the calendar runs and the shop is open, each shelf sells at
  `demand(category) × exp(-k × (factor - 1)) × traffic` items per hour; traffic grows with the
  number of different goods on the shelves. Demand accumulates in `Shelf.progress` and a sale
  happens at each whole unit, so sales are deterministic and don't depend on the frame rate (the
  system measures the exact open minutes covered by each step; a test compares 30 fps frames
  with one-hour steps). Prices are the item's usual value (the middle of its range) × the factor,
  so they don't follow the market's daily swings.
- **In the world** (`StoreRenderer`, app side): the *for rent* / *open* sign, and a villager
  walking in off the street for each sale (visual only, a few at a time).
- Rent is one more line in `Bank.weeklyBills`.

## Growing the farm (Phase 8)

- **Land** (`PropertyCatalog.forSale`): parcels with a price and a level. Ownership is just
  `ownedProperties`; every farming, tree and pen rule already checks it, so bought land works at
  once. Parcels never overlap (tested).
- **Upgrades** (`EstateState`): storage and truck-bed levels. Capacities come from
  `GameState.storageCapacity(_:)` / `truckCapacity(_:)`; level 0 is the base `Balance` value.
  Storage buildings stand in `EstateLayout` spots off the fields and block the truck
  (`Obstacles.built`).
- **Sprinklers** (`MachineCatalog`, `SprinklerSystem`): bought into the pouch, placed on free
  grass of your land. The system runs first and for the whole span, topping up `wetUntil` of
  covered plots past its end, so `CropSystem` treats them as wet, online and offline.
- **Farmhands** (`Worker`, `WorkerSystem`): work while the calendar runs during work hours. Work
  builds up in `progress`; each whole unit does the most useful task nearest to them
  (fields: harvest, then water; animals: collect, water, feed) through the same rules as the
  farmer (`byWorker`: no reach, energy or XP). The app's `EstateRenderer` walks their sprite to
  the last task's spot. Wages are a line in `Bank.weeklyBills`.

## The daily loop and weather (Phase 9)

- **Daily chores** (`DailyRoutine`, `DailyState`): each morning (`BusinessSystem.morning`) three
  chores are drawn for the day from what the farm can do, counted as goal-counter progress since
  the morning. Rewards are claimed one by one, then an all-done bonus that grows with the streak.
  The streak is counted at the next morning. Chores and the **market special** (one obtainable
  item paying `Balance.marketSpecialBonus` extra) come from a hash of the day, not the game's RNG.
- **Weather** (`Weather.on(day:)`): fixed per day from a hash, weighted by season. `WeatherSystem`
  runs first over each span (like sprinklers): on rainy days it tops up every plot's `wetUntil`
  to the day's end plus half a day. Snow is visual.
- **App side:** seasons switch chunk and tree art and tint the terrain shader (plus snow cover);
  `WeatherRenderer` recycles rain/snow particles over the visible rect; `Sound` plays bundle
  recordings named like the audio manifest, else synthesized placeholders.

## Workshops and artisan goods (Phase 10)

- **Catalog** (`WorkshopCatalog`): each workshop has recipes (`Recipe`: inputs from storage, an
  output item and amount, game hours, XP, a value range). Outputs are `ItemCategory.artisan`
  items, sold like crops (market, shop, clients). Automatic workshops (the beehive) have no inputs
  and stop when `holds` batches wait.
- **State** (`EstateState.workshops`): tile, kind, the recipe running, batches queued, progress
  and goods ready. Workshops are placed from the pouch like sprinklers (`EstateRules.placeMachine`);
  `EstateState.isOccupied` keeps fields, sprinklers and workshops apart.
- **Rules** (`Workshops`, via `Simulation.workshops { }`): start (takes the inputs; more batches
  of the same recipe queue up), collect (into storage, with XP for the farmer), pick up (only
  when empty). `WorkshopSystem` is a bulk system: whole batches finish in order for any step size,
  so offline time is exact (tested).
- **Workshop hands** (`WorkerJob.workshops`): collect first, then restart idle workshops on their
  last recipe if storage pays for it.
- **App side:** `EstateRenderer` draws workshops, a bubble with the ready goods and puffs while
  busy; tapping one queues a `.workshop` job and the panel (`WorkshopView`) opens on arrival.
  The copy of the estate the HUD observes zeroes workshop progress so SwiftUI isn't re-rendered
  every frame; the open panel ticks once a second from its own snapshot.

## The outdoors (Phase 11)

- **Water** (`Waters`): the farm pond and Willow Lake, each a rect matching its map object's
  footprint (solid, so the farmer stands on `shoreSpots`). **Fish** (`FishCatalog`) bite by water
  kind, season and (for some) night hours, weighted; legends have tiny weights.
- **Fishing** (`Fishing`, via `Simulation.outdoors { }`): `cast` checks reach and energy, spends
  energy and picks the fish with the game's RNG (deterministic); `land` puts it in storage with
  XP and counters (`fishCaught`, `caught:<id>`). The catch itself is the app's
  `FishingSession` (bite window, then a catch bar whose zone and speed follow the fish's
  difficulty): skill decides whether `land` is called.
- **Foraging** (`Foraging`): `spots` is a fixed scatter of open grass away from roads, the farm and
  the village. Each day's finds are a hash of the day (like chores and weather), so only the
  picked spot indices are saved (`ForageState`, v11). Finds on fields, trees or buildings are
  hidden.
- **Goats**: a new species and pen on the new **Goat Hill** property; pens already work on any
  owned property, so buying the land is what opens it. The map clears the track and pen.
- **Orders** only ask for fish and wild finds in season (`Contracts.isInSeason`, also used for the
  market special); legends are never ordered.
- **App side:** `OutdoorsRenderer` draws the finds (item icons with a twinkle), and the bobber,
  line, "!" and catch bar in SpriteKit, so the per-frame minigame never re-renders SwiftUI; the HUD
  only shows `fishingHint`.

## Fields and a gradual start

- **Fields** (`FieldCatalog`, `GameState.ownedFields`, v13): fixed patches of farmland on each
  property. `Farming.plowProblem` = `groundProblem` (free ground of your land) + inside an owned
  field; machines and workshops only need `groundProblem`. `EstateRules.buyField` sells the fields
  on land you own, by level. Plots already plowed anywhere keep working (old saves).
- **Features** (`Feature`): parts of the game with an unlock level. The simulation hides wild
  finds and the rod until then; the app hides the phone, chores, tools, phone tabs and shop rows
  (showing only what's open now or next level). Orders and chores still run underneath, so the
  first orders are waiting when the phone appears.
- **Brush** (`WildLand`, core, derived from level and land, nothing saved): a new farm is a
  clearing (house, barn, yard, the first field) in thick brush. `WildLand.homePatches` clear at
  levels 2–4 (each home field lies in a patch that clears at the field's level); land for sale is
  brush until bought; owned fields and old farmland are always clear. Brush is an obstacle
  (`Obstacles`, `Pathfinder`, `TruckPhysics` take a `wild:`), `groundProblem` answers
  `.overgrown`, and wild finds skip it. `ChunkManager` draws it per chunk (deterministic bushes,
  long grass, rocks, stumps and young trees, no shadows) from `GameController.drawnWildLand`, and
  the scene puffs dust where it clears.
- **The farm grows with you** (presentation only, no save change): pens below their level are
  drawn as overgrowth and ignore taps (`PenDefinition.isShown`, `RanchRenderer`); field outlines
  and FOR SALE signs for fields and land appear only from their level (`EstateRenderer`, which
  also owns every FOR SALE sign; the map's own sign is skipped by `ChunkManager`).

## The long game (Phase 12)

- **Almanac** (`Almanac`, `AlmanacState`, v12): entries are the sellable-kind items (crops,
  fruit, animal products, fish, wild finds, artisan goods, wood). `AlmanacSystem` (bulk, once per
  span) adds anything seen in storage, the truck or the shop's shelves, plus everything counted by
  the `caught:` / `found:` / `collected:` counters, and emits `.discovered`. That's also how old
  saves fill in after migrating. `Almanac.sets` are themed pages with one-time rewards (tested:
  every entry is on a page).
- **Net worth** (`NetWorth.of`): coins + land prices + upgrade costs + machines and workshops +
  repaired pens + animals + goods at their usual value − the loan.
- **Ranks** (`FarmRanks`, `RankState`, `RankSystem`): the best rank reached, never lower;
  `RankSystem` (bulk) moves it up through every threshold passed, with `.rankUp` events and XP.
  The last rank is the finale (`finaleDay`). Each rank names a farmhouse tier.
- **App side:** `ChunkManager.farmhouseTier` swaps the map's farmhouse for the renovated art (the
  same 5×5 footprint, so blocked tiles never change) and reloads chunks; `BuildingPainter`
  paints the four tiers from one layout (lights and the chimney line up). `RankUpCardView` and
  `FinaleCardView` show after any level-up card; the Almanac tab lives on the phone.

## Supply, demand and the village

- **The market fills up** (`Market`, `MarketState` in the save): each sale adds its coins' worth
  (at the usual price) to the item's recent sales, and the next one fetches
  `1 / (1 + recent / depth)` of the price, never below `Balance.marketPriceFloor` (30%).
  `Balance.marketDepth` is per category (6,000 coins for crops). Three quarters of it wears off
  each day (`marketRecoveryPerDay`, applied lazily from `MarketState.day`). Measured in coins so a
  load of pumpkins weighs like a mountain of wheat worth the same. Orders and your own shop never
  touch it. `Trading.quote` is what the sell buttons show; `swift run acres-tools economy` prints
  the curve, the crop ladder and what there is to buy.
- **The crop ladder:** later crops earn more per tile per day (`MarketAndVillageTests` checks the
  best crop at each unlock level never drops).
- **Village projects** (`Village`, `VillageWorks`, `VillageState` in the save): six projects from
  level 3 to 8, each wanting coins and goods (from storage, the bag and the truck), given a bit at
  a time, then opened for XP and lasting perks (`VillagePerks`: market depth, faster recovery,
  higher prices, better orders). What's been given counts toward net worth, so giving never
  costs a rank. Projects renamed before release keep their progress (`VillageState.renamed`).
- **In the world** (`VillageLayout`, app `VillageRenderer`): each project has pieces that stand in
  the village once it's open (post office, market hall, fair, boathouse with rowboats, the
  windmill with its six sail frames turning), a "coming soon" sign while it's open, and the
  windmill's ruin until then. The map keeps their `sites` clear and paints the track up to the
  mill; their footprints join `Obstacles.built`. Tapping a sign or a building opens its page in
  the journal (`VillageLayout.project(at:in:)`).

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
  `woodland`). v5 (Phase 5: `farmer`, `goals`). v6 (Phase 6: `contracts`, `finance`; a migrated
  save starts its books in the current week and gets fresh orders on the first step). v7 (Phase 7:
  `store`, not rented). v8 (Phase 8: `estate`: upgrades, sprinklers, farmhands). v9 (Phase 9:
  `daily`: chores, streak, market special). v10 (Phase 10: `estate.workshops`). v11 (Phase 11: `forage`). v12 (Phase 12: `almanac`, `rank`). v13 (`ownedFields`).

## Rendering

- **3/4 view** in 2D: the ground is a flat top-down grid; standing sprites show their front and
  top, are anchored at their foot point, and are depth-sorted by y (`World.depth(forY:)`).
  Soft contact shadows are separate sprites on the ground.
- **Chunks:** the world is 16 × 16-tile chunks (`ChunkManager`). Chunks on screen load
  immediately; nearby ones trickle in one per frame; far ones unload (with hysteresis). The map can
  grow large without more nodes on screen.
- **Pixel art** (`Art/PixelArt.swift`): placeholders are painted at 128 px per tile, then shrunk
  4× (32 px per tile, the Blender art's grid) for the world and for UI images, with hard alpha edges (soft effects keep a
  few alpha steps), a dark one-pixel outline around standing sprites and item icons, a
  saturation and contrast boost and a stepped palette. Textures use nearest-neighbour filtering;
  SwiftUI shows catalog images with `.interpolation(.none)`. `PixelArt.worldShrink` sets the pixel size.
- **Night light** (`World/NightLight.swift`): the night grade is a cool blue multiply; above it,
  glowing things add warm light. Lamp posts, the farmhouse and lit buildings cast a pool of light
  on the ground (a warm radial texture in flat rings, additive, faded in with the night like the
  window glows), and fireflies (a particle emitter in the object layer, kept over the visible area)
  drift and blink on dry nights outside winter.
- **Breeze** (`World/WindSway.swift`): trees, bushes, grass tufts and flowers sway through one
  shared fragment shader. The trunk (a share of the sprite from the bottom) stays still and each
  row above leans sideways by a whole number of texels, more towards the top, so pixels stay crisp
  squares. Each sprite passes its own numbers as shader attributes (lean, still share, speed,
  phase from its position), so neighbours sway out of step; the lean is set in tiles, so it looks
  the same at any pixel size. It replaced rotating the whole sprite, which smeared the pixels.
- **Terrain:** one sprite per chunk. Its texture is a tiny splat map (dirt/gravel/asphalt
  weights). A fragment shader blends seamless detail textures and pushes the edges through noise,
  so borders look organic rather than tiled; it snaps to the same 32-per-tile pixel grid. One draw
  call per chunk.
- **Draw order** (`ZLayer`): ground → flat things/shadows → standing objects → day/night grade
  (a multiply overlay) → the screen-edge vignette (`fx_vignette`, on the camera) → additive night
  lights (windows) → debug.
- **HUD look** (`UI/HUDStyle.swift`, enum `HUD`): wood and paper pixel art at 2 pt per art
  pixel (the world's pixel size at the normal zoom). Stretchable frames (`PixelFrame`: the
  catalog's `ui_hud_*` 9-slices, fixed corners, tiled edges and middle) for paper panels
  (`hudPanel()`), the wooden tool tray, paper slots and painted board buttons
  (`HUDBoardButtonStyle`, orange or plain wood); square paper buttons (`HUDButtonStyle`) press
  down a pixel instead of scaling, so pixels stay crisp; bars step in whole art pixels
  (`HUDBar`); icons are 12-pixel art at 24 pt (`HUDIcon`). Ink-brown type in Fredoka (bundled,
  SIL Open Font License, registered at launch with CoreText; the system rounded font if it's
  missing). The art is generated by `art/hud/make_hud.py`; the look was agreed on the mock in
  `art/style_test`.
- **Title screen** (`UI/TitleScreenView.swift`): one pixel-art picture of the farm at dusk
  (`ui_title_scene`, made by `art/title/make_title.py` from the Blender sprites rendered at 16 px
  per tile), shown at whole points per art pixel (at least 2) and held to the bottom of the screen
  so any cropping takes sky. What moves is drawn over it in a `TimelineView` + `Canvas` on the same
  pixel grid: twinkling stars, chimney smoke, fireflies. The launch screen (`Acres-Info.plist`,
  merged with the generated Info.plist) is the sky's night blue (`LaunchBackground`).
- **Menus and celebrations** (`UI/GameStyle.swift`): the HUD's pixel art carried into every
  sheet, with no stock iOS chrome. `MenuSheet` is every menu's frame (a leather band with an
  icon, the title, an optional accessory such as `HeaderCoins`, and a close button, over tiled
  `PaperBackground`); pages are built from `card()` (9-slice `ui_card`), `InsetPanel`,
  `PageHeading`, `PaperNote` (empty lists), `PaperTag` (small labels like "Level 4"), `PixelRule`,
  `HUDBar`, `PaperTabs` (tabs and segmented choices), `PaperToggleStyle` (switches) and
  `paperConfirm` (an "are you sure?" card; `ConfirmRequest` lets a page ask over the whole sheet;
  with no cancel button it is the launch-time save notice). Buttons are painted boards
  (`CandyButtonStyle`, `ui_board_*`) or paper slots (`SlotButtonStyle`); both press down a pixel.
  Pictures in menus are `MenuIcon`, which maps the SF symbol names the game uses (shops, clients,
  tile inspections, worker jobs) to 12-pixel icons from `art/hud/make_hud.py` and falls back to
  the symbol in ink. Celebrations share `RewardCard` (sunburst, ribbon title, paper). Only the
  debug panel (debug builds) keeps the system look.
- **Day/night:** `DayNightCurve` (core, tested) gives a tint and a night-light strength per hour.
- **Frame rate:** capped at 60 fps (also on ProMotion screens) for battery life and consistent
  behavior.

## Art pipeline

1. `AssetManifest` lists every asset: name, world size in tiles, recommended pixels, anchor, phase
   and art notes. `docs/ASSETS.md` is generated from it (`swift run acres-tools assets`), and a
   test fails if the doc is stale.
2. `AssetCatalog.texture(name)` looks for real art in `Assets.xcassets` (used as is: deliver pixel
   art at 32 px per tile), then a procedural placeholder (`PlaceholderPainter`, put on the pixel
   grid by `PixelArt`), then shows a magenta checkerboard.
3. Sprites are sized from the manifest, not from the image, so art at any resolution drops in.
4. Real art is modelled in Blender from Python (`art/blender/`): one model function per sprite,
   rendered with a fixed orthographic camera at a 40° pitch, toon light in flat bands tinted from
   cool shadow to warm light, textured surfaces (varied boards, shingles, leafy clusters), then
   shrunk to 32 px per tile (each pixel the most common colour of its samples, so edges stay
   crisp) with the same colour punch and outline as
   `PixelArt`, so rendered and drawn sprites sit together. Size and anchor come from
   `docs/ASSETS.md`, so a render always fits its slot. Overlays (night lights, truck loads) are
   rendered with the rest of the model as a holdout, so they line up. The scripts are dev
   tooling (the `bpy` module, Pillow, NumPy); the app itself stays dependency-free, and the PNGs
   are committed so building the app never needs Blender. Points the game attaches effects to
   (the farmhouse chimney's smoke) come from the model (`screen_point`), not the placeholder layout.

## Input model (Phase 5)

Tap to walk and work: the farmer walks to what you tap and does the job there. A one-finger drag
that *starts on a field* lines up a row of jobs; a drag anywhere else pans; two fingers always pan
and zoom. While driving, taps set the destination and drags look around. (Phases 1–4 had no
avatar and farmed wherever the truck was parked; Phase 5 replaced that with the farmer.)


**Tool belt (after Phase 7).** Farming input is explicit: the player picks a tool (`BeltTool`, app
side) and taps or drags only ever do that tool's job, checked by `Farming.toolAction` (core).
The hand walks, picks and tends animals; one-finger drags with a field tool paint jobs, two
fingers move the camera. Plant jobs carry the packet that was in hand when they were lined up.
## Adding content

- **Map objects:** `HomeValleyMap.swift` (`place` for landmarks, `scatter` for nature). Every
  object kind needs a manifest entry (a test checks this).
- **Art:** add a manifest entry, then either a painter case or a real PNG.
- **Numbers:** `Balance.swift`.

## Known limitations

- The core is compiled and tested on Linux; the app code is type-checked there against stand-in
  modules, so each change's first real build happens in Xcode.
- Sound effects are synthesized placeholders until recordings are added; there is no music yet.
- The shop and the farmhands only work while the game is open (like the calendar); crops,
  animals and sprinklers keep going while it's closed.
- Placeholder art is drawn procedurally at startup (well under a second). If that grows, it can
  be cached to disk or moved off the main thread.
- Crop sprites use individual textures. Big fields may want a runtime texture atlas so SpriteKit
  can batch them (Phase 8 performance pass).
- There is one market, with one price per item per day that falls as you sell. Contracts (Phase 6)
  and your own shop (Phase 7) are the other ways to sell; the shop only sells while the game is open.
- Animals are delivered straight to their pen; carrying them home in the truck could come later.
- Old wooden fences don't block the truck (they run along tile edges); pens, trees and
  buildings do.
