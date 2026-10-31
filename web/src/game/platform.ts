import { useSaveStore, type SaveStore } from '../core/save'

/** The parts of the CrazyGames SDK the game uses. Docs: https://docs.crazygames.com/sdk/intro/ */
interface AdCallbacks {
  adStarted: () => void
  adFinished: () => void
  adError: (error: { code: string; message: string }) => void
}

interface CrazySdk {
  init: () => Promise<void>
  environment: 'local' | 'crazygames' | 'disabled'
  ad: { requestAd: (kind: 'midgame' | 'rewarded', callbacks: AdCallbacks) => void }
  game: {
    gameplayStart: () => void
    gameplayStop: () => void
    loadingStart: () => void
    loadingStop: () => void
    happytime: () => void
    settings: { muteAudio: boolean }
    addSettingsChangeListener: (listener: (settings: { muteAudio: boolean }) => void) => void
  }
  data: SaveStore
}

declare global {
  interface Window {
    CrazyGames?: { SDK: CrazySdk }
  }
}

/** The game still starts if the SDK never answers. */
const CONNECT_TIMEOUT_MS = 5_000

/**
 * Ads are off during Basic Launch, and CrazyGames rejects a game whose ad
 * buttons do nothing. So they're only in the build made for Full Launch:
 * `npm run package:ads`.
 */
const ADS_BUILD = import.meta.env.DEV || import.meta.env.VITE_REWARDED_ADS === '1'

let sdk: CrazySdk | null = null
let inGameplay = false
/** Ads turned out to be off for this session: disabled, or blocked. */
let adsOff = false

/** Connects to the portal if there is one. Everywhere else the game runs the same, without it. */
export async function connectPlatform(onMuteChange: (muted: boolean) => void): Promise<void> {
  const candidate = window.CrazyGames?.SDK
  if (!candidate) return
  try {
    const timeout = new Promise<void>((_, reject) => window.setTimeout(() => reject(new Error('timed out')), CONNECT_TIMEOUT_MS))
    await Promise.race([candidate.init(), timeout])
  } catch {
    return
  }
  if (candidate.environment === 'disabled') return
  sdk = candidate
  if (candidate.environment === 'crazygames') useSaveStore(candidate.data)
  onMuteChange(candidate.game.settings.muteAudio)
  candidate.game.addSettingsChangeListener((settings) => onMuteChange(settings.muteAudio))
}

export function loadingStarted(): void {
  sdk?.game.loadingStart()
}

export function loadingFinished(): void {
  sdk?.game.loadingStop()
}

/** Tells the portal play has started or stopped, for menus and breaks. Tab switches are its own business. */
export function setGameplay(playing: boolean): void {
  if (playing === inGameplay) return
  inGameplay = playing
  if (playing) sdk?.game.gameplayStart()
  else sdk?.game.gameplayStop()
}

/** For big moments only. */
export function celebrateOnPortal(): void {
  sdk?.game.happytime()
}

export function adsOffered(): boolean {
  return ADS_BUILD && sdk !== null && !adsOff
}

export interface AdHooks {
  /** The ad really started. Audio goes quiet here, not on request. */
  started: () => void
  finished: () => void
  /** Why there was no ad. No reward goes with this. */
  failed: (code: string) => void
}

function requestAd(kind: 'midgame' | 'rewarded', hooks: AdHooks): void {
  sdk?.ad.requestAd(kind, {
    adStarted: hooks.started,
    adFinished: hooks.finished,
    adError: (error) => {
      if (error.code === 'adsDisabled' || error.code === 'adblock') adsOff = true
      hooks.failed(error.code)
    },
  })
}

export function showRewardedAd(hooks: AdHooks): void {
  requestAd('rewarded', hooks)
}

/** A break ad, for natural pauses. The SDK decides whether one is due. */
export function showBreakAd(hooks: AdHooks): void {
  requestAd('midgame', hooks)
}
