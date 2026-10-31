import { describe, expect, it } from 'vitest'
import { BALANCE, DAY } from './content'
import { placeMachine } from './estate'
import { perform } from './farming'
import { REAL_SECONDS_PER_DAY, TIME_SCALE } from './pace'
import { rollMutation } from './progress'
import { catchUp, step } from './simulation'
import { newGame, plotAt, tileKey, type GameState } from './state'

function planted(cropId = 'corn'): GameState {
  const state = newGame()
  state.level = 10
  state.money = 100_000
  state.plots = { [tileKey(9, 6)]: { x: 9, y: 6, crop: { cropId, growth: 0, harvests: 0 }, wetUntil: 0 } }
  return state
}

describe('crop growth', () => {
  it('runs at half speed in dry soil', () => {
    const state = planted()
    step(state, DAY)
    expect(plotAt(state, 9, 6)!.crop!.growth).toBe(DAY / 2)
  })

  it('runs at full speed while the soil is wet, then slows', () => {
    const state = planted()
    perform(state, { kind: 'water' }, 9, 6)
    step(state, 2 * DAY)
    expect(plotAt(state, 9, 6)!.crop!.growth).toBe(DAY + DAY / 2)
  })

  it('gives the same result for any step size', () => {
    const big = planted()
    perform(big, { kind: 'water' }, 9, 6)
    step(big, 3 * DAY)
    const small = planted()
    perform(small, { kind: 'water' }, 9, 6)
    for (let i = 0; i < 72; i++) step(small, 60)
    expect(plotAt(small, 9, 6)!.crop!.growth).toBeCloseTo(plotAt(big, 9, 6)!.crop!.growth, 6)
  })

  it('reports a crop once when it ripens', () => {
    const state = planted('wheat')
    expect(step(state, 2 * DAY)).toEqual([{ kind: 'cropReady', x: 9, y: 6, cropId: 'wheat' }])
    expect(step(state, DAY)).toEqual([])
  })
})

describe('sprinklers', () => {
  it('keep the eight tiles around them wet, even across a long catch-up', () => {
    const state = planted()
    state.plots[tileKey(11, 6)] = { x: 11, y: 6, crop: { cropId: 'corn', growth: 0, harvests: 0 }, wetUntil: 0 }
    expect(placeMachine(state, 'sprinkler', 10, 7)).toBeNull()
    step(state, 3 * DAY, 'offline')
    expect(plotAt(state, 9, 6)!.crop!.growth).toBe(3 * DAY)
    expect(plotAt(state, 11, 6)!.crop!.growth).toBe(3 * DAY)
  })

  it('cannot go on a crop or off your land', () => {
    const state = planted()
    expect(placeMachine(state, 'sprinkler', 9, 6)).toBe('occupied')
    expect(placeMachine(state, 'sprinkler', 15, 6)).toBe('notYourLand')
  })

  it('replace empty soil they are set on', () => {
    const state = planted()
    perform(state, { kind: 'plow' }, 10, 6)
    expect(placeMachine(state, 'sprinkler', 10, 6)).toBeNull()
    expect(plotAt(state, 10, 6)).toBeUndefined()
  })
})

describe('farmhands', () => {
  function withHand(): GameState {
    const state = planted('wheat')
    state.workers = [{ x: 8, y: 5, progress: 0 }]
    return state
  }

  it('water thirsty crops, then harvest ripe ones', () => {
    const state = withHand()
    step(state, DAY / 20)
    expect(plotAt(state, 9, 6)!.wetUntil).toBeGreaterThan(state.worldTime)
    plotAt(state, 9, 6)!.crop!.growth = DAY
    step(state, DAY / 20)
    expect(state.inventory.wheat).toBeGreaterThan(0)
  })

  it('harvest before they water', () => {
    const state = withHand()
    state.plots[tileKey(10, 6)] = { x: 10, y: 6, crop: { cropId: 'wheat', growth: DAY, harvests: 0 }, wetUntil: 0 }
    step(state, DAY / 20)
    expect(plotAt(state, 10, 6)!.crop).toBeNull()
    expect(plotAt(state, 9, 6)!.wetUntil).toBe(0)
  })

  it('do not bank idle time', () => {
    const state = withHand()
    state.plots = {}
    step(state, 5 * DAY)
    expect(state.workers[0].progress).toBeLessThanOrEqual(1)
  })

  it('rest while the game is closed', () => {
    const state = withHand()
    plotAt(state, 9, 6)!.crop!.growth = DAY
    step(state, 5 * DAY, 'offline')
    expect(plotAt(state, 9, 6)!.crop).not.toBeNull()
  })
})

describe('catchUp', () => {
  it('grows crops for the time away and counts what ripened', () => {
    const state = planted('wheat')
    state.lastSavedAt = 0
    const summary = catchUp(state, 2 * REAL_SECONDS_PER_DAY * 1000)
    expect(summary).toEqual({ awaySeconds: 2 * REAL_SECONDS_PER_DAY, ripened: 1, earned: 0 })
  })

  it('pays half the usual income while away, if the truck is running', () => {
    const state = planted('wheat')
    state.lastSavedAt = 0
    state.income = 100
    state.automation = ['driver']
    expect(catchUp(state, 1_000 * 1000).earned).toBe(50_000)
  })

  it('stops paying after the hours the farmer has earned', () => {
    const state = planted('wheat')
    state.lastSavedAt = 0
    state.income = 100
    state.automation = ['driver']
    expect(catchUp(state, 24 * 3600 * 1000).earned).toBe(100 * 4 * 3600 * 0.5)
  })

  it('pays nothing without a driver', () => {
    const state = planted('wheat')
    state.lastSavedAt = 0
    state.income = 100
    expect(catchUp(state, 1_000 * 1000).earned).toBe(0)
  })

  it('ignores a clock that went backwards', () => {
    const state = planted('wheat')
    state.lastSavedAt = 10_000
    expect(catchUp(state, 0).awaySeconds).toBe(0)
    expect(plotAt(state, 9, 6)!.crop!.growth).toBe(0)
  })
})

describe('automation', () => {
  it('lets a driver sell on its own every ten seconds', () => {
    const state = planted('wheat')
    state.automation = ['driver']
    state.inventory.wheat = 10
    expect(step(state, 9 * TIME_SCALE).some((event) => event.kind === 'autoSold')).toBe(false)
    expect(step(state, 2 * TIME_SCALE).some((event) => event.kind === 'autoSold')).toBe(true)
    expect(state.inventory.wheat).toBeUndefined()
  })

  it('keeps every plot wet with irrigation', () => {
    const state = planted('corn')
    state.automation = ['irrigation']
    step(state, 3 * DAY, 'offline')
    expect(plotAt(state, 9, 6)!.crop!.growth).toBe(3 * DAY)
  })

  it('has farmhands sow bare soil with the selected seed once there is a drill', () => {
    const state = planted('wheat')
    state.plots = { [tileKey(9, 6)]: { x: 9, y: 6, crop: null, wetUntil: 0 } }
    state.workers = [{ x: 8, y: 5, progress: 0 }]
    state.automation = ['drill']
    state.seed = 'carrot'
    step(state, DAY / 20)
    expect(plotAt(state, 9, 6)!.crop?.cropId).toBe('carrot')
  })

  it('has farmhands plow new land for a foreman, and only for a foreman', () => {
    const state = planted('wheat')
    state.plots = {}
    state.money = 0
    state.workers = [{ x: 8, y: 5, progress: 0 }]
    step(state, DAY / 20)
    expect(Object.keys(state.plots)).toHaveLength(0)
    state.automation = ['foreman']
    step(state, DAY / 20)
    expect(Object.keys(state.plots).length).toBeGreaterThan(0)
  })

  it('has a foreman buy what the coins allow', () => {
    const state = planted('wheat')
    state.automation = ['foreman']
    state.money = 1_000
    step(state, BALANCE.foremanInterval + 1)
    expect(state.training.seeds).toBeGreaterThan(0)
  })

  it('tracks income over time', () => {
    const state = planted('wheat')
    state.automation = ['driver']
    state.inventory.wheat = 100
    step(state, 11 * TIME_SCALE)
    expect(state.income).toBeGreaterThan(0)
  })
})

describe('rare crops', () => {
  it('turn up at about the listed rate', () => {
    const state = planted('wheat')
    let golden = 0
    for (let i = 0; i < 40_000; i++) {
      if (rollMutation(state)?.id === 'golden') golden += 1
    }
    expect(golden).toBeGreaterThan(800)
    expect(golden).toBeLessThan(1_200)
  })

  it('come up more often with luck', () => {
    const state = planted('wheat')
    state.perks.lucky = 5
    let rare = 0
    for (let i = 0; i < 10_000; i++) {
      if (rollMutation(state)) rare += 1
    }
    expect(rare).toBeGreaterThan(600)
  })

  it('pay their multiple on top of the normal crop', () => {
    const state = planted('wheat')
    plotAt(state, 9, 6)!.crop = { cropId: 'wheat', growth: DAY, harvests: 0, mutation: 'golden' }
    const money = state.money
    const outcome = perform(state, { kind: 'harvest' }, 9, 6)
    expect(outcome).toMatchObject({ ok: true, mutation: 'golden' })
    expect(state.money).toBeGreaterThan(money)
    expect(state.runCoins).toBe(state.money - money)
    expect(state.inventory.wheat).toBeGreaterThanOrEqual(3)
  })
})
