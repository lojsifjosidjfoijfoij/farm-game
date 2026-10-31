import { newGame, type GameState } from './state'

export const SAVE_KEY = 'valley-farm-save'

/** Saves stay on this device. Storage can be blocked or full, and the game must keep running either way. */
export function writeSave(state: GameState, now: number): void {
  state.lastSavedAt = now
  try {
    localStorage.setItem(SAVE_KEY, JSON.stringify(state))
  } catch {
    // The farm just won't be there next time.
  }
}

export function parseSave(json: string | null): GameState | null {
  if (!json) return null
  try {
    const state = JSON.parse(json) as Partial<GameState>
    if (state.version !== 1 || typeof state.money !== 'number' || typeof state.plots !== 'object') return null
    // Anything added to GameState later gets its default on an older save.
    return { ...newGame(), ...state } as GameState
  } catch {
    return null
  }
}

export function readSave(): GameState | null {
  try {
    return parseSave(localStorage.getItem(SAVE_KEY))
  } catch {
    return null
  }
}
