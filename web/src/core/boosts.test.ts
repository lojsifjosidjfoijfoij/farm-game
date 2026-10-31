import { describe, expect, it } from 'vitest'
import { applyBoost, boostCost, boostReadyIn, buyBoost, coinBoostLeft } from './boosts'
import { BALANCE, DAY } from './content'
import { REAL_SECONDS_PER_DAY, TIME_SCALE } from './pace'
import { basePrice, quote } from './market'
import { valueMultiplier } from './progress'
import { step } from './simulation'
import { newGame, plotAt, tileKey } from './state'

describe('the coin boost', () => {
  it('multiplies every price while it runs, then stops', () => {
    const state = newGame()
    const before = valueMultiplier(state)
    const price = basePrice(state, 'carrot')
    applyBoost(state, 'coins')
    expect(valueMultiplier(state)).toBe(before * BALANCE.coinBoostMultiplier)
    expect(Math.abs(quote(state, 'carrot', 1) - price * BALANCE.coinBoostMultiplier)).toBeLessThanOrEqual(BALANCE.coinBoostMultiplier)
    expect(coinBoostLeft(state)).toBe(BALANCE.coinBoostSeconds)
    step(state, (BALANCE.coinBoostSeconds + 1) * TIME_SCALE)
    expect(valueMultiplier(state)).toBe(before)
  })
})

describe('skip time', () => {
  it('grows crops the full jump', () => {
    const state = newGame()
    state.plots = { [tileKey(9, 6)]: { x: 9, y: 6, wetUntil: 0, crop: { cropId: 'pumpkin', growth: 0, harvests: 0 } } }
    applyBoost(state, 'skip')
    const days = BALANCE.skipSeconds / REAL_SECONDS_PER_DAY
    expect(plotAt(state, 9, 6)!.crop!.growth).toBe(Math.min(6 * DAY, days * DAY * BALANCE.dryGrowthRate))
  })

  it('pays the income for that time if the truck is running', () => {
    const state = newGame()
    state.income = 100
    state.automation = ['driver']
    expect(applyBoost(state, 'skip')).toBe(100 * BALANCE.skipSeconds)
  })
})

describe('buying a boost', () => {
  it('costs more for a richer farm', () => {
    const state = newGame()
    const small = boostCost(state, 'coins')
    state.income = 1e9
    expect(boostCost(state, 'coins')).toBeGreaterThan(small)
  })

  it('refuses without the coins, and spends nothing', () => {
    const state = newGame()
    state.money = 10
    expect(buyBoost(state, 'coins')).toBe('noMoney')
    expect(state.money).toBe(10)
  })

  it('makes both ways of getting it wait the same cooldown', () => {
    const state = newGame()
    state.money = 10_000
    expect(buyBoost(state, 'coins')).toBeNull()
    expect(boostReadyIn(state, 'coins')).toBe(BALANCE.boostCooldownSeconds)
    expect(buyBoost(state, 'coins')).toBe('cooling')
    expect(buyBoost(state, 'skip')).toBeNull()
    step(state, (BALANCE.boostCooldownSeconds + 1) * TIME_SCALE)
    expect(boostReadyIn(state, 'coins')).toBe(0)
  })
})
