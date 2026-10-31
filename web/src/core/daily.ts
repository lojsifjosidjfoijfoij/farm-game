import { BALANCE } from './content'
import { earn, type GameState } from './state'

const MS_PER_DAY = 24 * 60 * 60 * 1000

export interface DailyGift {
  coins: number
  streak: number
}

/** The first visit of each day pays out. Missing a day starts the streak over. */
export function claimDailyGift(state: GameState, now: number): DailyGift | null {
  const day = Math.floor(now / MS_PER_DAY)
  if (day <= state.giftDay) return null
  state.giftStreak = day === state.giftDay + 1 ? state.giftStreak + 1 : 1
  state.giftDay = day
  const days = Math.min(state.giftStreak, BALANCE.giftStreakCap)
  const coins = Math.max(BALANCE.giftMinimum, Math.round(state.income * BALANCE.giftIncomeSeconds)) * days
  earn(state, coins)
  return { coins, streak: state.giftStreak }
}
