import { describe, expect, it } from 'vitest'
import { availableUpgrades, buy, buyMax, trainingCost, type Upgrade } from './estate'
import { TRAINING } from './content'
import { checkGoals, currentGoal, GOALS } from './goals'
import { parseSave } from './save'
import { newGame, storageCapacity, type GameState } from './state'

function upgrade(state: GameState, kind: Upgrade['kind']): Upgrade {
  return availableUpgrades(state).find((item) => item.kind === kind)!
}

describe('the Farm menu', () => {
  it('gates on level, then on money', () => {
    const state = newGame()
    const parcel = upgrade(state, 'parcel')
    state.money = 1_000_000
    expect(buy(state, parcel)).toBe('locked')
    state.level = 10
    state.money = 1
    expect(buy(state, parcel)).toBe('noMoney')
  })

  it('buys land, and it leaves the list', () => {
    const state = newGame()
    state.level = 10
    state.money = 1_000_000
    const parcel = upgrade(state, 'parcel')
    expect(buy(state, parcel)).toBeNull()
    expect(state.ownedParcels).toContain('east_meadow')
    expect(availableUpgrades(state).some((item) => item.kind === 'parcel' && item.id === 'east_meadow')).toBe(false)
  })

  it('works through every storage level, then stops', () => {
    const state = newGame()
    state.level = 10
    state.money = 1_000_000
    const sizes = [storageCapacity(state)]
    for (let i = 0; i < 3; i++) {
      buy(state, upgrade(state, 'storage'))
      sizes.push(storageCapacity(state))
    }
    expect(sizes).toEqual([300, 450, 650, 900])
    expect(upgrade(state, 'storage')).toBeUndefined()
  })

  it('renovates the farmhouse three times', () => {
    const state = newGame()
    state.level = 10
    state.money = 1_000_000
    for (let i = 0; i < 3; i++) buy(state, upgrade(state, 'farmhouse'))
    expect(state.farmhouseLevel).toBe(3)
    expect(upgrade(state, 'farmhouse')).toBeUndefined()
  })

  it('hires three farmhands at most', () => {
    const state = newGame()
    state.level = 10
    state.money = 1_000_000
    for (let i = 0; i < 3; i++) buy(state, upgrade(state, 'worker'))
    expect(state.workers).toHaveLength(3)
    expect(upgrade(state, 'worker')).toBeUndefined()
  })
})

describe('endless upgrades', () => {
  const seeds = TRAINING.find((item) => item.id === 'seeds')!

  it('cost more each level, with no last level', () => {
    expect(trainingCost(seeds, 1)).toBeGreaterThan(trainingCost(seeds, 0))
    expect(Number.isFinite(trainingCost(seeds, 500))).toBe(true)
  })

  it('stay on the list after buying', () => {
    const state = newGame()
    state.level = 10
    state.money = 1_000_000
    buy(state, upgrade(state, 'training'))
    expect(state.training.seeds).toBe(1)
    expect(upgrade(state, 'training')).toBeDefined()
  })

  it('buy as many levels as the coins allow', () => {
    const state = newGame()
    state.level = 10
    state.money = trainingCost(seeds, 0) + trainingCost(seeds, 1) + trainingCost(seeds, 2) + 1
    expect(buyMax(state, 'seeds')).toBe(3)
    expect(state.money).toBe(1)
  })
})

describe('goals', () => {
  it('turn into trophies, for ever', () => {
    const state = newGame()
    state.goalIndex = GOALS.length
    expect(currentGoal(state).trophy).toBe(true)
    state.lifetimeCoins = 1e15
    expect(checkGoals(state)).toHaveLength(3)
    expect(currentGoal(state).needed).toBe(1e18)
  })

  it('finish in order and pay out', () => {
    const state = newGame()
    state.counters.harvestedPlots = 6
    state.counters.sales = 1
    state.counters.planted = 6
    state.counters.watered = 6
    const money = state.money
    expect(checkGoals(state).map((goal) => goal.id)).toEqual(['first_harvest', 'first_sale', 'replant', 'water'])
    expect(state.money).toBe(money + 20)
    expect(currentGoal(state)?.id).toBe('plow')
  })

})

describe('saves', () => {
  it('survive a round trip', () => {
    const state = newGame(123)
    state.money = 4_321
    expect(parseSave(JSON.stringify(state))).toEqual(state)
  })

  it('refuse anything that is not a farm', () => {
    expect(parseSave(null)).toBeNull()
    expect(parseSave('{broken')).toBeNull()
    expect(parseSave('{"version":99}')).toBeNull()
  })
})
