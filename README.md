# Acres

A cozy, top-down farming and business game for iPhone: a farmer's version of Big Ambitions.
You start with a run-down farm, a beat-up pickup truck and one farmer, and grow it into an
agricultural empire.

**Status: phases 1–10 are done.** Next: fishing, foraging and goats, then the almanac, farm ranks and an ending.

| Phase | Scope | Status |
|---|---|---|
| 1 | Foundation: architecture, save/load, time system, camera, placeholder art | ✅ |
| 2 | Farm: fields, planting, watering, growth, harvest, inventory, offline growth | ✅ |
| 3 | Truck and world: driving, village, first market, tutorial | ✅ |
| 4 | Animals and trees: pens, livestock market, woodlot, saplings, fruit | ✅ |
| 5 | The farmer's life: a farmer you walk around, clock and days, energy and sleep, tap-to-drive, goals, new HUD | ✅ |
| 6 | Contracts and deliveries, weekly bills, a bank loan | ✅ |
| 7 | Your own shop in town: rent, stock, prices, customers | ✅ |
| 8 | Hired workers; buy land, buildings and machines | ✅ |
| 9 | Polish: daily chores and streaks, market specials, weather, seasons, sound, celebrations | ✅ |
| 10 | More to do: nine new crops, workshops and artisan goods, the Valley Deli | ✅ |

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

## Phase 10: what to test

Your save carries over (format v10: no workshops yet).

1. **Nine new crops** (seed shop): lettuce and onions (spring and autumn), kale (winter and
   spring), tomatoes and blueberries (summer, pick again and again), garlic and cabbage (autumn
   and winter), sunflowers (summer) and melons (summer, level 7). **Winter has crops now.**
2. **Workshops** (phone → Farm → *Workshops*): buy one, tap **Place**, tap grass on your land.
   Tap a workshop: the farmer walks over and its panel opens. Pick a recipe, **Make** (or **×5**):
   the goods come out of storage and the timer starts (it keeps going while the game is closed).
   A bubble over the workshop means the goods are ready: tap it and **Collect** (XP!).
   - Sawhorse (level 2): logs → planks. Mill (3): wheat → flour, corn → cornmeal.
   - Beehive (3): honey on its own, every two days (holds two jars; collect to keep it going).
   - Jam kitchen (3): strawberry and blueberry jam, tomato sauce.
   - Pickling crock (4): pickled onions, sauerkraut. Cheese press (4): cheese (and goat cheese, later).
   - Juice press (5): apple, carrot and cherry juice. Oil press (5): sunflower oil. Loom (6): cloth.
   Goods are worth clearly more than what goes in, and sell at the market, in your shop and to clients.
3. **The Valley Deli** (a new client in the village): orders cheese, jam, honey, juice, oil,
   pickles and cloth. The diner and the bakery order flour, cornmeal, sauce and juice too; the
   lumber yard takes planks.
4. **A workshop hand** (Farm → Farmhands): collects finished goods and restarts idle workshops on
   their last recipe while storage has what they need.
5. **Goals and chores:** *Handmade* (set up a workshop), *Artisan* (make 50 goods), and a daily
   chore to make goods once you have a workshop. Pick up an empty workshop from its panel to move it.

## Phase 9: what to test

Your save carries over (format v9: today's chores start with your next morning).

1. **Today's chores:** three small jobs every morning (plant, water, harvest, sell, collect eggs,
   finish an order, chop trees, shop sales … depending on what your farm does). The chip under the
   goal tracker shows how many are done and glows when a reward is waiting; the goals sheet lists
   them with **Claim** buttons. Finish all three for a bonus. Doing them every day builds a
   **streak** 🔥 that makes the bonus bigger (up to a week); skipping a day resets it.
2. **Market special:** each morning one thing you can make pays 50% more at the market today (a
   gold *Special* badge in the market; the morning message says what it is).
3. **Weather:** sunny, cloudy, rain and (in winter) snow, fixed per day. **Rain waters every field**
   all day, and the soil stays wet a while after. The clock shows the weather; the sky dims and
   rain or snow falls. The morning message warns when rain is forecast for tomorrow.
4. **Seasons you can see:** trees change their leaves (spring blossom, autumn colors, bare winter
   branches), the grass turns golden in autumn and frosty in winter, with snow lying on snowy days.
5. **Sound:** placeholder sound effects for plowing, planting, watering, harvesting, chopping,
   coins, level-ups, goals, the truck door and bumps, and a soft "nope". Real recordings named like
   `docs/ASSETS.md` (e.g. `sfx_coin.m4a`) replace them. Basket → Settings → *Sound effects* turns
   them off; the phone's mute switch silences them too.
6. **Celebrations:** coins float up from the money counter (+/−) whenever it changes; leveling up
   shows a card with confetti and everything it unlocks. **Tap the level pill** for *What's next*:
   the coming levels and what each one brings.
7. **Balance:** chores pay modestly (a little XP, some coins), so levels still come mainly from
   farming.

## Phase 8: what to test

Your save carries over (format v8). Everything is on the phone's new **Farm** tab.

1. **Land for sale:** four parcels around the farm, each with a FOR SALE sign: East Meadow
   (2,500, level 2), North Woods (4,000, level 4, full of timber), West Field (6,000, level 5) and
   South Pasture (12,000, level 7). Tap the land (or the sign's area) for its card, or buy it on
   the Farm tab. Bought land can be plowed and its trees chopped; each parcel adds 100 coins of
   property tax on Mondays.
2. **Buildings:** a storage shed (+150 storage, level 2), then two silos (level 4 and 6) appear by
   the road south of the fence. A bigger truck bed (90, then 130 items per trip).
3. **Sprinklers** (level 3; big ones at level 7): buy one, tap **Place**, then tap grass in your
   fields. The farmer walks over and sets it up; it keeps the 8 tiles around it (5 × 5 for the big
   one) watered day and night, even while the game is closed. Tap a sprinkler to pick it up.
4. **Farmhands** (first at level 4, then 6 and 8; 350 coins a week each, the first week pro-rated):
   a *field hand* waters thirsty crops and harvests ripe ones into storage; an *animal keeper*
   collects, fills troughs and feeds. They work 08:00–17:00 while you play, walk to each job and
   go home in the evening. Switch a farmhand's job or let them go on the Farm tab. Their harvests
   don't give you XP: levels still come from your own work.
5. **Money tab:** wages, land and buildings show up in the weekly books and Monday's bills.
6. **New goals:** *More room*, *Room to grow*, *Rain maker*, *A helping hand*.

## Farming tools (new): what to test

Farming no longer guesses what you mean. A **tool belt** sits above the bottom buttons:

- **Hand** (glove): tap to walk, pick ripe crops and fruit, tend animals, open the house. Dragging
  with the hand moves the map. It never plows or plants.
- **Hoe:** tap or drag over grass on your land to plow. Only plows.
- **Seeds** (shows the packet in hand and how many): tap or drag over plowed soil to plant that
  packet. Tap the bag again to pick other seeds (or saplings). If the packet runs out mid-row, the
  farmer stops and asks instead of switching seeds.
- **Watering can:** tap or drag over crops to water them.
- **Sickle:** tap or drag over ripe crops to harvest.
- **Axe:** tap a grown tree to chop it, or a stump to clear it (the hand only picks fruit).

With a tool in hand, a one-finger drag on the field lines up that tool's job on every tile it
crosses (nothing else); **two fingers move and zoom the map**. A line above the belt says how to
use the tool in hand. The tutorial now teaches picking the tools.

## Phase 7: what to test

Your save carries over (format v7: the corner shop is waiting, for rent).

1. **The corner shop** stands on the village street between the gas station and the seed shop,
   with a *FOR RENT* sign. Drive there (map → *Corner Shop · for rent*) and tap **Corner Shop ·
   for rent**. From **level 3** you can rent it: 250 coins a week, paid with Monday's bills (the
   first payment only covers the days until Monday).
2. **Stocking:** park the truck in front and tap **Open your shop**. *Stock everything from the
   truck* puts all sellable goods on the six shelves (25 each; the most valuable first), or tap a
   single item in the row below it. *Take back* returns a shelf to the truck.
3. **Prices:** each shelf has − and + buttons (steps of 5%, from −40% to double the usual price).
   The card shows the price, the markup and how many sell per day. Cheaper sells faster; dearer
   earns more per sale. About +25% earns the most per hour. More different goods on the shelves
   bring more customers.
4. **Customers:** villagers walk in off the street while the shop is open (09:00–18:00, while you
   play; the shop is shut while the game is closed). Every sale pays at once and shows in the
   books as *Shop sales*. The *OPEN* chalkboard is out during opening hours. A banner tells you
   when a shelf sells out.
5. **The phone** has a new **Shop** tab: today's takings, this week's shop sales and every shelf's
   stock, so you know when to restock. Prices are changed in the shop itself.
6. **Giving it up:** with empty shelves, *Give up the shop…* at the bottom ends the lease (no more
   rent from next Monday).
7. **New goals:** *Open for business* and *Shopkeeper*.
8. **Debug extras:** *Load the truck with goods* (carrots, potatoes, eggs, apples, logs).

## Phase 6: what to test

Your save carries over (format v6: your books start this week, the first orders are waiting on
your phone).

1. **The business phone** (the round phone button next to your coins). Two tabs:
   - **Orders:** new orders from clients in the valley, each with the goods, the pay, the XP and
     how many days you get. It also shows how many of those goods you already have on the truck or
     at the farm. *Accept* up to 3 at a time; *Not now* removes an offer. New orders come in every
     morning and stay up for two days.
   - **Money:** coins, this week's income and expenses by category (market sales, orders, seeds,
     fuel, repairs …), Monday's bills, your loan, and last week's totals.
   A gold dot means there are new orders; the badge counts your orders in progress (red: one is
   due today).
2. **Clients:** *The Rusty Spoon* (a diner on the village street, 07–22: vegetables, eggs, milk,
   truffles), *Hansen's Bakery* (up the county road, 05–17: wheat, eggs, milk, fruit) and *North
   Woods Lumber* (the lumber yard in the northern woods, 07–18: logs). They're on the map menu too;
   the ones you have orders from are listed first.
3. **Delivering:** load the goods at the farm, drive to the client and stop on the gravel in front.
   Tap **Deliver to …**. Everything on the truck that an order needs is handed over; a finished
   order pays at once. With goods for an order on the truck, the guide arrow points to the client.
4. **Deadlines and reputation:** an order not finished by its due day is cancelled and costs
   reputation (shown on the Orders tab). Finishing orders raises it; better reputation means
   bigger, better-paid orders. Missed deadlines overnight are reported when you wake up.
5. **Weekly bills:** every Monday at 06:00 the property tax (100 coins per property) and any loan
   instalment are paid, and a card sums up the week that ended. If the coins run short, you go
   into debt (red money pill): buying stops until you're back above zero.
6. **The bank** (Valley Savings Bank, east of the market square, 09–16): borrow 1,000 coins now
   (5,000 at level 4, 20,000 at level 8), paid back with 12% interest in weekly instalments on
   Mondays. One loan at a time; you can pay it off early at the bank.
7. **New goals:** *First order* and *Reliable supplier*.
8. **Debug extras:** *Skip to Monday (bills day)*.

## Phase 5: what to test

Your save carries over (format v5: the farmer appears at the farmhouse door, rested, and the goal
ladder starts). **The pace changed a lot:** one game day now takes 24 real minutes, crops take
days (wheat 1, pumpkins 6), eggs and milk come daily, and you water once a day.

1. **The farmer.** A little farmer in a straw hat stands at the farmhouse door. Tap a field tile:
   they walk over and do the job (plow with a hoe, water with a can, plant and harvest by hand).
   Tap more tiles while they work to line up jobs (small gold markers); **drag across the field**
   to line up a whole row. The chip "5 jobs lined up · Stop" cancels the line. Tapping plain
   ground just walks there.
2. **Trees and pens** work the same way: the farmer walks to the trunk (axe) or the pen gate.
   Repairs and "Chop down" (fruit trees) are buttons on the info card; the farmer walks over and
   does them.
3. **The clock.** Top right: the day and time ("Mon 06:00"), the season and the week. The sky
   follows the clock: sunrise, noon, golden hour, night.
4. **Energy.** The bar under the clock drains slowly while awake and with every job. At 0 the
   farmer walks slowly and can't work. **Sleep:** tap the bed button (appears from 20:00 or when
   tired) or the farmhouse → *Go to bed*. The farmer walks home, the screen fades, the night
   passes (the farm keeps growing) and you wake at 06:00, rested. Staying up past 02:00, the
   farmer falls asleep where they stand and wakes only half rested.
5. **Driving is tap-only.** Tap **Drive** (or the truck): the farmer walks over and hops in. Then
   tap anywhere to drive there, or use the **map button** (GPS) to pick a place: Home farm, the
   market, the seed shop, the gas station or the livestock market. Drag to look around while
   driving; the camera catches up at the next tap. **Get out** parks.
6. **Opening hours.** Seed shop 08–18, market 07–19, livestock 08–17, gas station always open.
   You can walk into shops, but selling needs the truck at the market (that's where the goods
   are). A closed shop says when it opens.
7. **Goals** (top left, under the level): what to aim for next, with coin rewards. Tap it for the
   list; finished goals pulse and are claimed with a tap.
8. **Tutorial:** now teaches walking, lining up jobs and sleeping to the next day. ⚙️ Settings →
   *Restart the tutorial* to see it.
9. **Debug extras:** *Jump to 20:00*, *Refill the farmer's energy*, plus the Phase 4 tools.

## Phase 4: what to test

Your save carries over (format v4: empty, run-down pens and every tree still standing). Your
farm also grew: it now includes the **backyard** behind the field fence, with four old pens and
a small woodlot. Storage grew from 100 to 150 slots.

1. **Pens.** Pan north past the field fence: a chicken coop, a cow pasture, a sheepfold and a
   pigsty, all run-down (broken fences, empty troughs, a hammer sign). Tap one: its card says
   what it costs to fix up and from which level (coop: level 2, 150 coins). Tap **Repair**.
   (🐞 → *Level up* and *+1,000 coins* help you test quickly.)
2. **Buy animals.** Drive east through the village to the red **Valley Livestock** barn at the
   end of the road (the corral with a cow and sheep). Stop in the yard and tap *Visit Valley
   Livestock*: buy chicks (level 2), calves (4), lambs (5) or piglets (6), plus sacks of feed.
   Each animal gets a name and appears in its pen at once.
3. **Growing up.** Young animals wander around and grow up on their own (chicks in 90 s). A
   banner says "Pip the chick is all grown up!".
4. **One tap per pen.** Grown animals show a bubble with the food they want. Tap the pen: it
   does the next sensible thing, in this order: collect what's ready → fill the trough (if dry)
   → feed the hungry. Chickens eat wheat (or corn, or feed), cows corn or wheat, sheep carrots
   or wheat, pigs potatoes, pumpkins or corn. Fed animals get hearts; a full trough doubles
   production speed. Eggs take 2 min, milk 5, wool 8, truffles 12.
5. **Happiness.** Animals fed with water in the trough get happier; hungry ones slowly get sad.
   Happy animals often give two products instead of one. Long-press a pen (or tap it when there's
   nothing to do) for its card: mood, what's ready, who's hungry, when the next product comes and
   how long the water lasts.
6. **Chop trees.** Tap a full-grown tree in your woodlot (north of the pens): it falls, logs pop
   up, a stump stays behind. Tap the stump to clear it (the ground becomes farmable), or leave
   it: it sprouts again after 8 minutes and grows back. Trees outside your land say so.
7. **Plant trees.** Buy saplings at the seed shop (birch, pine, oak; apple and cherry trees
   bear fruit). Pick a sapling in the seed picker, then tap plowed soil. Growing trees can't be
   chopped; fruit trees are never chopped by a tap (their card has a *Chop down* button). Ripe
   fruit shows on the tree: tap to pick.
8. **Sell it all.** *Load all* now loads eggs, milk, wool, truffles, logs and fruit too (most
   valuable first). The market buys everything, at daily prices. Feed, seeds and saplings aren't
   for sale.
9. **Offline.** Leave with fed animals and growing trees: the welcome card lists products
   waiting, animals that grew up, hungry animals and ripe fruit.
10. **Debug extras:** *Grow up animals, finish products*, *Grow all trees, ripen fruit*,
    *Level up (+1)*.

## Phase 3: what to test

Your save carries over (it migrates to save format v3: a full tank, an empty truck bed, and the
tutorial). **Time changed:** there is no clock any more, just crop countdowns and a gentle
day/night lighting cycle. The top-right pill shows the season and how long until the next one.

1. **Tutorial.** A card at the bottom walks you through plow → plow a row → plant → water →
   harvest → load → drive → sell → buy seeds. The spot to tap glows in the field and the right
   button pulses. *Skip* ends it; ⚙️ Settings → *Restart the tutorial* brings it back.
2. **Drive.** Tap **Drive** (bottom left) or the truck itself. With the default *joystick*
   controls, put a thumb anywhere and drag: a stick appears under it. The camera follows the truck.
   Asphalt is fastest, grass slowest; gravel and dirt slide a little in turns. Hitting a tree,
   building or pen gives a bump (old fences are low enough to drive over). Tap **Park** to get out (the truck also parks itself when you
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
  App/                      AcresApp, GameController (+Farmer, +Tools, +Driving, +Trade, +Business, +Store, +Estate, +Daily, +Juice, +Tutorial, +Ranch), Haptics, Sound
  UI/                       HUD, shops, business phone, your shop, inventory, Welcome-back card, debug panel, theme
  World/                    GameScene, camera, chunk streaming, terrain shader, sprites, trees, pens, shop customers
  Art/                      AssetCatalog + procedural placeholder painters
  Resources/Assets.xcassets Real art goes in Art/ (see docs/ASSETS.md)
Packages/AcresCore/         Pure Swift simulation (no UIKit/SpriteKit), plus unit tests
  Balance/                  Balance.swift: every tunable number
  Time/                     Game clock and calendar
  Sim/                      Simulation stepping, offline catch-up, away summary
  Farm/                     Crop growth, farming rules and actions, forecasts, XP
  Driving/                  Truck physics, A* pathfinding, autopilot
  Trade/                    Shops, market prices, buying, selling, fuel, loading
  Animals/                  Animal simulation, pen rules (repair, collect, water, feed)
  Trees/                    Tree growth, forestry rules (chop, clear, plant, pick)
  Farmer/                   Energy, sleep, goals, daily chores, weather
  Business/                 Clients and contracts, the books (ledger), bills, loans, your shop, places
  Estate/                   Land, storage and truck upgrades, sprinklers, farmhands
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
