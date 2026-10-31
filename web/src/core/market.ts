import { BALANCE, cropDef } from './content'
import { cropsFor, cropValue } from './progress'
import { addCounter, earn, stableHash, today, trainingLevel, type GameState } from './state'

/**
 * The rules of supply and demand, as in AcresCore's `Market`. Each item has a
 * depth: the coins' worth the market takes before its price falls by half.
 * The factor for the next one is `1 / (1 + recent / depth)`, never below the
 * floor, and most of the drop wears off each day.
 */
function depth(state: GameState): number {
  const reach = Math.pow(1.25, trainingLevel(state, 'reach'))
  return BALANCE.marketDepth * reach * (state.windmill ? BALANCE.windmillMarketDepth : 1)
}

function factorFor(sold: number, marketDepth: number): number {
  return Math.max(BALANCE.marketPriceFloor, 1 / (1 + sold / Math.max(1, marketDepth)))
}

function memory(): number {
  return 1 - BALANCE.marketRecoveryPerDay
}

function weight(itemId: string): number {
  return cropDef(itemId)?.marketWeight ?? 0
}

/** Recent sales of an item in coins, as of today (fading days applied). */
export function recent(state: GameState, itemId: string): number {
  const sold = state.market.sold[itemId] ?? 0
  const days = state.market.day < 0 ? 0 : Math.max(0, today(state) - state.market.day)
  return sold * Math.pow(memory(), days)
}

/** Today's price factor for the next one sold (1 = a fresh market). */
export function marketFactor(state: GameState, itemId: string): number {
  return factorFor(recent(state, itemId), depth(state))
}

function priceDay(state: GameState): number {
  return Math.floor(today(state) / BALANCE.marketDaysPerPrice)
}

const specialMemo = { key: '', id: '' }

/** Today's special, chosen from what the farmer can grow, so it's always within reach. */
export function marketSpecial(state: GameState): string {
  // Asked for on every price, and it only changes every minute or so.
  const key = `${priceDay(state)}:${state.level}:${state.totalRebirths}`
  if (specialMemo.key !== key) {
    const grown = cropsFor(state)
    specialMemo.key = key
    specialMemo.id = grown[stableHash(`special:${priceDay(state)}`) % grown.length].id
  }
  return specialMemo.id
}

/** Today's price before the market's mood, drifting inside the item's usual range. */
export function basePrice(state: GameState, itemId: string): number {
  const def = cropDef(itemId)
  if (!def) return 0
  const [low, high] = def.sellPrice
  const drift = stableHash(`${itemId}:${priceDay(state)}`) / 0xffffffff
  let price = (low + Math.round((high - low) * drift)) * cropValue(state, itemId) * BALANCE.priceScale
  if (marketSpecial(state) === itemId) price *= 1 + BALANCE.marketSpecialBonus
  return Math.max(1, Math.round(price))
}

const bestMemo = { stamp: '', id: '' }

/**
 * The crop that pays best per plot right now, after market prices and what
 * it costs to sow. The Foreman replants with this, which spreads a farm
 * across crops by itself as each one's price sags.
 */
export function bestCrop(state: GameState): string {
  // Farmhands ask on every task; once per step is plenty, and keeps a fast farm fast.
  const stamp = `${state.worldTime}:${state.rebirths}`
  if (bestMemo.stamp === stamp) return bestMemo.id
  let best = state.seed
  let bestScore = -Infinity
  for (const crop of cropsFor(state)) {
    if (crop.seedCost > state.money) continue
    const items = (crop.yield[0] + crop.yield[1]) / 2
    const regrowth = crop.regrowSeconds ?? crop.growthSeconds
    const score = (items * basePrice(state, crop.id) * marketFactor(state, crop.id) - crop.seedCost) / regrowth
    if (score > bestScore) {
      best = crop.id
      bestScore = score
    }
  }
  bestMemo.stamp = stamp
  bestMemo.id = best
  return best
}

/** Most sales are priced item by item; a huge load goes in this many lots, so it stays quick. */
const MAX_LOTS = 64

/** What selling `amount` would earn now, each one a little less than the last. */
export function quote(state: GameState, itemId: string, amount: number): number {
  if (amount <= 0 || !cropDef(itemId)) return 0
  const unitPrice = basePrice(state, itemId)
  const marketDepth = depth(state)
  const itemWeight = weight(itemId)
  const lots = Math.min(amount, MAX_LOTS)
  const lotSize = amount / lots
  let sold = recent(state, itemId)
  let total = 0
  for (let i = 0; i < lots; i++) {
    total += Math.max(1, Math.round(unitPrice * factorFor(sold, marketDepth))) * lotSize
    sold += itemWeight * lotSize
  }
  return Math.min(BALANCE.maxCoins, total)
}

/** Records a sale: brings every item up to today, then adds this one. */
function record(state: GameState, itemId: string, amount: number): void {
  const day = today(state)
  if (state.market.day !== day) {
    const days = state.market.day < 0 ? 0 : Math.max(0, day - state.market.day)
    const fade = Math.pow(memory(), days)
    const sold: Record<string, number> = {}
    for (const [id, value] of Object.entries(state.market.sold)) {
      if (value * fade >= 1) sold[id] = value * fade
    }
    state.market = { day, sold }
  }
  state.market.sold[itemId] = (state.market.sold[itemId] ?? 0) + weight(itemId) * amount
}

function sellStock(state: GameState, itemId: string): number {
  const amount = state.inventory[itemId] ?? 0
  const earned = quote(state, itemId, amount)
  if (earned === 0) return 0
  record(state, itemId, amount)
  delete state.inventory[itemId]
  earn(state, earned)
  addCounter(state, 'coinsFromSales', earned)
  return earned
}

/** Sells all of one item. Returns the coins earned. */
export function sell(state: GameState, itemId: string): number {
  const earned = sellStock(state, itemId)
  if (earned > 0) addCounter(state, 'sales')
  return earned
}

/** The extra a harvest chain pays, right away, for this link. */
export function comboBonus(state: GameState, cropId: string, amount: number, combo: number): number {
  const links = Math.min(combo - 1, BALANCE.comboCap)
  return links <= 0 ? 0 : Math.max(1, Math.round(amount * basePrice(state, cropId) * links * BALANCE.comboStep))
}

/** What catching the Golden Hen pays: enough to matter at any size of farm. */
export function henReward(state: GameState): number {
  return Math.max(BALANCE.henMinimum, Math.round(state.income * BALANCE.henIncomeSeconds))
}

export function sellAllQuote(state: GameState): number {
  return Object.entries(state.inventory).reduce((sum, [id, amount]) => sum + quote(state, id, amount), 0)
}

export function sellAll(state: GameState): number {
  const earned = Object.keys(state.inventory).reduce((sum, id) => sum + sellStock(state, id), 0)
  if (earned > 0) addCounter(state, 'sales')
  return earned
}
