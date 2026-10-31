import { AUTOMATION, BALANCE, PERKS, PARCELS, type PerkDef } from './content'
import { addCounter, perkLevel, type GameState } from './state'

/**
 * Three ways to start over, each bigger than the last:
 *
 * - Rebirth: a new farm, with a permanent multiplier and Golden Seeds to spend.
 * - Ascend: gives up rebirths and Golden Seeds for stars, which are worth far more.
 * - Big bang: gives up everything but your levels and trophies for a new universe.
 *
 * Each rebirth asks for many times more coins than the last, so there is always a next one.
 */
export function rebirthRequirement(state: GameState): number {
  return BALANCE.rebirthBase
    * Math.pow(BALANCE.rebirthGrowth, state.rebirths)
    * Math.pow(BALANCE.ascensionGrowth, state.ascensions)
}

export function canRebirth(state: GameState): boolean {
  return state.runCoins >= rebirthRequirement(state)
}

/** Golden Seeds a rebirth pays now. More for going past the requirement, and for each rebirth so far. */
export function goldenSeedsFor(state: GameState): number {
  const past = Math.sqrt(state.runCoins / rebirthRequirement(state))
  return Math.floor(2 * (1 + state.rebirths) * Math.min(past, 1e6))
}

export function canAscend(state: GameState): boolean {
  return state.rebirths >= BALANCE.rebirthsToAscend
}

/** One star per rebirth given up, and a bonus for each past what's needed. */
export function starsFor(state: GameState): number {
  return state.rebirths + Math.max(0, state.rebirths - BALANCE.rebirthsToAscend)
}

export function canBigBang(state: GameState): boolean {
  return state.runCoins >= BALANCE.bigBangCoins
}

export function perkCost(perk: PerkDef, level: number): number {
  return Math.ceil(perk.baseCost * Math.pow(perk.costGrowth, level))
}

export type PerkFailure = 'maxed' | 'noSeeds'

export function buyPerk(state: GameState, perk: PerkDef): PerkFailure | null {
  const level = perkLevel(state, perk.id)
  if (perk.maxLevel !== null && level >= perk.maxLevel) return 'maxed'
  const cost = perkCost(perk, level)
  if (state.goldenSeeds < cost) return 'noSeeds'
  state.goldenSeeds -= cost
  state.perks[perk.id] = level + 1
  return null
}

/** The coins a new farm starts with. */
function startingCoins(state: GameState): number {
  const headStart = perkLevel(state, 'head_start')
  return headStart === 0 ? BALANCE.startingMoney : 1_000 * Math.pow(8, headStart - 1)
}

/** Clears the farm for a new run. Levels, mastery, counters and trophies stay. */
function startFarm(state: GameState): void {
  const fields = PARCELS.filter((parcel) => parcel.price !== null).sort((a, b) => a.price! - b.price!)
  state.money = startingCoins(state)
  state.runCoins = 0
  // Or a new farm would earn at the old farm's rate while the player is away.
  state.income = 0
  state.inventory = {}
  state.plots = {}
  state.ownedParcels = ['home_field', ...fields.slice(0, perkLevel(state, 'family_land')).map((parcel) => parcel.id)]
  state.storageLevel = 0
  state.sprinklers = []
  state.workers = Array.from({ length: perkLevel(state, 'loyal_hands') }, () => ({ x: 8, y: 5, progress: 0 }))
  state.farmhouseLevel = 0
  state.windmill = false
  state.training = {}
  state.market = { day: -1, sold: {} }
  state.driverClock = 0
  state.foremanClock = 0
  state.automation = AUTOMATION.map((item) => item.id).filter((id) => {
    if (id === 'drill' || id === 'driver') return perkLevel(state, 'old_habits') > 0
    if (id === 'irrigation') return perkLevel(state, 'deep_wells') > 0
    return perkLevel(state, 'old_foreman') > 0
  })
}

export function rebirth(state: GameState): number {
  if (!canRebirth(state)) return 0
  const seeds = goldenSeedsFor(state)
  state.goldenSeeds += seeds
  state.rebirths += 1
  state.totalRebirths += 1
  addCounter(state, 'rebirths')
  startFarm(state)
  return seeds
}

export function ascend(state: GameState): number {
  if (!canAscend(state)) return 0
  const stars = starsFor(state)
  state.stars += stars
  state.ascensions += 1
  state.rebirths = 0
  state.goldenSeeds = 0
  // Perks with a last level are keepsakes. The ones with no ceiling go back to zero.
  for (const perk of PERKS) {
    if (perk.maxLevel === null) delete state.perks[perk.id]
  }
  addCounter(state, 'ascensions')
  startFarm(state)
  return stars
}

export function bigBang(state: GameState): boolean {
  if (!canBigBang(state)) return false
  state.universes += 1
  // The exotic crop in hand is locked again in a new universe.
  state.seed = 'wheat'
  state.rebirths = 0
  state.totalRebirths = 0
  state.goldenSeeds = 0
  state.perks = {}
  state.ascensions = 0
  state.stars = 0
  addCounter(state, 'bigBangs')
  startFarm(state)
  return true
}
