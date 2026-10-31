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
  { id: 'first_harvest', text: 'Morning! That wheat is ripe. Click it to harvest, or drag across the rows.', reward: 0, target: 'ripe', progress: counter('harvestedPlots'), needed: 6 },
  { id: 'first_sale', text: 'Nice haul. It went into your storage, see the crate up top? Hit Sell to turn it into coins.', reward: 0, target: 'sell', progress: counter('sales'), needed: 1 },
  { id: 'replant', text: 'Coins in hand. Click the bare soil to plant wheat. Each seed costs a few coins.', reward: 0, target: 'soil', progress: counter('planted'), needed: 6 },
  { id: 'water', text: 'Now click them again to water. Wet soil grows twice as fast, and dark soil means it is wet.', reward: 20, target: 'dry', progress: counter('watered'), needed: 6 },
  { id: 'plow', text: 'While that grows, click the grass in your field to plow it. You can only plant on plowed soil.', reward: 30, target: 'ground', progress: counter('plowed'), needed: 9 },

  // A tour of the menus, each one as it becomes useful.
  { id: 'open_seeds', text: 'Click the Planting button, bottom left. That is your seed list: everything you can grow.', reward: 0, target: 'seeds', progress: counter('opened:seeds'), needed: 1 },
  { id: 'carrots', text: 'Carrots pay better than wheat. Pick them in your seed list, then plant six.', reward: 40, target: 'seeds', progress: counter('planted:carrot'), needed: 6 },
  { id: 'open_market', text: 'Open the Market. Prices move through the day, and one crop is always the special.', reward: 0, target: 'market', progress: counter('opened:market'), needed: 1 },
  { id: 'level2', text: 'The star up top is your level. Every harvest fills its bar. Reach level 2 for new seeds.', reward: 60, target: 'ripe', progress: (state) => state.level, needed: 2 },
  { id: 'open_farm', text: 'Open Farm. Everything you can buy is there, and each price shows how close you are.', reward: 0, target: 'farm', progress: counter('opened:farm'), needed: 1 },
  { id: 'seeds', text: 'Save up and buy Better Seeds in Farm. Every crop sells for more, and it never stops improving.', reward: 100, target: 'farm', progress: (state) => trainingLevel(state, 'seeds'), needed: 1, saveFor: price((item) => item.kind === 'training' && item.id === 'seeds') },

  // Growing the farm.
  { id: 'land', text: 'Your field is full. Save up for East Meadow in Farm: fifteen more plots.', reward: 200, target: 'farm', progress: counter('landBought'), needed: 1, saveFor: price((item) => item.kind === 'parcel') },
  { id: 'level3', text: 'Keep farming to reach level 3. New seeds, and sprinklers too.', reward: 300, target: 'ripe', progress: (state) => state.level, needed: 3 },
  { id: 'sprinkler', text: 'Tired of watering? Buy a sprinkler in Farm and click a spot in your field.', reward: 300, target: 'farm', progress: counter('sprinklersPlaced'), needed: 1, saveFor: price((item) => item.kind === 'machine' && item.id === 'sprinkler') },
  { id: 'storage', text: 'Storage fills fast. Save up for the storage shed in Farm.', reward: 500, target: 'farm', progress: counter('storageUpgrades'), needed: 1, saveFor: price((item) => item.kind === 'storage') },
  { id: 'worker', text: 'At level 4 you can hire a farmhand. They harvest and water for you.', reward: 1_000, target: 'farm', progress: counter('workersHired'), needed: 1, saveFor: price((item) => item.kind === 'worker') },

  // Letting the farm run itself.
  { id: 'drill', text: 'Buy the Seed Drill, and harvested plots replant themselves.', reward: 2_000, target: 'farm', progress: owns('drill'), needed: 1, saveFor: price((item) => item.kind === 'automation' && item.id === 'drill') },
  { id: 'driver', text: 'Buy the Market Driver. Your truck sells while you farm.', reward: 3_000, target: 'farm', progress: owns('driver'), needed: 1, saveFor: price((item) => item.kind === 'automation' && item.id === 'driver') },
  { id: 'watch_rare', text: 'Watch for glowing crops. Harvest a Golden one and it pays five times over.', reward: 3_000, target: null, progress: counter('mutation:golden'), needed: 1 },
  { id: 'corn', text: 'Grow something bigger. Harvest 20 corn.', reward: 5_000, target: 'seeds', progress: counter('harvested:corn'), needed: 20 },
  { id: 'land3', text: 'Own four fields.', reward: 10_000, target: 'farm', progress: counter('landBought'), needed: 3, saveFor: price((item) => item.kind === 'parcel') },
  { id: 'seeds10', text: 'Get Better Seeds to level 10.', reward: 15_000, target: 'farm', progress: (state) => trainingLevel(state, 'seeds'), needed: 10 },
  { id: 'pumpkin', text: 'Pumpkins take patience. Harvest 10.', reward: 20_000, target: 'seeds', progress: counter('harvested:pumpkin'), needed: 10 },
  { id: 'all_land', text: 'Buy every field in the valley.', reward: 30_000, target: 'farm', progress: counter('landBought'), needed: 5, saveFor: price((item) => item.kind === 'parcel') },
  { id: 'million', text: 'Earn a million coins on one farm.', reward: 50_000, target: 'market', progress: (state) => state.runCoins, needed: 1_000_000 },
  { id: 'irrigation', text: 'Dig the Irrigation and every plot stays wet.', reward: 50_000, target: 'farm', progress: owns('irrigation'), needed: 1, saveFor: price((item) => item.kind === 'automation' && item.id === 'irrigation') },
  { id: 'farmhouse', text: 'The old house has seen better days. Patch it up.', reward: 50_000, target: 'farm', progress: (state) => state.farmhouseLevel, needed: 1, saveFor: price((item) => item.kind === 'farmhouse') },
  { id: 'foreman', text: 'Hire a Foreman and the farm starts running itself.', reward: 100_000, target: 'farm', progress: owns('foreman'), needed: 1, saveFor: price((item) => item.kind === 'automation' && item.id === 'foreman') },
  { id: 'windmill', text: 'That windmill has stood still for forty years. Get its sails turning.', reward: 250_000, target: 'farm', progress: (state) => (state.windmill ? 1 : 0), needed: 1, saveFor: price((item) => item.kind === 'windmill') },
  { id: 'open_rebirth', text: 'Open Rebirth. Start a new farm with every crop worth more, for good.', reward: 0, target: 'rebirth', progress: counter('opened:rebirth'), needed: 1 },
  { id: 'first_rebirth', text: `Earn ${formatNumber(BALANCE.rebirthBase)} on this farm, then Rebirth.`, reward: 0, target: 'rebirth', progress: (state) => count(state, 'rebirths'), needed: 1 },
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
