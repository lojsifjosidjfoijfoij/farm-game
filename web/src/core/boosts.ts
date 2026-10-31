import { BALANCE } from './content'
import { TIME_SCALE } from './pace'
import { fastForward } from './simulation'
import { addCounter, type GameState } from './state'

/**
 * Short boosts from the Market. Each can be had with coins, or by watching an
 * ad in the Full Launch build. They're occasional extras: the cooldown is the
 * same either way, and nothing in the game needs one.
 */
export type BoostKind = 'coins' | 'skip'

/** Real seconds until a boost can be taken again. */
export function boostReadyIn(state: GameState, kind: BoostKind): number {
  return Math.max(0, ((state.boostReady[kind] ?? 0) - state.worldTime) / TIME_SCALE)
}

/** Real seconds left on the coin boost. */
export function coinBoostLeft(state: GameState): number {
  return Math.max(0, (state.boostUntil - state.worldTime) / TIME_SCALE)
}

/** Priced in the farm's own income, so it's a real choice at any size. */
export function boostCost(state: GameState, kind: BoostKind): number {
  const seconds = kind === 'coins' ? BALANCE.coinBoostCostSeconds : BALANCE.skipCostSeconds
  return Math.max(kind === 'coins' ? 500 : 250, Math.round(state.income * seconds))
}

/** Gives a boost, paid for or watched. Returns the coins a skip earned. */
export function applyBoost(state: GameState, kind: BoostKind): number {
  state.boostReady[kind] = state.worldTime + BALANCE.boostCooldownSeconds * TIME_SCALE
  addCounter(state, `boost:${kind}`)
  if (kind === 'coins') {
    state.boostUntil = state.worldTime + BALANCE.coinBoostSeconds * TIME_SCALE
    return 0
  }
  return fastForward(state, BALANCE.skipSeconds, BALANCE.skipSeconds, 1).earned
}

export type BoostFailure = 'cooling' | 'noMoney'

export function buyBoost(state: GameState, kind: BoostKind): BoostFailure | null {
  if (boostReadyIn(state, kind) > 0) return 'cooling'
  const cost = boostCost(state, kind)
  if (state.money < cost) return 'noMoney'
  state.money -= cost
  applyBoost(state, kind)
  return null
}
