# Acres

A cozy, top-down open-world farming and business game for iPhone. You start with a run-down
farm and a beat-up pickup truck, then grow it into an agricultural empire.

**Status: Phase 3 (Truck and world) is done.** Phase 4 (Animals and trees) is in progress.

| Phase | Scope | Status |
|---|---|---|
| 1 | Foundation: architecture, save/load, time system, camera, placeholder art | ✅ |
| 2 | Farm: fields, planting, watering, growth, harvest, inventory, offline growth | ✅ |
| 3 | Truck and world: driving, village, first market, tutorial | ✅ |
| 4 | Animals and trees | ⏳ next |
| 5 | Economy depth: markets, prices, contracts | |
| 6 | Properties, buildings, workers | |
| 7 | Progression, collection book, seasons, day/night polish | |
| 8 | Polish: audio, particles, weather, performance, balancing | |

## Running it

Requirements: **Xcode 16 or newer** (the project uses Xcode 16's folder-synced groups) and an
iOS 17+ simulator or iPhone. No third-party dependencies.

1. Open `Acres.xcodeproj`.
2. Pick an iPhone simulator (e.g. iPhone 16) and press **Run** (⌘R).
3. For a real device: select the *Acres* target → *Signing & Capabilities* → choose your Team.
   You may need to change the bundle ID (`com.acresgame.Acres`) to something unique.

Tests: press **⌘U** in Xcode (runs the simulation tests in `AcresCore`), or from a terminal:

```sh
cd Packages/AcresCore
swift test
```

## Phase 3: what to test

Your save carries over (it migrates to save format v3: a full tank, an empty truck bed, and the
tutorial). **Time changed:** there is no clock any more, just crop countdowns and a gentle
day/night lighting cycle. The top-right pill shows the season and how long until the next one.

1. **Tutorial.** A card at the bottom walks you through plow → plow a row → plant → water →
   harvest → load → drive → sell → buy seeds. The spot to tap glows in the field and the right
   button pulses. *Skip* ends it; ⚙️ Settings → *Restart the tutorial* brings it back.
2. **Drive.** Tap **Drive** (bottom left) or the truck itself. With the default *joystick*
   controls, put a thumb anywhere and drag: a stick appears under it. The camera follows the truck.
   Asphalt is fastest, grass slowest; gravel and dirt slide a little in turns. Hitting a fence,
   tree or building gives a bump. Tap **Park** to get out (the truck also parks itself when you
   leave the app).
3. **Tap to drive.** ⚙️ Settings → Driving → *Tap to drive*. While driving, tap anywhere: the truck
   finds its own way there (a flag marks the goal). Touching the joystick in joystick mode or a
   bump cancels the route.
4. **Load.** At the farm, open the basket: the **Truck bed** section (30 slots) has *Load all*
   and a *Load* button per crop; the arrows on the chips unload again. Loading only works with
   the truck parked at the farm.
5. **The village** is east along the road: a gas station, a seed shop, a market square with
   stalls, cottages and street lamps that glow at night.
6. **Sell.** Stop inside the market square: a gold **Sell at Village Market** button appears.
   Sell one, all of a crop, or *Sell everything*. Prices change daily inside each crop's range
   (↑ = good day to sell). With an empty truck the market shows today's prices instead.
7. **Buy seeds.** Stop at the seed shop: buy 1 or 10 of any unlocked seed (pumpkins and others
   show the level they unlock at).
8. **Fuel.** The fuel gauge appears under the season pill while driving. Stop at the gas station
   to fill up (you pay for what you fill). Run dry and the truck limps along at a third of its
   speed, so you can always get to the pumps.
9. **Debug extras:** *Fill the tank*, *Skip / Restart the tutorial*.

## Phase 2: what to test

Your Phase 1 save carries over (it migrates to save format v2 and gets the starting seeds).

1. **Plow.** Tap a grass or dirt tile inside the fence: it becomes plowed soil (weeds and pebbles
   on it disappear). Tapping outside the fence says the land isn't yours yet.
2. **Plant.** Tap plowed soil: it plants the packet shown on the **seed button** (bottom right,
   next to the basket). Tap the seed button to pick another packet; out-of-season seeds are dimmed.
   You start with 12 wheat, 8 carrot and 4 potato seeds.
3. **Water.** Tap a freshly planted crop: it gets watered (the soil darkens). Wet soil lasts
   ~10 minutes; watered crops grow twice as fast as dry ones.
4. **Grow and harvest.** Crops grow through 5 visible stages. Since Phase 3, wheat takes 30 s
   watered, carrots 1 min, potatoes 2. Ripe crops twinkle; tap to harvest ("+3" floats up, XP
   fills the level bar).
5. **Drag-to-paint.** Put one finger on a tile you can act on and drag: it plows / plants /
   waters / harvests every tile you pass. Starting a drag anywhere else moves the camera; two
   fingers always move and zoom.
6. **Long-press** any tile for info ("Ready in 2m 10s · Thirsty").
7. **Basket** opens farm storage (100 slots; seeds don't count) and ⚙️ Settings (harvest
   reminders, haptics). When storage is full, harvesting stops and ripe crops wait in the field.
8. **Offline growth.** Plant, then close the app for a few minutes (or 🐞 → *Pretend I was away*):
   the Welcome card lists what's ready, what's still growing and what's thirsty.
9. **Harvest reminder.** Plant something, allow notifications when asked, leave the app: you get
   a notification when the fields are ready.
10. **Debug extras:** +10 of every seed, water all, ripen all, empty storage.

## Phase 1: what to test

(The clock and "Good morning!" banner described here were replaced in Phase 3 by timers and a
lighting-only day/night cycle.)

1. **Launch.** You see the run-down farm: an old farmhouse with chimney smoke, a faded red barn,
   a broken fence, an overgrown field, a pond, the teal pickup parked in the yard, forest to
   the north and a road to the east. The HUD shows coins (500), *Lv 1*, *Spring 1* and the time.
2. **Camera.** Drag to pan (it glides after you let go), pinch to zoom (it zooms around your
   fingers), two fingers pan and zoom at once. You can't scroll past the world edge.
3. **Tap.** Tapping the ground highlights that tile. Tapping the truck glides the camera to it.
4. **Time.** The clock advances ~1.2 in-game minutes per real second (a day = 20 minutes).
   Open the 🐞 debug panel → *Speed 60×* to watch a full day in 20 seconds: warm morning, bright
   noon, orange evening, blue night with glowing farmhouse windows. At 06:00 a banner says
   *Good morning!*; after day 7, *Summer has arrived*.
5. **Save and restore.** Pan somewhere, wait a few seconds, then force-quit (swipe up in the app
   switcher) and relaunch. You're back at the same spot and time. Autosave runs every 30 s and
   whenever the app goes to the background.
6. **Offline catch-up, the real thing.** Close the app for 2+ minutes and reopen it: a
   *Welcome back!* card says how long you were away and the clock is exactly where you left it.
   Close it for over an hour: you wake at 06:00 the next morning.
7. **Offline catch-up, the fast way.** Debug panel → *Pretend I was away* → 10 minutes / 2 hours
   / 12 hours / 5 days. 5 days shows the gentle "only catches up on 3 days" note.
8. **Debug extras:** chunk borders (the world streams in 16 × 16-tile chunks), FPS / node /
   draw-call counters, *Save now*, *Reset farm*.

Please report anything that doesn't build or look right; screenshots of the placeholder art are
especially helpful, since that art is drawn entirely in code.

> **A note on how this was built:** development happens in a Linux cloud container without Xcode.
> The simulation core is compiled and unit-tested there (100+ tests). The iOS app code is
> type-checked against stand-ins for UIKit/SpriteKit/SwiftUI; each phase's new screens are first
> compiled by Xcode on your Mac. If Xcode reports any error, paste it and I'll fix it right away.

## Project layout

```
Acres.xcodeproj
Acres/                      iOS app (SwiftUI + SpriteKit): rendering, input, UI
  App/                      AcresApp, GameController (+Driving, +Trade, +Tutorial), Haptics
  UI/                       HUD, shops, inventory, Welcome-back card, debug panel, theme
  World/                    GameScene, camera, chunk streaming, terrain shader, sprites
  Art/                      AssetCatalog + procedural placeholder painters
  Resources/Assets.xcassets Real art goes in Art/ (see docs/ASSETS.md)
Packages/AcresCore/         Pure Swift simulation (no UIKit/SpriteKit), plus unit tests
  Balance/                  Balance.swift: every tunable number
  Time/                     Game clock and calendar
  Sim/                      Simulation stepping, offline catch-up, away summary
  Farm/                     Crop growth, farming rules and actions, forecasts, XP
  Driving/                  Truck physics, A* pathfinding, autopilot
  Trade/                    Shops, market prices, buying, selling, fuel, loading
  Save/                     Versioned save files, migrations, file store
  World/                    Map data, the Home Valley map
  Content/                  Crops, items, properties, asset and audio manifests
docs/
  ARCHITECTURE.md           How it fits together, and the design decisions made so far
  ASSETS.md                 Every asset the game needs (generated)
```

## Tweaking the game

- **Numbers:** `Packages/AcresCore/Sources/AcresCore/Balance/Balance.swift`.
- **Art:** drop a PNG named exactly like an entry in [`docs/ASSETS.md`](docs/ASSETS.md) into
  `Acres/Resources/Assets.xcassets/Art/`. It replaces the placeholder with no code changes.
- **The map:** `Packages/AcresCore/Sources/AcresCore/World/HomeValleyMap.swift`.
  `swift run acres-tools map-dump` in `Packages/AcresCore` prints it as text.

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the details.
