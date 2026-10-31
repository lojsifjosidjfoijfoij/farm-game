import { describe, expect, it } from 'vitest'
import { BALANCE } from './content'
import { claimDailyGift } from './daily'
import { removeMachine, placeMachine, buyMax } from './estate'
import { newGame } from './state'

const DAY_MS = 24 * 60 * 60 * 1000

describe('the daily gift', () => {
  it('pays once a day', () => {
    const state = newGame()
    expect(claimDailyGift(state, 100 * DAY_MS)).toEqual({ coins: BALANCE.giftMinimum, streak: 1 })
    expect(claimDailyGift(state, 100 * DAY_MS + 1000)).toBeNull()
  })

  it('grows with a streak, and a missed day starts it over', () => {
    const state = newGame()
    claimDailyGift(state, 100 * DAY_MS)
    expect(claimDailyGift(state, 101 * DAY_MS)?.streak).toBe(2)
    expect(claimDailyGift(state, 103 * DAY_MS)?.streak).toBe(1)
  })
})

describe('sprinklers', () => {
  it('can be picked back up for a full refund', () => {
    const state = newGame()
    state.level = 10
    state.money = 5_000
    state.plots = {}
    placeMachine(state, 'sprinkler', 9, 6)
    expect(removeMachine(state, 9, 6)).toBe(true)
    expect(state.money).toBe(5_000)
    expect(state.sprinklers).toEqual([])
    expect(removeMachine(state, 9, 6)).toBe(false)
  })
})

describe('buying the most', () => {
  it('stops paying for fertilizer at top speed', () => {
    const state = newGame()
    state.level = 10
    state.money = 1e30
    buyMax(state, 'fertilizer')
    expect(state.training.fertilizer).toBe(70)
  })
})
