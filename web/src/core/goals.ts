import { BALANCE } from './content'
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
}

function counter(name: string): (state: GameState) => number {
  return (state) => count(state, name)
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
  { id: 'first_harvest', text: 'Morning! That wheat is ripe. Click it to harvest, or drag across the rows.', reward: 0, target: 'ripe', progress: counter('harvestedPlots'), needed: 6 },
  { id: 'first_sale', text: 'Nice haul. Now hit Sell and take it to market.', reward: 0, target: 'sell', progress: counter('sales'), needed: 1 },
  { id: 'replant', text: 'Coins in hand. Click the bare soil to plant more wheat.', reward: 0, target: 'soil', progress: counter('planted'), needed: 6 },
  { id: 'water', text: 'Now water them. Wet soil grows twice as fast.', reward: 20, target: 'dry', progress: counter('watered'), needed: 6 },
  { id: 'plow', text: 'While that grows, click the grass in your field to plow the rest.', reward: 30, target: 'ground', progress: counter('plowed'), needed: 9 },
  { id: 'carrots', text: 'Carrots pay better. Pick them below and plant six.', reward: 60, target: 'seeds', progress: counter('planted:carrot'), needed: 6 },
  { id: 'level2', text: 'Keep harvesting by hand and you learn the land. Reach level 2.', reward: 100, target: 'ripe', progress: (state) => state.level, needed: 2 },
  { id: 'seeds', text: 'Open the Farm menu and buy Better Seeds. Those never stop getting better.', reward: 150, target: 'farm', progress: (state) => trainingLevel(state, 'seeds'), needed: 1 },
  { id: 'land', text: 'East Meadow is for sale. Buy it from the Farm menu.', reward: 250, target: 'farm', progress: counter('landBought'), needed: 1 },
  { id: 'level3', text: 'Reach level 3. New seeds, and sprinklers too.', reward: 300, target: 'ripe', progress: (state) => state.level, needed: 3 },
  { id: 'sprinkler', text: 'Tired of watering? Place a sprinkler from the Farm menu.', reward: 200, target: 'farm', progress: counter('sprinklersPlaced'), needed: 1 },
  { id: 'storage', text: 'Your barn is small. Buy the storage shed.', reward: 300, target: 'farm', progress: counter('storageUpgrades'), needed: 1 },
  { id: 'worker', text: 'At level 4 you can hire a farmhand. Do it. Your back will thank you.', reward: 800, target: 'farm', progress: counter('workersHired'), needed: 1 },
  { id: 'drill', text: 'Buy the Seed Drill, and harvested plots replant themselves.', reward: 2_500, target: 'farm', progress: owns('drill'), needed: 1 },
  { id: 'driver', text: 'Buy the Market Driver. Your truck sells while you farm.', reward: 5_000, target: 'farm', progress: owns('driver'), needed: 1 },
  { id: 'watch_rare', text: 'Watch for glowing crops. Harvest a Golden one and it pays five times over.', reward: 5_000, target: null, progress: counter('mutation:golden'), needed: 1 },
  { id: 'corn', text: 'Grow something bigger. Harvest 20 corn.', reward: 10_000, target: 'seeds', progress: counter('harvested:corn'), needed: 20 },
  { id: 'land3', text: 'Own four fields.', reward: 15_000, target: 'farm', progress: counter('landBought'), needed: 3 },
  { id: 'seeds10', text: 'Get Better Seeds to level 10.', reward: 20_000, target: 'farm', progress: (state) => trainingLevel(state, 'seeds'), needed: 10 },
  { id: 'pumpkin', text: 'Pumpkins take patience. Harvest 10.', reward: 30_000, target: 'seeds', progress: counter('harvested:pumpkin'), needed: 10 },
  { id: 'all_land', text: 'Buy every field in the valley.', reward: 50_000, target: 'farm', progress: counter('landBought'), needed: 5 },
  { id: 'million', text: 'Earn a million coins on one farm.', reward: 100_000, target: 'market', progress: (state) => state.runCoins, needed: 1_000_000 },
  { id: 'irrigation', text: 'Dig the Irrigation and every plot stays wet.', reward: 100_000, target: 'farm', progress: owns('irrigation'), needed: 1 },
  { id: 'farmhouse', text: 'The old house has seen better days. Patch it up.', reward: 100_000, target: 'farm', progress: (state) => state.farmhouseLevel, needed: 1 },
  { id: 'foreman', text: 'Hire a Foreman and the farm starts running itself.', reward: 200_000, target: 'farm', progress: owns('foreman'), needed: 1 },
  { id: 'windmill', text: 'That windmill has stood still for forty years. Get its sails turning.', reward: 500_000, target: 'farm', progress: (state) => (state.windmill ? 1 : 0), needed: 1 },
  { id: 'first_rebirth', text: `Earn ${formatNumber(BALANCE.rebirthBase)} on this farm, then open Rebirth and start again, stronger.`, reward: 0, target: 'rebirth', progress: (state) => count(state, 'rebirths'), needed: 1 },
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
