import { BALANCE, CROPS, cropDef, mutationDef, xpToNextLevel } from './content'
import { basePrice, bestCrop } from './market'
import {
  addCounter, earn, hasAutomation, isReady, isWet, nextUnit, parcelAt, plotAt, storageCapacity, storageUsed, tileKey,
  type GameState, type Plot,
} from './state'

export type FarmActionKind = 'plow' | 'plant' | 'water' | 'harvest'
export type FarmAction = { kind: 'plow' | 'water' | 'harvest' } | { kind: 'plant'; cropId: string }

/** Why an action could not happen. The HUD turns these into friendly messages. */
export type FarmFailure =
  | 'notYourLand' | 'cannotPlowHere' | 'alreadyPlowed' | 'notPlowed' | 'alreadyPlanted' | 'unknownCrop'
  | 'locked' | 'noMoney' | 'nothingToWater' | 'alreadyWet' | 'notReady' | 'storageFull'

export type FarmOutcome =
  | { ok: true; kind: 'plow' | 'water' }
  | { ok: true; kind: 'plant'; cropId: string }
  | { ok: true; kind: 'harvest'; cropId: string; amount: number; xp: number; levelsGained: number; mutation?: string; bonus: number }
  | { ok: false; failure: FarmFailure }

function fail(failure: FarmFailure): FarmOutcome {
  return { ok: false, failure }
}

/** Adds experience, levelling up as often as needed. Returns the levels gained. */
export function addXP(state: GameState, amount: number): number {
  let gained = 0
  state.xp += amount
  while (state.xp >= xpToNextLevel(state.level)) {
    state.xp -= xpToNextLevel(state.level)
    state.level += 1
    gained += 1
  }
  return gained
}

function accessProblem(state: GameState, x: number, y: number): FarmFailure | null {
  const parcel = parcelAt(x, y)
  return parcel && state.ownedParcels.includes(parcel.id) ? null : 'notYourLand'
}

function plowProblem(state: GameState, x: number, y: number): FarmFailure | null {
  const access = accessProblem(state, x, y)
  if (access) return access
  if (plotAt(state, x, y)) return 'alreadyPlowed'
  if (state.sprinklers.some((s) => s.x === x && s.y === y)) return 'cannotPlowHere'
  return null
}

/**
 * The single most sensible action for a click on this tile, or null if there
 * is nothing to do (a crop growing in wet soil). `seed` is the crop to plant
 * on empty soil.
 */
export function suggestedAction(state: GameState, x: number, y: number, seed: string | null): FarmAction | null {
  if (accessProblem(state, x, y)) return null
  const plot = plotAt(state, x, y)
  if (!plot) return plowProblem(state, x, y) ? null : { kind: 'plow' }
  if (!plot.crop) return seed ? { kind: 'plant', cropId: seed } : null
  if (isReady(plot.crop)) return { kind: 'harvest' }
  if (!isWet(plot, state.worldTime)) return { kind: 'water' }
  return null
}

/**
 * What one job does on this tile, or why it can't. A drag repeats the job it
 * started with, and a job only ever does its own work: harvesting across a
 * field never plants.
 */
export function toolAction(
  state: GameState, kind: FarmActionKind, x: number, y: number, seed: string | null,
): FarmAction | FarmFailure {
  const access = accessProblem(state, x, y)
  if (access) return access
  const plot = plotAt(state, x, y)
  switch (kind) {
    case 'plow':
      return plowProblem(state, x, y) ?? { kind: 'plow' }
    case 'plant':
      if (!plot) return 'notPlowed'
      if (plot.crop) return 'alreadyPlanted'
      if (!seed || !cropDef(seed)) return 'unknownCrop'
      return { kind: 'plant', cropId: seed }
    case 'water':
      if (!plot) return 'notPlowed'
      if (!plot.crop || isReady(plot.crop)) return 'nothingToWater'
      if (isWet(plot, state.worldTime)) return 'alreadyWet'
      return { kind: 'water' }
    case 'harvest':
      if (!plot?.crop || !isReady(plot.crop)) return 'notReady'
      return { kind: 'harvest' }
  }
}

/** Nothing growing, nothing to sell, not even coins for seeds. Arne lends a handful. */
function needsSeedsOnTheHouse(state: GameState, seedCost: number): boolean {
  const cheapest = Math.min(...CROPS.map((crop) => crop.seedCost))
  return seedCost === cheapest && state.money < cheapest
    && Object.values(state.inventory).every((items) => items === 0)
    && Object.values(state.plots).every((plot) => plot.crop === null)
}

/** Harvested by hand, what's selected. A farmhand keeps the field as it was, unless the Foreman knows better. */
function replantChoice(state: GameState, harvested: string, byWorker: boolean): string {
  if (!byWorker) return state.seed
  return hasAutomation(state, 'foreman') ? bestCrop(state) : harvested
}

function canGrow(state: GameState, cropId: string): boolean {
  const def = cropDef(cropId)
  return def !== undefined && def.unlockLevel <= state.level && def.unlockRebirths <= state.totalRebirths
}

/** With the Seed Drill, a harvested plot goes straight back in, if there are coins for the seed. */
function replant(state: GameState, plot: Plot, cropId: string): void {
  const def = cropDef(cropId)
  if (!def || !canGrow(state, cropId) || state.money < def.seedCost) return
  state.money -= def.seedCost
  plot.crop = { cropId, growth: 0, harvests: 0 }
  addCounter(state, 'planted')
  addCounter(state, `planted:${cropId}`)
}

/**
 * Does a field job. A farmhand (`byWorker`) earns the farmer half the
 * experience: with none, hiring help would quietly stop the farmer levelling.
 */
export function perform(state: GameState, action: FarmAction, x: number, y: number, byWorker = false): FarmOutcome {
  const access = accessProblem(state, x, y)
  if (access) return fail(access)
  switch (action.kind) {
    case 'plow': {
      const problem = plowProblem(state, x, y)
      if (problem) return fail(problem)
      state.plots[tileKey(x, y)] = { x, y, crop: null, wetUntil: 0 }
      addCounter(state, 'plowed')
      return { ok: true, kind: 'plow' }
    }
    case 'plant': {
      const plot = plotAt(state, x, y)
      if (!plot) return fail('notPlowed')
      if (plot.crop) return fail('alreadyPlanted')
      const def = cropDef(action.cropId)
      if (!def) return fail('unknownCrop')
      if (!canGrow(state, def.id)) return fail('locked')
      if (state.money >= def.seedCost) state.money -= def.seedCost
      else if (!needsSeedsOnTheHouse(state, def.seedCost)) return fail('noMoney')
      plot.crop = { cropId: def.id, growth: 0, harvests: 0 }
      addCounter(state, 'planted')
      addCounter(state, `planted:${def.id}`)
      return { ok: true, kind: 'plant', cropId: def.id }
    }
    case 'water': {
      const plot = plotAt(state, x, y)
      if (!plot) return fail('notPlowed')
      if (!plot.crop || isReady(plot.crop)) return fail('nothingToWater')
      if (isWet(plot, state.worldTime)) return fail('alreadyWet')
      plot.wetUntil = state.worldTime + BALANCE.soilWetDuration
      addCounter(state, 'watered')
      return { ok: true, kind: 'water' }
    }
    case 'harvest': {
      const plot = plotAt(state, x, y)
      if (!plot?.crop || !isReady(plot.crop)) return fail('notReady')
      const def = cropDef(plot.crop.cropId)
      if (!def) return fail('notReady')
      // Roll the yield on a saved seed: a harvest refused for lack of space
      // must not change the outcome of the next attempt.
      const seed = state.rng
      const [low, high] = def.yield
      const amount = low + Math.floor(nextUnit(state) * (high - low + 1))
      if (storageUsed(state) + amount > storageCapacity(state)) {
        state.rng = seed
        return fail('storageFull')
      }
      state.inventory[def.id] = (state.inventory[def.id] ?? 0) + amount
      const mutation = plot.crop.mutation
      const rare = mutationDef(mutation)
      const bonus = rare ? amount * basePrice(state, def.id) * (rare.multiplier - 1) : 0
      if (bonus > 0) {
        earn(state, bonus)
        addCounter(state, `mutation:${rare!.id}`)
      }
      if (def.regrowSeconds !== undefined) {
        plot.crop.growth = Math.max(0, def.growthSeconds - def.regrowSeconds)
        plot.crop.harvests += 1
        plot.crop.mutation = undefined
      } else {
        plot.crop = null
        if (hasAutomation(state, 'drill')) replant(state, plot, replantChoice(state, def.id, byWorker))
      }
      addCounter(state, 'harvested', amount)
      addCounter(state, 'harvestedPlots')
      addCounter(state, `harvested:${def.id}`, amount)
      const xp = byWorker ? Math.ceil(def.xp / 2) : def.xp
      const levelsGained = xp > 0 ? addXP(state, xp) : 0
      return { ok: true, kind: 'harvest', cropId: def.id, amount, xp, levelsGained, mutation, bonus }
    }
  }
}
