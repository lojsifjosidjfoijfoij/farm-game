import { BALANCE, cropDef, DAY, machineDef } from './content'
import { availableUpgrades, buy, workerTask, type Upgrade, type WorkerTask } from './estate'
import { sellAll } from './market'
import { TIME_SCALE } from './pace'
import { growthSpeed, rollMutation, workerSpeed } from './progress'
import { earn, hasAutomation, isReady, perkLevel, plotAt, type GameState } from './state'

export type SimMode = 'live' | 'offline'

export type SimEvent =
  | { kind: 'cropReady'; x: number; y: number; cropId: string; mutation?: string }
  | { kind: 'workerTask'; task: WorkerTask }
  | { kind: 'autoSold'; earned: number }
  | { kind: 'foremanBought'; upgrade: Upgrade }

/** Sprinklers and irrigation top up the soil past the end of the span, so covered crops count as wet throughout. */
function waterStep(state: GameState, dt: number): void {
  const until = state.worldTime + dt + 60
  if (hasAutomation(state, 'irrigation')) {
    for (const plot of Object.values(state.plots)) {
      if (plot.wetUntil < until) plot.wetUntil = until
    }
    return
  }
  for (const sprinkler of state.sprinklers) {
    const r = machineDef(sprinkler.kind)?.radius ?? 0
    for (let y = sprinkler.y - r; y <= sprinkler.y + r; y++) {
      for (let x = sprinkler.x - r; x <= sprinkler.x + r; x++) {
        const plot = plotAt(state, x, y)
        if (plot && plot.wetUntil < until) plot.wetUntil = until
      }
    }
  }
}

/** Exact for any step size: the wet part of a step comes from `wetUntil`, so a long catch-up matches 60 fps play. */
function cropStep(state: GameState, dt: number, events: SimEvent[]): void {
  const start = state.worldTime
  const speed = growthSpeed(state)
  for (const plot of Object.values(state.plots)) {
    const crop = plot.crop
    const def = crop && cropDef(crop.cropId)
    if (!crop || !def || crop.growth >= def.growthSeconds) continue
    const wetTime = Math.min(Math.max(plot.wetUntil - start, 0), dt)
    const gain = (wetTime + (dt - wetTime) * BALANCE.dryGrowthRate) * speed
    crop.growth = Math.min(def.growthSeconds, crop.growth + gain)
    if (crop.growth >= def.growthSeconds) {
      crop.mutation = rollMutation(state)?.id
      events.push({ kind: 'cropReady', x: plot.x, y: plot.y, cropId: def.id, mutation: crop.mutation })
    }
  }
}

/** Farmhands work a task at a time while the game is open, and rest while it's closed. */
function workerStep(state: GameState, dt: number, events: SimEvent[]): void {
  const pace = (dt / DAY) * BALANCE.workerTasksPerDay * workerSpeed(state)
  state.workers.forEach((worker, index) => {
    worker.progress += pace
    while (worker.progress >= 1 - 1e-9) {
      const task = workerTask(state, index)
      if (!task) {
        // Nothing to do: they wait, without banking the idle time.
        worker.progress = Math.min(worker.progress, 1)
        break
      }
      events.push({ kind: 'workerTask', task })
      worker.progress = Math.max(0, worker.progress - 1)
    }
  })
}

function driverStep(state: GameState, dt: number, events: SimEvent[]): void {
  if (!hasAutomation(state, 'driver')) return
  state.driverClock += dt
  if (state.driverClock < BALANCE.driverSeconds * TIME_SCALE) return
  state.driverClock = 0
  const earned = sellAll(state)
  if (earned > 0) events.push({ kind: 'autoSold', earned })
}

/** The Foreman buys whatever is affordable, cheapest first. Sprinklers need placing, so those wait for you. */
function foremanStep(state: GameState, dt: number, events: SimEvent[]): void {
  if (!hasAutomation(state, 'foreman')) return
  state.foremanClock += dt
  if (state.foremanClock < BALANCE.foremanInterval) return
  state.foremanClock = 0
  // Bounded, so a big windfall still buys in visible rounds.
  for (let bought = 0; bought < 20; bought++) {
    const upgrade = availableUpgrades(state).find((item) => item.kind !== 'machine' && item.level <= state.level && item.cost <= state.money)
    if (!upgrade || buy(state, upgrade)) return
    events.push({ kind: 'foremanBought', upgrade })
  }
}

function trackIncome(state: GameState, dt: number, before: number): void {
  const seconds = dt / TIME_SCALE
  const share = 1 - Math.exp(-seconds / BALANCE.incomeAverageSeconds)
  state.income += ((state.runCoins - before) / seconds - state.income) * share
}

/** Advances the world by `dt` sim seconds. */
export function step(state: GameState, dt: number, mode: SimMode = 'live'): SimEvent[] {
  const events: SimEvent[] = []
  if (dt <= 0) return events
  const coinsBefore = state.runCoins
  waterStep(state, dt)
  cropStep(state, dt, events)
  if (mode === 'live') {
    workerStep(state, dt, events)
    driverStep(state, dt, events)
    foremanStep(state, dt, events)
    trackIncome(state, dt, coinsBefore)
  }
  state.worldTime += dt
  return events
}

export interface AwaySummary {
  awaySeconds: number
  ripened: number
  earned: number
}

/** Hours of absence that earn coins. */
export function offlineHours(state: GameState): number {
  return BALANCE.offlineEarningHours + perkLevel(state, 'long_naps') * 2
}

/**
 * Jumps the farm ahead: crops grow for `seconds` of real time, and a farm with
 * a driver earns `rate` of its usual income for `paidSeconds`. Farmhands don't
 * work the jump, so ripe crops wait for them.
 */
export function fastForward(state: GameState, seconds: number, paidSeconds: number, rate: number): { ripened: number; earned: number } {
  const ripeBefore = Object.values(state.plots).filter((plot) => plot.crop && isReady(plot.crop)).length
  step(state, seconds * TIME_SCALE, 'offline')
  const ripeAfter = Object.values(state.plots).filter((plot) => plot.crop && isReady(plot.crop)).length
  const earned = hasAutomation(state, 'driver') ? Math.round(state.income * paidSeconds * rate) : 0
  if (earned > 0) earn(state, earned)
  return { ripened: ripeAfter - ripeBefore, earned }
}

/** Catches the farm up after an absence. */
export function catchUp(state: GameState, now: number): AwaySummary {
  const away = Math.min(Math.max(0, (now - state.lastSavedAt) / 1000), BALANCE.offlineCatchUpCap)
  state.lastSavedAt = now
  const paidSeconds = Math.min(away, offlineHours(state) * 3600)
  return { awaySeconds: away, ...fastForward(state, away, paidSeconds, BALANCE.offlineEarningRate) }
}
