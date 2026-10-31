import { describe, expect, it } from 'vitest'
import { cropDef, DAY } from './content'
import { addXP, perform, suggestedAction, toolAction } from './farming'
import { newGame, plotAt, tileKey, type GameState } from './state'

function farmWith(money = 1_000): GameState {
  const state = newGame()
  state.plots = {}
  state.money = money
  return state
}

describe('suggestedAction', () => {
  it('walks a tile through plow, plant, water and harvest', () => {
    const state = farmWith()
    expect(suggestedAction(state, 9, 6, 'wheat')).toEqual({ kind: 'plow' })
    perform(state, { kind: 'plow' }, 9, 6)
    expect(suggestedAction(state, 9, 6, 'wheat')).toEqual({ kind: 'plant', cropId: 'wheat' })
    perform(state, { kind: 'plant', cropId: 'wheat' }, 9, 6)
    expect(suggestedAction(state, 9, 6, 'wheat')).toEqual({ kind: 'water' })
    perform(state, { kind: 'water' }, 9, 6)
    expect(suggestedAction(state, 9, 6, 'wheat')).toBeNull()
    plotAt(state, 9, 6)!.crop!.growth = DAY
    expect(suggestedAction(state, 9, 6, 'wheat')).toEqual({ kind: 'harvest' })
  })

  it('offers nothing on land you do not own', () => {
    expect(suggestedAction(farmWith(), 15, 6, 'wheat')).toBeNull()
  })
})

describe('toolAction', () => {
  it('only ever does its own job', () => {
    const state = farmWith()
    perform(state, { kind: 'plow' }, 9, 6)
    expect(toolAction(state, 'harvest', 9, 6, 'wheat')).toBe('notReady')
    expect(toolAction(state, 'plow', 9, 6, 'wheat')).toBe('alreadyPlowed')
    expect(toolAction(state, 'water', 9, 6, 'wheat')).toBe('nothingToWater')
  })
})

describe('planting', () => {
  it('pays for the seed', () => {
    const state = farmWith(100)
    perform(state, { kind: 'plow' }, 9, 6)
    perform(state, { kind: 'plant', cropId: 'carrot' }, 9, 6)
    expect(state.money).toBe(92)
  })

  it('refuses seeds above your level or your purse', () => {
    const state = farmWith(5)
    perform(state, { kind: 'plow' }, 9, 6)
    expect(perform(state, { kind: 'plant', cropId: 'melon' }, 9, 6)).toEqual({ ok: false, failure: 'locked' })
    expect(perform(state, { kind: 'plant', cropId: 'carrot' }, 9, 6)).toEqual({ ok: false, failure: 'noMoney' })
  })

  it('never leaves a broke farmer stuck', () => {
    const state = farmWith(0)
    perform(state, { kind: 'plow' }, 9, 6)
    expect(perform(state, { kind: 'plant', cropId: 'wheat' }, 9, 6).ok).toBe(true)
    perform(state, { kind: 'plow' }, 10, 6)
    // Something is growing now, so the handout is over.
    expect(perform(state, { kind: 'plant', cropId: 'wheat' }, 10, 6)).toEqual({ ok: false, failure: 'noMoney' })
  })
})

describe('harvest', () => {
  function ripe(state: GameState, cropId: string): void {
    const def = cropDef(cropId)!
    state.plots[tileKey(9, 6)] = { x: 9, y: 6, wetUntil: 0, crop: { cropId, growth: def.growthSeconds, harvests: 0 } }
  }

  it('adds the yield and clears the plot but keeps the soil', () => {
    const state = farmWith()
    ripe(state, 'wheat')
    const outcome = perform(state, { kind: 'harvest' }, 9, 6)
    expect(outcome).toMatchObject({ ok: true, kind: 'harvest', cropId: 'wheat', xp: 2 })
    expect(state.inventory.wheat).toBeGreaterThanOrEqual(3)
    expect(state.inventory.wheat).toBeLessThanOrEqual(4)
    expect(plotAt(state, 9, 6)!.crop).toBeNull()
  })

  it('leaves regrowing crops in the ground, set back by the regrow time', () => {
    const state = farmWith()
    ripe(state, 'strawberry')
    state.level = 3
    perform(state, { kind: 'harvest' }, 9, 6)
    const crop = plotAt(state, 9, 6)!.crop!
    expect(crop.growth).toBe(1.5 * DAY)
    expect(crop.harvests).toBe(1)
  })

  it('refuses when storage is full, without spending the roll', () => {
    const state = farmWith()
    ripe(state, 'wheat')
    state.inventory.carrot = 300
    const rng = state.rng
    expect(perform(state, { kind: 'harvest' }, 9, 6)).toEqual({ ok: false, failure: 'storageFull' })
    expect(state.rng).toBe(rng)
  })

  it('earns half the experience when a farmhand does it', () => {
    const state = farmWith()
    ripe(state, 'corn')
    perform(state, { kind: 'harvest' }, 9, 6, true)
    expect(state.xp).toBe(5)
  })
})

describe('addXP', () => {
  it('climbs several levels at once and keeps the rest', () => {
    const state = farmWith()
    expect(addXP(state, 40 + 100 + 5)).toBe(2)
    expect(state.level).toBe(3)
    expect(state.xp).toBe(5)
  })
})
