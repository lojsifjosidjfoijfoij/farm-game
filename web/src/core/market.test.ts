import { describe, expect, it } from 'vitest'
import { BALANCE, DAY } from './content'
import { basePrice, marketFactor, marketSpecial, quote, sell, sellAll, sellAllQuote } from './market'
import { newGame } from './state'

describe('prices', () => {
  it('stay inside the usual range, and special days pay half as much again', () => {
    for (let day = 0; day < 40; day++) {
      const state = newGame()
      state.worldTime = day * DAY
      const price = basePrice(state, 'carrot')
      expect(price).toBeGreaterThanOrEqual(Math.round(18 * BALANCE.priceScale))
      expect(price).toBeLessThanOrEqual(Math.round(36 * BALANCE.priceScale))
    }
  })

  it('only name something you can grow as the special', () => {
    for (let day = 0; day < 40; day++) {
      const state = newGame()
      state.worldTime = day * DAY
      expect(['wheat', 'carrot', 'potato']).toContain(marketSpecial(state))
    }
  })

  it('gain 5% per farmhouse tier', () => {
    const state = newGame()
    state.worldTime = 0
    const before = basePrice(state, 'pumpkin')
    state.farmhouseLevel = 2
    expect(Math.abs(basePrice(state, 'pumpkin') - before * 1.1)).toBeLessThanOrEqual(1.5)
  })
})

describe('supply and demand', () => {
  it('lowers the price of what you just sold and nothing else', () => {
    const state = newGame()
    state.inventory.pumpkin = 20
    sell(state, 'pumpkin')
    expect(marketFactor(state, 'pumpkin')).toBeLessThan(1)
    expect(marketFactor(state, 'carrot')).toBe(1)
  })

  it('never falls below the floor', () => {
    const state = newGame()
    state.inventory.pumpkin = 900
    sell(state, 'pumpkin')
    expect(marketFactor(state, 'pumpkin')).toBe(0.3)
  })

  it('recovers three quarters of the drop each day', () => {
    const state = newGame()
    state.inventory.pumpkin = 20
    sell(state, 'pumpkin')
    const sold = 1 / marketFactor(state, 'pumpkin') - 1
    state.worldTime += DAY
    expect(1 / marketFactor(state, 'pumpkin') - 1).toBeCloseTo(sold * 0.25, 6)
  })

  it('charges each item a little less than the last', () => {
    const state = newGame()
    expect(quote(state, 'pumpkin', 40)).toBeLessThan(quote(state, 'pumpkin', 1) * 40)
  })

  it('stays quick and fair on an enormous load', () => {
    const state = newGame()
    const small = quote(state, 'pumpkin', 100)
    const huge = quote(state, 'pumpkin', 1_000_000)
    expect(huge).toBeGreaterThan(small)
    expect(Number.isFinite(huge)).toBe(true)
  })

  it('treats an exotic crop like its plain cousin', () => {
    const state = newGame()
    state.totalRebirths = 3
    state.inventory.x0 = 40
    sell(state, 'x0')
    expect(marketFactor(state, 'x0')).toBeGreaterThan(0.9)
  })

  it('goes deeper once the windmill turns', () => {
    const state = newGame()
    state.inventory.pumpkin = 20
    sell(state, 'pumpkin')
    const before = marketFactor(state, 'pumpkin')
    state.windmill = true
    expect(marketFactor(state, 'pumpkin')).toBeGreaterThan(before)
  })
})

describe('selling', () => {
  it('turns the whole store into exactly the quoted coins', () => {
    const state = newGame()
    state.inventory = { wheat: 20, carrot: 8 }
    const quoted = sellAllQuote(state)
    const money = state.money
    expect(sellAll(state)).toBe(quoted)
    expect(state.money).toBe(money + quoted)
    expect(state.inventory).toEqual({})
    expect(state.counters.sales).toBe(1)
  })

  it('does not count an empty trip as a sale', () => {
    const state = newGame()
    expect(sellAll(state)).toBe(0)
    expect(state.counters.sales).toBeUndefined()
  })
})
