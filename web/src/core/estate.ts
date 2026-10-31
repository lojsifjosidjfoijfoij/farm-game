import { AUTOMATION, BALANCE, cropDef, machineDef, PARCELS, TRAINING, type TrainingDef } from './content'
import { perform, type FarmAction, type FarmOutcome } from './farming'
import { bestCrop } from './market'
import { growthSpeed } from './progress'
import {
  addCounter, hasAutomation, isReady, isWet, parcelAt, plotAt, storageCapacity, storageUsed, tileKey, trainingLevel,
  type GameState,
} from './state'

/** Everything on the Farm menu, each with what it costs and what it needs. */
export type Upgrade = { name: string; cost: number; level: number; blurb: string; rebirths: number } & (
  | { kind: 'parcel' | 'machine' | 'automation'; id: string }
  | { kind: 'storage' | 'worker' | 'farmhouse' | 'windmill' }
  | { kind: 'training'; id: string; owned: number }
)

/** Has the farmer reached this yet? The big purchases wait for rebirths, so a first farm stays a first farm. */
export function isUnlocked(state: GameState, upgrade: Upgrade): boolean {
  return state.level >= upgrade.level && state.totalRebirths >= upgrade.rebirths
}

const FARMHOUSE_NAMES = ['Patch up the farmhouse', 'Renovate the farmhouse', 'Finish the farmhouse']

export function trainingCost(def: TrainingDef, owned: number): number {
  return Math.ceil(def.baseCost * Math.pow(def.costGrowth, owned))
}

/** What can be bought next, cheapest first. Finished lines drop off the list. */
export function availableUpgrades(state: GameState): Upgrade[] {
  const upgrades: Upgrade[] = []
  for (const def of TRAINING) {
    if (def.id === 'training' && state.workers.length === 0) continue
    if (def.id === 'fertilizer' && growthSpeed(state) >= BALANCE.maxGrowthSpeed) continue
    const owned = trainingLevel(state, def.id)
    upgrades.push({
      kind: 'training', id: def.id, name: def.name, blurb: def.blurb, level: def.unlockLevel, rebirths: 0, owned,
      cost: trainingCost(def, owned),
    })
  }
  for (const item of AUTOMATION) {
    if (hasAutomation(state, item.id)) continue
    upgrades.push({ kind: 'automation', id: item.id, name: item.name, cost: item.cost, level: item.unlockLevel, rebirths: item.rebirths, blurb: item.blurb })
  }
  for (const parcel of PARCELS) {
    if (parcel.price === null || state.ownedParcels.includes(parcel.id)) continue
    upgrades.push({
      kind: 'parcel', id: parcel.id, name: parcel.name, cost: parcel.price, level: parcel.unlockLevel, rebirths: parcel.rebirths ?? 0,
      blurb: 'Fifteen more plots to farm.',
    })
  }
  const nextStorage = state.storageLevel + 1
  if (nextStorage < BALANCE.storageLevels.length) {
    upgrades.push({
      kind: 'storage', name: nextStorage === 1 ? 'Storage shed' : 'Grain silo',
      cost: BALANCE.storageUpgradeCosts[state.storageLevel], level: BALANCE.storageUpgradeLevels[state.storageLevel],
      rebirths: BALANCE.storageUpgradeRebirths[state.storageLevel],
      blurb: `Store ${BALANCE.storageLevels[nextStorage]} items.`,
    })
  }
  for (const id of hasAutomation(state, 'irrigation') ? [] : ['sprinkler', 'sprinkler_pro']) {
    const machine = machineDef(id)!
    upgrades.push({ kind: 'machine', id, name: machine.name, cost: machine.price, level: machine.unlockLevel, rebirths: 0, blurb: machine.blurb })
  }
  const hired = state.workers.length
  if (hired < BALANCE.workerHireCosts.length) {
    upgrades.push({
      kind: 'worker', name: hired === 0 ? 'Hire a farmhand' : 'Hire another farmhand',
      cost: BALANCE.workerHireCosts[hired], level: BALANCE.workerUnlockLevels[hired], rebirths: BALANCE.workerRebirths[hired],
      blurb: 'Harvests ripe crops and waters dry ones.',
    })
  }
  if (state.farmhouseLevel < BALANCE.farmhouseCosts.length) {
    upgrades.push({
      kind: 'farmhouse', name: FARMHOUSE_NAMES[state.farmhouseLevel],
      cost: BALANCE.farmhouseCosts[state.farmhouseLevel], level: BALANCE.farmhouseLevels[state.farmhouseLevel],
      rebirths: BALANCE.farmhouseRebirths[state.farmhouseLevel],
      blurb: `A proper farm fetches ${Math.round(BALANCE.farmhouseBonus * 100)}% more at market.`,
    })
  }
  if (!state.windmill) {
    upgrades.push({
      kind: 'windmill', name: 'Rebuild the old windmill', cost: BALANCE.windmillCost, level: BALANCE.windmillLevel, rebirths: BALANCE.windmillRebirths,
      blurb: 'Buyers come from all over: the market takes half as much again.',
    })
  }
  return upgrades.sort((a, b) => a.cost - b.cost)
}

export type BuyFailure = 'locked' | 'noMoney'

function pay(state: GameState, upgrade: Upgrade): BuyFailure | null {
  if (!isUnlocked(state, upgrade)) return 'locked'
  if (state.money < upgrade.cost) return 'noMoney'
  state.money -= upgrade.cost
  return null
}

/** Buys anything on the list except machines, which are bought as they're placed. */
export function buy(state: GameState, upgrade: Upgrade): BuyFailure | null {
  const problem = pay(state, upgrade)
  if (problem) return problem
  switch (upgrade.kind) {
    case 'parcel':
      state.ownedParcels.push(upgrade.id)
      addCounter(state, 'landBought')
      break
    case 'storage':
      state.storageLevel += 1
      addCounter(state, 'storageUpgrades')
      break
    case 'worker':
      state.workers.push({ x: 8, y: 5, progress: 0 })
      addCounter(state, 'workersHired')
      break
    case 'farmhouse':
      state.farmhouseLevel += 1
      break
    case 'windmill':
      state.windmill = true
      break
    case 'automation':
      state.automation.push(upgrade.id)
      break
    case 'training':
      state.training[upgrade.id] = upgrade.owned + 1
      break
    case 'machine':
      throw new Error('Machines are bought with placeMachine')
  }
  return null
}

/** Buys as many levels of an endless upgrade as the coins allow. Returns how many. */
export function buyMax(state: GameState, id: string): number {
  const def = TRAINING.find((item) => item.id === id)
  if (!def || state.level < def.unlockLevel) return 0
  let bought = 0
  for (;;) {
    // Past top speed, fertilizer does nothing, so Max must not keep paying for it.
    if (id === 'fertilizer' && growthSpeed(state) >= BALANCE.maxGrowthSpeed) return bought
    const owned = trainingLevel(state, id)
    const cost = trainingCost(def, owned)
    if (cost > state.money) return bought
    state.money -= cost
    state.training[id] = owned + 1
    bought += 1
  }
}

export type PlaceFailure = BuyFailure | 'notYourLand' | 'occupied'

/** Why a sprinkler can't stand here, or null. It may take bare ground or empty soil. */
export function placeProblem(state: GameState, x: number, y: number): PlaceFailure | null {
  const parcel = parcelAt(x, y)
  if (!parcel || !state.ownedParcels.includes(parcel.id)) return 'notYourLand'
  if (state.sprinklers.some((s) => s.x === x && s.y === y)) return 'occupied'
  if (plotAt(state, x, y)?.crop) return 'occupied'
  return null
}

export function placeMachine(state: GameState, kind: string, x: number, y: number): PlaceFailure | null {
  const machine = machineDef(kind)
  if (!machine) return 'occupied'
  const problem = placeProblem(state, x, y)
  if (problem) return problem
  if (state.level < machine.unlockLevel) return 'locked'
  if (state.money < machine.price) return 'noMoney'
  state.money -= machine.price
  delete state.plots[tileKey(x, y)]
  state.sprinklers.push({ x, y, kind })
  addCounter(state, 'sprinklersPlaced')
  return null
}

/** Takes a sprinkler back out, money back, so a misplaced one isn't a mistake for life. */
export function removeMachine(state: GameState, x: number, y: number): boolean {
  const index = state.sprinklers.findIndex((sprinkler) => sprinkler.x === x && sprinkler.y === y)
  if (index < 0) return false
  state.money += machineDef(state.sprinklers[index].kind)?.price ?? 0
  state.sprinklers.splice(index, 1)
  return true
}

export interface WorkerTask {
  worker: number
  x: number
  y: number
  action: FarmAction
  outcome: FarmOutcome
}

/** Bare ground a Foreman's farmhands can plow, nearest first. */
function nearestGround(state: GameState, fromX: number, fromY: number): { x: number; y: number; distance: number } | null {
  let best: { x: number; y: number; distance: number } | null = null
  for (const parcel of PARCELS) {
    if (!state.ownedParcels.includes(parcel.id)) continue
    for (let y = parcel.minY; y <= parcel.maxY; y++) {
      for (let x = parcel.minX; x <= parcel.maxX; x++) {
        if (plotAt(state, x, y) || state.sprinklers.some((s) => s.x === x && s.y === y)) continue
        const distance = Math.hypot(x - fromX, y - fromY)
        if (!best || distance < best.distance) best = { x, y, distance }
      }
    }
  }
  return best
}

/**
 * Harvest ripe crops first (while storage has room), then sow, then water,
 * then plow. Port of `Farmhands.fieldTask`, with the last jobs added.
 */
export function workerTask(state: GameState, index: number): WorkerTask | null {
  const worker = state.workers[index]
  const room = storageCapacity(state) - storageUsed(state)
  const drill = hasAutomation(state, 'drill')
  const sowingCrop = drill && hasAutomation(state, 'foreman') ? bestCrop(state) : state.seed
  const sowing = drill && state.money >= (cropDef(sowingCrop)?.seedCost ?? Infinity)
  let best: { x: number; y: number; action: FarmAction; rank: number; distance: number } | null = null
  for (const plot of Object.values(state.plots)) {
    let action: FarmAction
    let rank: number
    if (!plot.crop) {
      if (!sowing) continue
      action = { kind: 'plant', cropId: sowingCrop }
      rank = 1
    } else {
      const def = cropDef(plot.crop.cropId)
      if (!def) continue
      if (isReady(plot.crop)) {
        if (room < def.yield[1]) continue
        action = { kind: 'harvest' }
        rank = 0
      } else if (!isWet(plot, state.worldTime)) {
        action = { kind: 'water' }
        rank = 2
      } else {
        continue
      }
    }
    const distance = Math.hypot(plot.x - worker.x, plot.y - worker.y)
    if (!best || rank < best.rank || (rank === best.rank && distance < best.distance)) {
      best = { x: plot.x, y: plot.y, action, rank, distance }
    }
  }
  if (!best && hasAutomation(state, 'foreman')) {
    const ground = nearestGround(state, worker.x, worker.y)
    if (ground) best = { x: ground.x, y: ground.y, action: { kind: 'plow' }, rank: 3, distance: 0 }
  }
  if (!best) return null
  const outcome = perform(state, best.action, best.x, best.y, true)
  if (!outcome.ok) return null
  worker.x = best.x
  worker.y = best.y
  return { worker: index, x: best.x, y: best.y, action: best.action, outcome }
}
