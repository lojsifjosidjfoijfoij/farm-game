# Web version

A browser version of Acres for portals such as CrazyGames: an endless farming game where the numbers climb
past billions into names like Qa and Sx and beyond, with three layers of starting over. It's a rewrite in
TypeScript, not a build of the Swift app. The art comes straight from the iOS asset catalog, and the crop
prices and base rules come from `AcresCore`.

"Valley Farm" is a working title, because the name Acres is taken by another farming game. To change it,
edit `GAME_TITLE` in `src/main.ts`, the `<title>` in `index.html`, and `SAVE_KEY` in `src/core/save.ts`.

## Running it

Needs Node 20 or newer.

```sh
npm install
npm run dev
```

## Tests

```sh
npm test
```

`src/core/pacing.test.ts` plays the game with a simple bot and prints a timeline of each rebirth, trophy
and ascension. Check it after changing any number. It plays two hours by default. For a longer look:

```sh
VITE_PACING_HOURS=96 npx vitest run src/core/pacing.test.ts
```

## The climb

- **Endless upgrades:** Better Seeds and the rest have no last level. Each costs more than it pays back,
  which is what makes a rebirth worth taking.
- **Rare crops:** Golden, Rainbow, Cosmic and Void crops are rolled as a plot ripens and pay 5× to 1,000×.
- **Automation:** the Seed Drill, Market Driver, Irrigation and Foreman take over the clicking in turn.
- **Rebirth:** a new farm, ×1.5 on every crop, and Golden Seeds to spend on permanent perks.
- **Exotic crops:** a new one every 4 rebirths, for ever. They're the plain crops recolored in code.
- **Ascend:** after 10 rebirths, trade them and your Golden Seeds for stars. Each star doubles every crop.
- **Big bang:** at a googol coins on one farm, a new universe and ×1,000 on every crop.
- **Trophies:** one for each 1,000× more coins earned, with no last one. Each adds 20% for good.

From the bot, playing nonstop with perfect timing: first rebirth at 2.7 hours, second at 5.5 hours, fourth at
23 hours. A real player will be slower, and it stays far out of reach of a big bang. Money stops at 1e300
rather than overflowing.

## Building for upload

There are two builds, because CrazyGames rejects a game whose ad buttons do nothing, and ads are off during
Basic Launch:

```sh
npm run package       # farm-web.zip: no ad buttons, for Basic Launch
npm run package:ads   # farm-web-ads.zip: ad buttons on, for Full Launch
```

Both connect to the CrazyGames SDK and put `index.html` at the root of the archive. Turn on the "Progress
Save" option when submitting, or the SDK's cloud saves stay off. To check load time and errors in Chrome:

```sh
npm run build
node promo/check-load.mjs
```

## Ads

- The Market offers Coin Boost and Skip Time, each for coins or, in the ads build, for watching an ad. Both
  ways share a 3-minute cooldown.
- In the ads build, the welcome-back card offers to double what the farm earned, and a rebirth is followed
  by a break ad if the SDK says one is due.
- Rewards only come from `adFinished`. The game is paused and blocked while an ad is requested or playing.
- Ad buttons stay in menus, because the rules forbid them on the active play screen. If the SDK reports ads
  disabled or blocked, they disappear and the game carries on.

## Covers and videos

`promo/` makes the images and videos a portal asks for, from the game's own models and the game itself. If
the game's name changes, make them again: the title is read from `GAME_TITLE`.

```sh
uv run --python 3.11 --with "bpy==4.5.*" --with pillow --with numpy \
  python promo/cover_scene.py landscape promo/renders/landscape.png --samples 48
# The same for portrait and square, then:
npm run promo
```

The results land in `promo/out`, which isn't committed.

## How it's laid out

- `src/core` holds the rules. Nothing in it touches the page, and it mirrors `AcresCore`: same growth,
  market, experience and farmhand rules, written in sim seconds.
- `src/game` draws the world on a canvas, runs the HUD as ordinary HTML, and synthesizes the sound.
  `platform.ts` is the only file that talks to the CrazyGames SDK.
- `src/main.ts` joins the two and handles input.

`src/core/pace.ts` sets how fast time runs: a game day is 45 seconds here and 24 minutes on iOS.

## How it differs from the iOS game

- No walking, driving, energy, seasons, bills or orders. A click does the job and Sell goes to market.
- Seeds are paid for as you plant them, so there's no trip to the seed shop.
- A farmhand's harvest gives the farmer half the experience. With none, hiring help stops you levelling.
- Farmhands cost a one-off fee instead of weekly wages.
- Land is priced for this smaller map, and the farmhouse tiers each add 5% to market prices.
- Everything under "The climb" is new here. None of it is in the iOS game.
