import { BALANCE } from './content'
import { availableUpgrades, type Upgrade } from './estate'
import { GOAL_COUNT } from './goalCount'
import { formatNumber } from './numbers'
import { count, hasAutomation, trainingLevel, type GameState } from './state'

/** What Arne points at while a goal is open. */
export type GoalTarget = 'ripe' | 'soil' | 'dry' | 'ground' | 'sell' | 'seeds' | 'farm' | 'market' | 'rebirth' | null

export interface Goal {
  id: string
  /** What Arne says. */
  text: string
  reward: number
  target: GoalTarget
  progress: (state: GameState) => number
  needed: number
  trophy?: boolean
  /** For goals to buy something: its price, so Arne can show the coins saved toward it. */
  saveFor?: (state: GameState) => number
  /** Stops the game once, as this goal starts, to show one part of the screen. */
  card?: { title: string; text: string; spotlight: string }
}

function counter(name: string): (state: GameState) => number {
  return (state) => count(state, name)
}

/** The price of the first thing on the Farm menu that fits, or 0 if it's gone. */
function price(matches: (upgrade: Upgrade) => boolean): (state: GameState) => number {
  return (state) => availableUpgrades(state).find(matches)?.cost ?? 0
}

function owns(id: string): (state: GameState) => number {
  return (state) => (hasAutomation(state, id) ? 1 : 0)
}

/**
 * Arne's goals, one at a time. The first few are the whole tutorial: he says
 * what to do next, in the middle of play, and points at it. After these come
 * trophies, and there's always one more of those.
 */
export const GOALS: Goal[] = [
  // The first harvest: what a farm does, one move at a time.
  { id: 'first_harvest', text: "I left you some ripe wheat. You're welcome. Click it, or drag across the rows.", reward: 0, target: 'ripe', progress: counter('harvestedPlots'), needed: 6 },
  { id: 'first_sale', text: 'Lovely. Now hit Sell, before the wheat gets ideas.', reward: 0, target: 'sell', progress: counter('sales'), needed: 1,
    card: { title: 'This is your storage', text: 'Everything you harvest lands in this crate. It earns nothing sitting there, so sell it. When the crate is full, harvesting stops, and I start judging you.', spotlight: '.stats .chip:nth-child(3)' } },
  { id: 'replant', text: 'Rich at last. Click the bare soil to plant wheat. Seeds cost a few coins. Sorry, I don\'t make the rules. I did, actually.', reward: 0, target: 'soil', progress: counter('planted'), needed: 6 },
  { id: 'water', text: 'Click them again to water. Wet soil is darker and grows twice as fast. Crops are simple like that.', reward: 20, target: 'dry', progress: counter('watered'), needed: 6 },
  { id: 'plow', text: "While that grows, click the grass in your field to plow it. Nothing grows on grass. Well, grass does.", reward: 30, target: 'ground', progress: counter('plowed'), needed: 9 },

  // A tour of the menus, each one as it becomes useful.
  { id: 'open_seeds', text: 'Open your seed list, bottom left.', reward: 0, target: 'seeds', progress: counter('opened:seeds'), needed: 1,
    card: { title: 'Your seed list', text: 'This button shows what you are planting. Click it to see every crop, what it costs, how long it takes and what it earns. Pick one, then click your soil. Press E to open it fast.', spotlight: '.seed-pick' } },
  { id: 'carrots', text: 'Carrots pay better than wheat, and they never complain. Pick them, then plant six.', reward: 40, target: 'seeds', progress: counter('planted:carrot'), needed: 6 },
  { id: 'open_market', text: 'Go have a look at the Market.', reward: 0, target: 'market', progress: counter('opened:market'), needed: 1,
    card: { title: 'The Market', text: 'Sell sells everything at once. The Market shows today\'s prices, and the crop on special pays 50% extra. Sell too much of one crop and its price drops, so grow a mix. Press M to open it.', spotlight: '.actions .action:nth-child(2)' } },
  { id: 'level2', text: 'Keep harvesting by hand and reach level 2. Drag fast: chains pay a combo bonus!', reward: 60, target: 'ripe', progress: (state) => state.level, needed: 2,
    card: { title: 'Your level', text: 'Every harvest fills this star\'s bar. New levels unlock new seeds and new things to buy, and every level makes all crops worth a little more. It never resets, not even when you rebirth.', spotlight: '.chip.level' } },
  { id: 'open_farm', text: 'Open the Farm menu.', reward: 0, target: 'farm', progress: counter('opened:farm'), needed: 1,
    card: { title: 'The Farm menu', text: 'Everything you can buy lives here: land, buildings, helpers and upgrades that never end. Green bars show how close you are. The red number says how many you can afford now. Press F to open it.', spotlight: '.actions .action:nth-child(3)' } },
  { id: 'seeds', text: 'Buy Better Seeds in Farm. I asked the seeds to try harder. It worked.', reward: 100, target: 'farm', progress: (state) => trainingLevel(state, 'seeds'), needed: 1, saveFor: price((item) => item.kind === 'training' && item.id === 'seeds') },

  // Growing the farm.
  { id: 'land', text: 'Your field is full. Save up for East Meadow. It comes with a sign and absolutely no refunds.', reward: 200, target: 'farm', progress: counter('landBought'), needed: 1, saveFor: price((item) => item.kind === 'parcel') },
  { id: 'level3', text: 'Reach level 3. New seeds, and sprinklers, which are basically me but wetter.', reward: 300, target: 'ripe', progress: (state) => state.level, needed: 3 },
  { id: 'sprinkler', text: 'Buy a sprinkler in Farm, then click a spot in your field.', reward: 300, target: 'farm', progress: counter('sprinklersPlaced'), needed: 1, saveFor: price((item) => item.kind === 'machine' && item.id === 'sprinkler') },
  { id: 'storage', text: 'Storage fills fast. Buy the shed. Yes, you are paying for a shed.', reward: 500, target: 'farm', progress: counter('storageUpgrades'), needed: 1, saveFor: price((item) => item.kind === 'storage') },
  { id: 'open_rebirth', text: 'Psst. There is a new button. Open Rebirth.', reward: 0, target: 'rebirth', progress: counter('opened:rebirth'), needed: 1,
    card: { title: 'Rebirth', text: 'Earn enough and you can start a new farm with every crop worth ×1.5, for good, plus Golden Seeds to spend on perks. You lose the farm but keep your level. Sounds mad. Works every time. Press R to open it.', spotlight: '.rebirth-button' } },
  { id: 'first_rebirth', text: `Earn ${formatNumber(BALANCE.rebirthBase)} on this farm, then Rebirth. Don't worry, I've done this nine times.`, reward: 0, target: 'rebirth', progress: (state) => count(state, 'rebirths'), needed: 1 },
  { id: 'worker', text: 'At level 4 you can hire a farmhand. They harvest and water. Their name is Kevin, probably.', reward: 1_000, target: 'farm', progress: counter('workersHired'), needed: 1, saveFor: price((item) => item.kind === 'worker') },

  // Letting the farm run itself.
  { id: 'drill', text: 'Buy the Seed Drill, and harvested plots replant themselves. Witchcraft, but legal.', reward: 2_000, target: 'farm', progress: owns('drill'), needed: 1, saveFor: price((item) => item.kind === 'automation' && item.id === 'drill') },
  { id: 'driver', text: 'Buy the Market Driver. The truck sells while you farm. It has no idea where it\'s going, but it gets there.', reward: 3_000, target: 'farm', progress: owns('driver'), needed: 1, saveFor: price((item) => item.kind === 'automation' && item.id === 'driver') },
  { id: 'watch_rare', text: 'Watch for glowing crops. A Golden one pays five times over. Do not eat it.', reward: 3_000, target: null, progress: counter('mutation:golden'), needed: 1 },
  { id: 'corn', text: 'Grow something bigger. Harvest 20 corn. All ears on you.', reward: 5_000, target: 'seeds', progress: counter('harvested:corn'), needed: 20 },
  { id: 'land3', text: 'Own four fields. A man with four fields is called "sir".', reward: 10_000, target: 'farm', progress: counter('landBought'), needed: 3, saveFor: price((item) => item.kind === 'parcel') },
  { id: 'seeds10', text: 'Get Better Seeds to level 10. They are practically going to university.', reward: 15_000, target: 'farm', progress: (state) => trainingLevel(state, 'seeds'), needed: 10 },
  { id: 'pumpkin', text: 'Pumpkins take patience. Harvest 10. I once waited a whole week and I want that on my gravestone.', reward: 20_000, target: 'seeds', progress: counter('harvested:pumpkin'), needed: 10 },
  { id: 'all_land', text: 'Buy every field in the valley. The neighbours can move.', reward: 30_000, target: 'farm', progress: counter('landBought'), needed: 5, saveFor: price((item) => item.kind === 'parcel') },
  { id: 'million', text: 'Earn a million coins on one farm. Then you can afford my therapy.', reward: 50_000, target: 'market', progress: (state) => state.runCoins, needed: 1_000_000 },
  { id: 'irrigation', text: 'Dig the Irrigation and every plot stays wet.', reward: 50_000, target: 'farm', progress: owns('irrigation'), needed: 1, saveFor: price((item) => item.kind === 'automation' && item.id === 'irrigation') },
  { id: 'farmhouse', text: 'The old house has seen better days. So have I. Patch it up.', reward: 50_000, target: 'farm', progress: (state) => state.farmhouseLevel, needed: 1, saveFor: price((item) => item.kind === 'farmhouse') },
  { id: 'foreman', text: 'Hire a Foreman and the farm runs itself. I may finally sit down.', reward: 100_000, target: 'farm', progress: owns('foreman'), needed: 1, saveFor: price((item) => item.kind === 'automation' && item.id === 'foreman') },
  { id: 'windmill', text: 'That windmill has stood still for forty years. Same as me. Get its sails turning.', reward: 250_000, target: 'farm', progress: (state) => (state.windmill ? 1 : 0), needed: 1, saveFor: price((item) => item.kind === 'windmill') },
]

/** Rebirth stays hidden until Arne introduces it. */
export const REBIRTH_INTRO = GOALS.findIndex((goal) => goal.id === 'open_rebirth')

/** Arne's remarks, for when something good happens. */
export const QUIPS = [
  'Arne: Not bad. I was better.',
  'Arne: Back in my day that was 3 coins and a goat.',
  'Arne: The carrots are talking about you.',
  'Arne: Beautiful. I may cry. It may be hay fever.',
  'Arne: You are officially less bad.',
  'Arne: My knees felt that.',
]

if (GOALS.length !== GOAL_COUNT) throw new Error(`GOAL_COUNT should be ${GOALS.length}`)

/** Trophies run on for ever: each is 1,000× further than the last. */
function trophy(index: number): Goal {
  const needed = 1e9 * Math.pow(1_000, index)
  return {
    id: `trophy:${index}`,
    text: `Next trophy: earn ${formatNumber(needed)} coins in total. Each one adds 20% to every crop, for good.`,
    reward: 0,
    target: null,
    progress: (state) => state.lifetimeCoins,
    needed,
    trophy: true,
  }
}

export function currentGoal(state: GameState): Goal {
  return GOALS[state.goalIndex] ?? trophy(state.goalIndex - GOALS.length)
}

/** Finishes every goal that's been met, pays it, and returns them. */
export function checkGoals(state: GameState): Goal[] {
  const finished: Goal[] = []
  for (;;) {
    const goal = currentGoal(state)
    if (goal.progress(state) < goal.needed) return finished
    state.money += goal.reward
    state.goalIndex += 1
    finished.push(goal)
  }
}
