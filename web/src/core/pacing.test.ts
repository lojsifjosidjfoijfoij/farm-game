import { describe, expect, it } from 'vitest'
import { CROPS, PARCELS, PERKS, type CropDef } from './content'
import { availableUpgrades, buy, buyMax, placeMachine } from './estate'
import { perform, suggestedAction } from './farming'
import { checkGoals, currentGoal, GOALS } from './goals'
import { sellAll } from './market'
import { formatNumber } from './numbers'
import { REAL_SECONDS_PER_DAY, TIME_SCALE } from './pace'
import { cropsFor, valueMultiplier } from './progress'
import { ascend, buyPerk, canAscend, canRebirth, perkCost, rebirth, rebirthRequirement } from './rebirth'
import { step } from './simulation'
import { hasAutomation, newGame, parcelAt, perkLevel, storageCapacity, storageUsed, type GameState } from './state'

/** Best crop for a player who comes back every `visit` seconds: most coins per plot per visit. */
function bestSeed(state: GameState, visit: number): CropDef {
  const day = 1440
  const open = cropsFor(state).filter((crop) => crop.seedCost <= state.money)
  const score = (crop: CropDef): number => {
    const items = (crop.yield[0] + crop.yield[1]) / 2
    const price = (crop.sellPrice[0] + crop.sellPrice[1]) / 2
    const seconds = Math.max(visit, (crop.growthSeconds / day) * REAL_SECONDS_PER_DAY)
    return (items * price - crop.seedCost) / seconds
  }
  return open.sort((a, b) => score(b) - score(a))[0] ?? CROPS[0]
}

function spendSeeds(state: GameState): void {
  for (;;) {
    const open = PERKS.filter((perk) => perk.maxLevel === null || perkLevel(state, perk.id) < perk.maxLevel)
    const cheapest = open.sort((a, b) => perkCost(a, perkLevel(state, a.id)) - perkCost(b, perkLevel(state, b.id)))[0]
    if (buyPerk(state, cheapest)) return
  }
}

/** A plain but attentive player: every few seconds, work the field, sell, buy what's affordable, rebirth when offered. */
function play(hours: number, visit = 5): { milestones: Map<string, number>; state: GameState } {
  const state = newGame()
  const milestones = new Map<string, number>()
  const note = (name: string, t: number): void => {
    if (!milestones.has(name)) milestones.set(name, t)
  }
  const seconds = hours * 3600
  for (let t = 0; t < seconds; t += visit) {
    const asked = { carrots: 'carrot', corn: 'corn', pumpkin: 'pumpkin' }[currentGoal(state).id]
    const askedCrop = CROPS.find((crop) => crop.id === asked)
    state.seed = askedCrop && askedCrop.unlockLevel <= state.level ? askedCrop.id : bestSeed(state, visit).id
    if (!hasAutomation(state, 'foreman') || state.workers.length === 0) {
      for (const parcel of PARCELS.filter((p) => state.ownedParcels.includes(p.id))) {
        for (let y = parcel.minY; y <= parcel.maxY; y++) {
          for (let x = parcel.minX; x <= parcel.maxX; x++) {
            const action = suggestedAction(state, x, y, state.seed)
            if (action) perform(state, action, x, y)
          }
        }
      }
    }
    if (storageUsed(state) > storageCapacity(state) * 0.2 || t % 20 === 0) sellAll(state)
    for (const upgrade of availableUpgrades(state)) {
      if (upgrade.kind === 'machine') {
        if (state.level >= upgrade.level && state.money >= upgrade.cost * 3 && state.sprinklers.length < state.ownedParcels.length) {
          const parcel = PARCELS.find((p) => state.ownedParcels.includes(p.id) && !state.sprinklers.some((s) => parcelAt(s.x, s.y)?.id === p.id))
          if (parcel) {
            const x = parcel.minX + 2
            const y = parcel.minY + 1
            delete state.plots[`${x},${y}`]
            placeMachine(state, upgrade.id, x, y)
          }
        }
      } else if (upgrade.kind === 'training') {
        buyMax(state, upgrade.id)
      } else if (buy(state, upgrade) === null) {
        note(upgrade.name, t)
      }
    }
    note(`level ${state.level}`, t)
    for (const goal of checkGoals(state)) note(goal.trophy ? `trophy ${formatNumber(goal.needed)}` : `goal ${goal.id}`, t)
    if (canAscend(state)) {
      ascend(state)
      note(`ascension ${state.ascensions}`, t)
      spendSeeds(state)
    }
    if (canRebirth(state)) {
      const target = rebirthRequirement(state)
      rebirth(state)
      const total = state.totalRebirths
      note(`rebirth ${total} at ${formatNumber(target)}, value ×${formatNumber(valueMultiplier(state))}`, t)
      spendSeeds(state)
    }
    step(state, visit * TIME_SCALE)
  }
  return { milestones, state }
}

describe('pacing', () => {
  // Set VITE_PACING_HOURS for a longer look. A simulated day takes a few minutes.
  const hours = Number(import.meta.env.VITE_PACING_HOURS ?? 2)
  const { milestones, state } = play(hours, 5)
  const firstRebirth = [...milestones].find(([name]) => name.startsWith('rebirth 1 '))?.[1] ?? Infinity
  const at = (name: string): number => milestones.get(name) ?? Infinity

  it('prints the timeline', () => {
    const rows = [...milestones].filter(([name]) => !name.startsWith('goal ') && !name.startsWith('level '))
      .sort((a, b) => a[1] - b[1]).map(([name, t]) => `${(t / 3600).toFixed(2).padStart(7)} h  ${name}`)
    console.log(`${rows.join('\n')}\nafter ${hours} h: ${formatNumber(state.money)} coins, level ${state.level}, ${state.totalRebirths} rebirths, ${state.ascensions} ascensions, goal ${state.goalIndex}/${GOALS.length}`)
  })

  it('reaches the first rebirth after a decent first run', () => {
    expect(firstRebirth).toBeGreaterThan(15 * 60)
    expect(firstRebirth).toBeLessThan(60 * 60)
  })

  it('reaches billions in the first session', () => {
    expect(at('trophy 1.00B')).toBeLessThan(2 * 3600)
  })

  it('is nowhere near the end after all that', () => {
    expect(state.runCoins).toBeLessThan(1e60)
    expect(Number.isFinite(state.money)).toBe(true)
  })
})
