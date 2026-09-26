# Acres

A cozy, top-down open-world farming and business game for iPhone. You start with a run-down
farm and a beat-up pickup truck, then grow it into an agricultural empire.

**Status: Phase 1 (Foundation) is done.** Phase 2 (Farm) starts when you say so.

| Phase | Scope | Status |
|---|---|---|
| 1 | Foundation: architecture, save/load, time system, camera, placeholder art | ✅ |
| 2 | Farm: fields, planting, watering, growth, harvest, inventory, offline growth | ⏳ next |
| 3 | Truck and world: driving, village, first market | |
| 4 | Animals and trees | |
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

## Phase 1: what to test

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
> The simulation core is compiled and unit-tested there (56 tests). The iOS app code is
> type-checked against stand-ins for UIKit/SpriteKit/SwiftUI, but it has **not** been compiled
> by Xcode or run in the Simulator yet. Your first build is that check; if Xcode reports any
> error, paste it and I'll fix it right away.

## Project layout

```
Acres.xcodeproj
Acres/                      iOS app (SwiftUI + SpriteKit): rendering, input, UI
  App/                      AcresApp, GameController (owns the simulation), Haptics
  UI/                       HUD, Welcome-back card, debug panel, theme
  World/                    GameScene, camera, chunk streaming, terrain shader, sprites
  Art/                      AssetCatalog + procedural placeholder painters
  Resources/Assets.xcassets Real art goes in Art/ (see docs/ASSETS.md)
Packages/AcresCore/         Pure Swift simulation (no UIKit/SpriteKit), plus unit tests
  Balance/                  Balance.swift: every tunable number
  Time/                     Game clock and calendar
  Sim/                      Simulation stepping, offline catch-up
  Save/                     Versioned save files, migrations, file store
  World/                    Map data, the Home Valley map
  Content/                  Asset and audio manifests
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
