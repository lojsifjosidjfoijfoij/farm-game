import { describe, expect, it } from 'vitest'
import { BALANCE, cropDef, exoticCrop, PERKS } from './content'
import { perform } from './farming'
import { currentGoal, GOALS } from './goals'
import { basePrice } from './market'
import { cropsFor, masteryLevel, nextCrop, valueMultiplier } from './progress'
import {
  ascend, bigBang, buyPerk, canAscend, canBigBang, canRebirth, goldenSeedsFor, perkCost, rebirth, rebirthRequirement,
} from './rebirth'
import { newGame, tileKey, type GameState } from './state'

function perk(id: string) {
  return PERKS.find((item) => item.id === id)!
}

function readyToRebirth(): GameState {
  const state = newGame()
  state.goalIndex = GOALS.length
  state.level = 20
  state.runCoins = rebirthRequirement(state)
  state.money = 1_000_000
  return state
}

describe('rebirth', () => {
  it('is out of reach until the run has earned enough', () => {
    const state = newGame()
    expect(canRebirth(state)).toBe(false)
    expect(rebirth(state)).toBe(0)
    state.runCoins = rebirthRequirement(state)
    expect(canRebirth(state)).toBe(true)
  })

  it('asks for far more each time', () => {
    const state = newGame()
    const first = rebirthRequirement(state)
    state.rebirths = 1
    expect(rebirthRequirement(state)).toBeGreaterThan(first * BALANCE.rebirthGrowth)
  })

  it('wipes the farm and pays Golden Seeds', () => {
    const state = readyToRebirth()
    state.training.seeds = 12
    state.ownedParcels.push('east_meadow')
    state.workers.push({ x: 1, y: 1, progress: 0 })
    state.farmhouseLevel = 2
    state.windmill = true
    state.inventory.wheat = 50
    expect(rebirth(state)).toBeGreaterThan(0)
    expect(state.rebirths).toBe(1)
    expect(state.money).toBe(BALANCE.rebirthStartMoney)
    expect(state.runCoins).toBe(0)
    expect(state.training).toEqual({})
    expect(state.ownedParcels).toEqual(['home_field'])
    expect(state.workers).toEqual([])
    expect(state.farmhouseLevel).toBe(0)
    expect(state.windmill).toBe(false)
    expect(state.inventory).toEqual({})
    expect(state.plots).toEqual({})
  })

  it('forgets the old farm\'s income', () => {
    const state = readyToRebirth()
    state.income = 5e9
    rebirth(state)
    expect(state.income).toBe(0)
  })

  it('keeps levels, mastery and lifetime coins', () => {
    const state = readyToRebirth()
    state.lifetimeCoins = 5e9
    state.counters['harvested:wheat'] = 5_000
    rebirth(state)
    expect(state.level).toBe(20)
    expect(state.lifetimeCoins).toBe(5e9)
    expect(masteryLevel(state, 'wheat')).toBe(6)
  })

  it('makes every crop worth more', () => {
    const state = readyToRebirth()
    const before = valueMultiplier(state)
    rebirth(state)
    expect(valueMultiplier(state)).toBeCloseTo(before * BALANCE.rebirthValue, 6)
  })

  it('pays more for going past the requirement', () => {
    const state = readyToRebirth()
    const atTheLine = goldenSeedsFor(state)
    state.runCoins *= 100
    expect(goldenSeedsFor(state)).toBe(atTheLine * 10)
  })
})

describe('Golden Seed perks', () => {
  it('spend seeds, and cost more each level', () => {
    const state = newGame()
    state.goldenSeeds = 100
    const thumb = perk('green_thumb')
    expect(buyPerk(state, thumb)).toBeNull()
    expect(state.goldenSeeds).toBe(100 - perkCost(thumb, 0))
    expect(perkCost(thumb, 5)).toBeGreaterThan(perkCost(thumb, 0))
  })

  it('refuse when short of seeds or at the last level', () => {
    const state = newGame()
    expect(buyPerk(state, perk('green_thumb'))).toBe('noSeeds')
    state.goldenSeeds = 1_000
    buyPerk(state, perk('old_habits'))
    expect(buyPerk(state, perk('old_habits'))).toBe('maxed')
  })

  it('start each new farm further along', () => {
    const state = readyToRebirth()
    state.perks = { old_habits: 1, deep_wells: 1, old_foreman: 1, loyal_hands: 2, family_land: 3, head_start: 2 }
    rebirth(state)
    expect(state.automation.sort()).toEqual(['drill', 'driver', 'foreman', 'irrigation'])
    expect(state.workers).toHaveLength(2)
    expect(state.ownedParcels).toEqual(['home_field', 'east_meadow', 'west_field', 'mill_lot'])
    expect(state.money).toBe(8_000)
  })
})

describe('ascend', () => {
  it('needs a full set of rebirths in this ascension', () => {
    const state = newGame()
    state.rebirths = BALANCE.rebirthsToAscend - 1
    expect(canAscend(state)).toBe(false)
    state.rebirths = BALANCE.rebirthsToAscend
    expect(canAscend(state)).toBe(true)
  })

  it('trades rebirths and seeds for stars worth far more', () => {
    const state = newGame()
    state.rebirths = BALANCE.rebirthsToAscend
    state.goldenSeeds = 500
    const before = valueMultiplier(state)
    expect(ascend(state)).toBe(BALANCE.rebirthsToAscend)
    expect(state.rebirths).toBe(0)
    expect(state.goldenSeeds).toBe(0)
    expect(valueMultiplier(state)).toBeGreaterThan(before * 10)
  })

  it('keeps perks that have a last level and clears the endless ones', () => {
    const state = newGame()
    state.rebirths = BALANCE.rebirthsToAscend
    state.perks = { old_habits: 1, green_thumb: 9 }
    ascend(state)
    expect(state.perks).toEqual({ old_habits: 1 })
  })

  it('raises the price of the next rebirths', () => {
    const state = newGame()
    const first = rebirthRequirement(state)
    state.rebirths = BALANCE.rebirthsToAscend
    ascend(state)
    expect(rebirthRequirement(state)).toBe(first * BALANCE.ascensionGrowth)
  })
})

describe('big bang', () => {
  it('needs a googol coins on one farm', () => {
    const state = newGame()
    state.runCoins = 1e99
    expect(canBigBang(state)).toBe(false)
    state.runCoins = 1e100
    expect(canBigBang(state)).toBe(true)
  })

  it('wipes every layer below it and starts a stronger universe', () => {
    const state = newGame()
    state.runCoins = 1e100
    state.rebirths = 9
    state.totalRebirths = 150
    state.ascensions = 8
    state.stars = 120
    state.perks = { old_habits: 1 }
    const before = Math.pow(BALANCE.universeValue, 1)
    expect(bigBang(state)).toBe(true)
    expect(state).toMatchObject({ rebirths: 0, totalRebirths: 0, ascensions: 0, stars: 0, perks: {}, universes: 1 })
    expect(valueMultiplier(state)).toBe(before)
  })
})

describe('a new universe', () => {
  it('goes back to a seed that can be planted', () => {
    const state = newGame()
    state.runCoins = 1e100
    state.seed = 'x4'
    bigBang(state)
    expect(state.seed).toBe('wheat')
  })
})

describe('exotic crops', () => {
  it('have a next one, however far you go', () => {
    const state = newGame()
    state.level = 50
    state.totalRebirths = 600
    expect(nextCrop(state).unlockRebirths).toBeGreaterThan(600)
  })

  it('open up with rebirths, and each is worth more than the last', () => {
    const state = newGame()
    state.level = 50
    const plain = cropsFor(state).length
    state.totalRebirths = BALANCE.rebirthsPerExoticCrop * 2
    expect(cropsFor(state).length).toBe(plain + 2)
    expect(exoticCrop(1).sellPrice[0]).toBeGreaterThan(exoticCrop(0).sellPrice[1])
  })

  it('are found by id, so old saves still load them', () => {
    expect(cropDef('x4')?.name).toBe(exoticCrop(4).name)
    expect(cropDef('x4x')).toBeUndefined()
  })

  it('stay locked until enough rebirths', () => {
    const state = newGame()
    state.money = 1e12
    state.plots[tileKey(9, 8)] = { x: 9, y: 8, crop: null, wetUntil: 0 }
    expect(perform(state, { kind: 'plant', cropId: 'x0' }, 9, 8)).toEqual({ ok: false, failure: 'locked' })
  })
})

describe('the numbers', () => {
  it('keep rising with no ceiling in sight', () => {
    const state = newGame()
    state.totalRebirths = 300
    state.rebirths = 9
    state.stars = 200
    state.level = 500
    state.goalIndex = GOALS.length + 30
    expect(Number.isFinite(basePrice(state, 'pumpkin'))).toBe(true)
    expect(currentGoal(state).needed).toBeGreaterThan(1e90)
  })
})
