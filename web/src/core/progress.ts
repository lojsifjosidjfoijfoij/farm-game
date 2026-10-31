import { BALANCE, CROPS, exoticCrop, MUTATIONS, type CropDef, type MutationDef } from './content'
import { GOAL_COUNT } from './goalCount'
import { nextUnit, perkLevel, trainingLevel, type GameState } from './state'

/** Every crop the farmer can plant right now, cheapest first. */
export function cropsFor(state: GameState): CropDef[] {
  const crops = CROPS.filter((crop) => crop.unlockLevel <= state.level)
  for (let index = 0; exoticCrop(index).unlockRebirths <= state.totalRebirths; index++) crops.push(exoticCrop(index))
  return crops
}

/** The next crop on the way, plain or exotic. */
export function nextCrop(state: GameState): CropDef {
  const plain = CROPS.find((crop) => crop.unlockLevel > state.level)
  if (plain) return plain
  let index = 0
  while (exoticCrop(index).unlockRebirths <= state.totalRebirths) index++
  return exoticCrop(index)
}

/** A crop's mastery: one level for each doubling of what's been harvested. Never resets. */
export function masteryLevel(state: GameState, cropId: string): number {
  const harvested = state.counters[`harvested:${cropId}`] ?? 0
  return Math.floor(Math.log2(1 + harvested / BALANCE.masteryFirstHarvest))
}

export function trophies(state: GameState): number {
  return Math.max(0, state.goalIndex - GOAL_COUNT)
}

/** Everything that multiplies every crop's price, shown in the HUD. */
export function valueMultiplier(state: GameState): number {
  return Math.pow(1.2, trainingLevel(state, 'seeds'))
    * (1 + state.farmhouseLevel * BALANCE.farmhouseBonus)
    * (1 + (state.level - 1) * BALANCE.levelValue)
    * Math.pow(1.25, perkLevel(state, 'green_thumb'))
    * Math.pow(BALANCE.rebirthValue, state.rebirths)
    * Math.pow(BALANCE.starValue, state.stars)
    * Math.pow(BALANCE.trophyValue, trophies(state))
    * Math.pow(BALANCE.universeValue, state.universes)
}

/** What multiplies one crop's price. */
export function cropValue(state: GameState, cropId: string): number {
  return valueMultiplier(state) * (1 + masteryLevel(state, cropId) * BALANCE.masteryValue)
}

/** How fast crops grow, relative to the base game. */
export function growthSpeed(state: GameState): number {
  const speed = (1 + trainingLevel(state, 'fertilizer') * 0.1) * Math.pow(1.2, perkLevel(state, 'swift'))
  return Math.min(BALANCE.maxGrowthSpeed, speed)
}

export function workerSpeed(state: GameState): number {
  return Math.pow(1.25, trainingLevel(state, 'training'))
}

export function luck(state: GameState): number {
  return (1 + trainingLevel(state, 'clover') * 0.1) * (1 + perkLevel(state, 'lucky') * 0.25)
}

/** Rolled as a crop ripens. Rarest first, so luck can't crowd out the top. */
export function rollMutation(state: GameState): MutationDef | undefined {
  const roll = nextUnit(state)
  const lucky = luck(state)
  let threshold = 0
  for (const mutation of MUTATIONS) {
    threshold += mutation.chance * lucky
    if (roll < threshold) return mutation
  }
  return undefined
}
