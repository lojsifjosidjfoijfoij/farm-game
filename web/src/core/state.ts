import { BALANCE, cropDef, DAY, PARCELS, type ParcelDef } from './content'

export interface PlantedCrop {
  cropId: string
  /** Sim seconds of growth so far. */
  growth: number
  harvests: number
  /** Set if it ripened rare. */
  mutation?: string
}

export interface Plot {
  x: number
  y: number
  crop: PlantedCrop | null
  /** World time the soil stays wet until. */
  wetUntil: number
}

export interface Sprinkler {
  x: number
  y: number
  kind: string
}

export interface Worker {
  x: number
  y: number
  /** Whole tasks banked; a task runs when this reaches 1. */
  progress: number
}

export interface MarketState {
  /** The game day `sold` was last brought up to date (-1: never). */
  day: number
  /** Recent sales per item, in coins at the usual price, fading each day. */
  sold: Record<string, number>
}

export interface GameState {
  version: 1
  /** Sim seconds since the farm began. */
  worldTime: number
  money: number
  /** Farmer level. Levels and experience are never reset. */
  level: number
  /** Experience earned within the current level. */
  xp: number
  /** The crop being planted. */
  seed: string
  inventory: Record<string, number>
  plots: Record<string, Plot>
  ownedParcels: string[]
  storageLevel: number
  sprinklers: Sprinkler[]
  workers: Worker[]
  farmhouseLevel: number
  windmill: boolean
  market: MarketState
  rng: number
  counters: Record<string, number>
  /** Index of Arne's current goal. */
  goalIndex: number

  /** Levels of the endless upgrades this run. */
  training: Record<string, number>
  /** Automation owned this run. */
  automation: string[]
  /** Coins earned since the last rebirth. */
  runCoins: number
  lifetimeCoins: number
  /** Coins per real second, averaged over the last couple of minutes. */
  income: number
  /** Sim seconds since the Market Driver's last trip, and the Foreman's last round. */
  driverClock: number
  foremanClock: number

  /** Rebirths in this ascension, and in this universe. */
  rebirths: number
  totalRebirths: number
  goldenSeeds: number
  perks: Record<string, number>
  ascensions: number
  stars: number
  universes: number
  /** Wall clock (ms) at the last save, for catching up after an absence. */
  lastSavedAt: number
}

export function tileKey(x: number, y: number): string {
  return `${x},${y}`
}

export function plotAt(state: GameState, x: number, y: number): Plot | undefined {
  return state.plots[tileKey(x, y)]
}

export function isReady(plantedCrop: PlantedCrop): boolean {
  const def = cropDef(plantedCrop.cropId)
  return def !== undefined && plantedCrop.growth >= def.growthSeconds
}

export function isWet(plot: Plot, time: number): boolean {
  return plot.wetUntil > time
}

export function parcelAt(x: number, y: number): ParcelDef | undefined {
  return PARCELS.find((p) => x >= p.minX && x <= p.maxX && y >= p.minY && y <= p.maxY)
}

export function today(state: GameState): number {
  return Math.floor(state.worldTime / DAY)
}

export function storageUsed(state: GameState): number {
  return Object.values(state.inventory).reduce((sum, count) => sum + count, 0)
}

export function storageCapacity(state: GameState): number {
  const base = BALANCE.storageLevels[state.storageLevel] ?? BALANCE.storageLevels[0]
  return Math.round(base * Math.pow(1.25, trainingLevel(state, 'barn')))
}

export function trainingLevel(state: GameState, id: string): number {
  return state.training[id] ?? 0
}

export function perkLevel(state: GameState, id: string): number {
  return state.perks[id] ?? 0
}

export function hasAutomation(state: GameState, id: string): boolean {
  return state.automation.includes(id)
}

/** The one way coins come in, so every coin earned counts toward rebirth. */
export function earn(state: GameState, amount: number): void {
  state.money = Math.min(BALANCE.maxCoins, state.money + amount)
  state.runCoins = Math.min(BALANCE.maxCoins, state.runCoins + amount)
  state.lifetimeCoins = Math.min(BALANCE.maxCoins, state.lifetimeCoins + amount)
}

export function addCounter(state: GameState, name: string, amount = 1): void {
  if (amount > 0) state.counters[name] = (state.counters[name] ?? 0) + amount
}

export function count(state: GameState, name: string): number {
  return state.counters[name] ?? 0
}

/** Six plots of ripe wheat are waiting, so the first click pays. */
export function newGame(now = 0, seed = 0x5eed): GameState {
  const state: GameState = {
    version: 1,
    worldTime: 0,
    money: BALANCE.startingMoney,
    level: 1,
    xp: 0,
    inventory: {},
    plots: {},
    ownedParcels: ['home_field'],
    storageLevel: 0,
    sprinklers: [],
    workers: [],
    farmhouseLevel: 0,
    windmill: false,
    market: { day: -1, sold: {} },
    rng: seed,
    counters: {},
    goalIndex: 0,
    lastSavedAt: now,
    seed: 'wheat',
    training: {},
    automation: [],
    runCoins: 0,
    lifetimeCoins: 0,
    income: 0,
    driverClock: 0,
    foremanClock: 0,
    rebirths: 0,
    totalRebirths: 0,
    goldenSeeds: 0,
    perks: {},
    ascensions: 0,
    stars: 0,
    universes: 0,
  }
  const wheat = cropDef('wheat')!
  for (let y = 6; y <= 7; y++) {
    for (let x = 9; x <= 11; x++) {
      state.plots[tileKey(x, y)] = {
        x, y, wetUntil: 0,
        crop: { cropId: wheat.id, growth: wheat.growthSeconds, harvests: 0 },
      }
    }
  }
  return state
}

/** Next value in 0…1 from the state's own generator (mulberry32), so a save replays the same. */
export function nextUnit(state: GameState): number {
  const value = (state.rng + 0x6d2b79f5) | 0
  state.rng = value
  let t = Math.imul(value ^ (value >>> 15), 1 | value)
  t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296
}

/** A hash that stays the same between runs, for prices that drift by item and day. */
export function stableHash(text: string, seed = 0x811c9dc5): number {
  let hash = seed >>> 0
  for (let i = 0; i < text.length; i++) {
    hash = Math.imul(hash ^ text.charCodeAt(i), 0x01000193) >>> 0
  }
  return hash
}
