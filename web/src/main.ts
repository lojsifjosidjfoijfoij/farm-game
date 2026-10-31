import './styles.css'
import { applyBoost, buyBoost, type BoostKind } from './core/boosts'
import { BALANCE, CROPS, cropDef, exoticCrop, mutationDef, type PerkDef } from './core/content'
import { buy, buyMax, placeMachine, placeProblem, type Upgrade } from './core/estate'
import { perform, suggestedAction, toolAction, type FarmActionKind, type FarmOutcome } from './core/farming'
import { checkGoals, currentGoal } from './core/goals'
import { sell, sellAll } from './core/market'
import { REAL_SECONDS_PER_DAY, TIME_SCALE } from './core/pace'
import { growthSpeed } from './core/progress'
import { ascend, bigBang, buyPerk, rebirth } from './core/rebirth'
import { readSave, writeSave } from './core/save'
import { catchUp, step, type SimEvent } from './core/simulation'
import { earn, isWet, newGame, parcelAt, plotAt, type GameState } from './core/state'
import { artURL, cropIconURL, loadArt } from './game/assets'
import { coins, failureMessage, Hud, hoverText, seedsShown, type Panel } from './game/hud'
import {
  adsOffered, celebrateOnPortal, connectPlatform, loadingFinished, loadingStarted, setGameplay, showBreakAd, showRewardedAd,
  type AdHooks,
} from './game/platform'
import { isMuted, play, setAdPlaying, setMuted, setPortalMuted, unlockAudio, type SoundEffect } from './game/sound'
import { WorldView } from './game/view'

/** Working title. Also in index.html and the save key. */
const GAME_TITLE = 'Valley Farm'

const AUTOSAVE_SECONDS = 10

/** A fast farm finishes dozens of jobs a frame. Only this many get shown. */
const SHOWN_TASKS_PER_FRAME = 6

class Game {
  private state: GameState
  private placing: string | null = null
  private panel: Panel | null = null
  private hover: { x: number; y: number } | null = null
  /** The job a press started: dragging repeats it across the field. */
  private stroke: { kind: FarmActionKind; x: number; y: number } | null = null
  private lastFrame = performance.now()
  private lastSave = performance.now()
  /** The world holds still while an ad is requested or playing. */
  private adBusy = false
  private readonly view: WorldView
  private readonly hud: Hud
  private readonly tooltip: HTMLElement

  constructor(canvas: HTMLCanvasElement, hudRoot: HTMLElement, tooltip: HTMLElement) {
    const saved = readSave()
    this.state = saved ?? newGame(Date.now())
    this.tooltip = tooltip
    this.view = new WorldView(canvas)
    this.hud = new Hud(hudRoot, {
      selectSeed: (id) => this.selectSeed(id),
      sellAll: () => this.sellEverything(),
      sellItem: (id) => this.sellOne(id),
      buy: (upgrade) => this.buyUpgrade(upgrade),
      buyMax: (id) => this.buyMaxOf(id),
      buyPerk: (perk) => this.buyPerkOf(perk),
      buyBoost: (kind) => this.takeBoost(kind),
      watchBoost: (kind) => this.watchBoost(kind),
      rebirth: () => this.startOver('rebirth'),
      ascend: () => this.startOver('ascend'),
      bigBang: () => this.startOver('bigBang'),
      togglePanel: (panel) => this.setPanel(this.panel === panel ? null : panel),
      closePanel: () => this.setPanel(null),
      toggleSound: () => setMuted(!isMuted()),
      cancelPlacing: () => {
        this.placing = null
      },
    })
    if (saved) this.welcomeBack()
    setGameplay(true)
    // Only in the build promo/make-promo.mjs records from.
    if (import.meta.env.VITE_PROMO === '1') Object.assign(window, { game: this })
    this.bindInput(canvas)
    this.bindLifecycle()
    requestAnimationFrame((now) => this.frame(now))
  }

  private welcomeBack(): void {
    const summary = catchUp(this.state, Date.now())
    if (summary.awaySeconds < 60) return
    if (summary.earned > 0 && adsOffered()) {
      setGameplay(false)
      this.hud.showWelcome(summary.earned, () => this.watchAd(() => {
        earn(this.state, summary.earned)
        this.rewardShown('Doubled!', `+${coins(summary.earned)} coins`)
      }), () => setGameplay(this.panel === null))
    } else if (summary.earned > 0) {
      this.hud.showBanner('Welcome back', `Your farm earned ${coins(summary.earned)} coins while you were away.`)
    } else if (summary.ripened > 0) {
      this.hud.showBanner('Welcome back', `${summary.ripened} ${summary.ripened === 1 ? 'plot' : 'plots'} ripened while you were away.`)
    }
  }

  private frame(now: number): void {
    const realDt = Math.min((now - this.lastFrame) / 1000, 0.25)
    this.lastFrame = now
    if (!this.adBusy) this.handleEvents(step(this.state, realDt * TIME_SCALE))
    this.finishGoals()
    if (now - this.lastSave > AUTOSAVE_SECONDS * 1000) this.save(now)

    const goal = currentGoal(this.state)
    this.view.draw(this.state, { hover: this.hover, placing: this.placing, guide: goal?.target ?? null })
    this.hud.update(this.state, this.state.seed, this.placing)
    requestAnimationFrame((next) => this.frame(next))
  }

  private handleEvents(events: SimEvent[]): void {
    let shown = 0
    for (const event of events) {
      if (event.kind === 'autoSold') {
        this.view.sendTruck()
        play('coins')
        const point = this.view.screenPoint(19.4, 3.6)
        this.hud.floater(point.x, point.y, `+${coins(event.earned)}`, artURL('ui_icon_coin'))
      } else if (event.kind === 'workerTask') {
        const { task } = event
        if (shown < SHOWN_TASKS_PER_FRAME) {
          shown += 1
          this.view.workerActs(task.worker, task.x, task.y, task.action.kind)
        }
        if (task.outcome.ok && task.outcome.kind === 'harvest') {
          if (task.outcome.bonus > 0) this.showRare(task.outcome.mutation, task.outcome.bonus, task.x, task.y)
          if (task.outcome.levelsGained > 0) this.leveledUp()
        }
      } else if (event.kind === 'cropReady' && event.mutation) {
        const point = this.view.screenPoint(event.x, event.y)
        this.hud.floater(point.x, point.y, mutationDef(event.mutation)?.name ?? '', artURL('ui_icon_sparkle'), true)
        play('rare')
      }
    }
  }

  private showRare(mutation: string | undefined, bonus: number, x: number, y: number): void {
    const rare = mutationDef(mutation)
    if (!rare) return
    const point = this.view.screenPoint(x, y)
    this.hud.floater(point.x, point.y, `${rare.name}! +${coins(bonus)}`, artURL('ui_icon_coin'), true)
    this.view.sparkleAt(x + 0.5, y + 0.5)
    play('rare')
    if (rare.multiplier >= 100) this.hud.showBanner(`${rare.name} crop!`, `+${coins(bonus)} coins`)
  }

  private save(now = performance.now()): void {
    this.lastSave = now
    writeSave(this.state, Date.now())
  }

  private finishGoals(): void {
    for (const goal of checkGoals(this.state)) {
      if (goal.trophy) {
        play('goal')
        this.hud.toast('Trophy! Every crop is worth 20% more, for good.')
      } else if (goal.reward > 0) {
        play('goal')
        this.hud.toast(`Goal done: +${coins(goal.reward)} coins`)
      }
    }
  }

  // MARK: Input

  private bindInput(canvas: HTMLCanvasElement): void {
    canvas.addEventListener('pointerdown', (event) => {
      unlockAudio()
      canvas.setPointerCapture(event.pointerId)
      this.press(this.view.tileAt(event.clientX, event.clientY))
    })
    canvas.addEventListener('pointermove', (event) => {
      const tile = this.view.tileAt(event.clientX, event.clientY)
      this.hover = tile
      this.showTooltip(event.clientX, event.clientY, tile)
      if (this.stroke) this.drag(tile)
    })
    canvas.addEventListener('pointerleave', () => {
      this.hover = null
      this.tooltip.hidden = true
    })
    const release = (): void => {
      this.stroke = null
    }
    canvas.addEventListener('pointerup', release)
    canvas.addEventListener('pointercancel', release)
    canvas.addEventListener('contextmenu', (event) => event.preventDefault())
    document.addEventListener('pointerdown', unlockAudio, { once: true })

    window.addEventListener('resize', () => this.view.resize())
    window.addEventListener('keydown', (event) => this.key(event))
  }

  private key(event: KeyboardEvent): void {
    if (event.key === 'Escape') {
      this.placing = null
      this.setPanel(null)
    } else if (event.key === 's' || event.key === 'S') {
      this.sellEverything()
    } else if (event.key === 'f' || event.key === 'F') {
      this.setPanel(this.panel === 'farm' ? null : 'farm')
    } else if (event.key === 'm' || event.key === 'M') {
      this.setPanel(this.panel === 'market' ? null : 'market')
    } else if (event.key === 'r' || event.key === 'R') {
      this.setPanel(this.panel === 'rebirth' ? null : 'rebirth')
    } else {
      const crop = seedsShown(this.state)[Number(event.key) - 1]
      if (crop) this.selectSeed(crop.id)
    }
  }

  private press(tile: { x: number; y: number }): void {
    if (this.panel) {
      this.setPanel(null)
      return
    }
    if (this.placing) {
      this.place(tile)
      return
    }
    const parcel = parcelAt(tile.x, tile.y)
    if (parcel && !this.state.ownedParcels.includes(parcel.id)) {
      this.setPanel('farm')
      return
    }
    const action = suggestedAction(this.state, tile.x, tile.y, this.state.seed)
    if (!action) return
    this.stroke = { kind: action.kind, x: tile.x, y: tile.y }
    this.apply(action.kind, tile.x, tile.y)
  }

  /** Walks the line from the last tile to this one, so a fast flick misses nothing. */
  private drag(tile: { x: number; y: number }): void {
    const stroke = this.stroke
    if (!stroke || (stroke.x === tile.x && stroke.y === tile.y)) return
    const steps = Math.max(Math.abs(tile.x - stroke.x), Math.abs(tile.y - stroke.y))
    for (let i = 1; i <= steps; i++) {
      const x = Math.round(stroke.x + ((tile.x - stroke.x) * i) / steps)
      const y = Math.round(stroke.y + ((tile.y - stroke.y) * i) / steps)
      this.apply(stroke.kind, x, y)
    }
    stroke.x = tile.x
    stroke.y = tile.y
  }

  private apply(kind: FarmActionKind, x: number, y: number): void {
    const action = toolAction(this.state, kind, x, y, this.state.seed)
    if (typeof action === 'string') return
    this.react(perform(this.state, action, x, y), x, y)
    this.finishGoals()
  }

  private react(outcome: FarmOutcome, x: number, y: number): void {
    if (!outcome.ok) {
      const message = failureMessage(outcome.failure, this.state.seed)
      if (message) {
        this.hud.toast(message)
        play('refuse')
        if (outcome.failure === 'storageFull') this.hud.nudgeSell()
      }
      return
    }
    this.view.farmerActs(x, y, outcome.kind)
    const effect: Record<FarmActionKind, SoundEffect> = { plow: 'plow', plant: 'plant', water: 'water', harvest: 'harvest' }
    play(effect[outcome.kind])
    if (outcome.kind === 'harvest') {
      const point = this.view.screenPoint(x, y)
      const def = cropDef(outcome.cropId)
      if (def) this.hud.floater(point.x, point.y, `+${outcome.amount}`, cropIconURL(def))
      if (outcome.bonus > 0) this.showRare(outcome.mutation, outcome.bonus, x, y)
      if (outcome.levelsGained > 0) this.leveledUp()
    }
  }

  private leveledUp(): void {
    const level = this.state.level
    const opened = CROPS.filter((crop) => crop.unlockLevel === level).map((crop) => crop.name)
    if (opened.length > 0) this.hud.showBanner(`Level ${level}`, `New seeds: ${opened.join(', ')}`)
    else this.hud.toast(`Level ${level}: every crop is worth 2% more`)
    play('levelUp')
    this.view.celebrate()
  }

  private place(tile: { x: number; y: number }): void {
    const kind = this.placing
    if (!kind) return
    const failure = placeMachine(this.state, kind, tile.x, tile.y)
    if (failure) {
      play('refuse')
      this.hud.toast(failure === 'noMoney' ? 'Not enough coins for that.' : "A sprinkler can't go there.")
      return
    }
    this.placing = null
    play('open')
    this.view.sparkleAt(tile.x + 0.5, tile.y + 0.5)
    this.finishGoals()
  }

  private showTooltip(clientX: number, clientY: number, tile: { x: number; y: number }): void {
    const plot = plotAt(this.state, tile.x, tile.y)
    const def = plot?.crop && cropDef(plot.crop.cropId)
    const parcel = parcelAt(tile.x, tile.y)
    let text: string | null = null
    if (this.placing) {
      text = placeProblem(this.state, tile.x, tile.y) ? "Can't go here" : 'Place it here'
    } else if (plot?.crop && def) {
      const wet = isWet(plot, this.state.worldTime)
      const remaining = (def.growthSeconds - plot.crop.growth) / ((wet ? 1 : BALANCE.dryGrowthRate) * growthSpeed(this.state))
      const rare = mutationDef(plot.crop.mutation)
      text = hoverText((remaining / 1440) * REAL_SECONDS_PER_DAY, rare ? `${rare.name} ${def.name}, pays ×${rare.multiplier}` : def.name, wet)
    } else if (parcel && !this.state.ownedParcels.includes(parcel.id)) {
      text = `${parcel.name}: ${coins(parcel.price ?? 0)} coins`
    }
    this.tooltip.hidden = text === null
    if (text) {
      this.tooltip.textContent = text
      this.tooltip.style.left = `${clientX + 14}px`
      this.tooltip.style.top = `${clientY + 16}px`
    }
  }

  private bindLifecycle(): void {
    const leave = (): void => this.save()
    document.addEventListener('visibilitychange', () => {
      if (document.hidden) {
        leave()
      } else {
        // Timers stop while the tab is hidden, so hand the gap to the catch-up.
        this.welcomeBack()
        this.lastFrame = performance.now()
      }
    })
    window.addEventListener('pagehide', leave)
  }

  // MARK: Menus

  private setPanel(panel: Panel | null): void {
    if (panel !== this.panel) play('open')
    this.panel = panel
    this.hud.setPanel(panel)
    setGameplay(panel === null)
  }

  private selectSeed(id: string): void {
    this.state.seed = id
    play('tap')
  }

  private celebrateSale(earned: number): void {
    if (earned <= 0) return
    play('coins')
    this.view.sparkleAt(19.9, 4)
    const point = this.view.screenPoint(19.4, 3.6)
    this.hud.floater(point.x, point.y, `+${coins(earned)}`, 'ui_icon_coin')
    this.finishGoals()
  }

  private sellEverything(): void {
    this.celebrateSale(sellAll(this.state))
  }

  private sellOne(id: string): void {
    this.celebrateSale(sell(this.state, id))
  }

  private buyUpgrade(upgrade: Upgrade): void {
    if (upgrade.kind === 'machine') {
      if (this.state.money < upgrade.cost) return
      this.placing = upgrade.id
      this.setPanel(null)
      return
    }
    const failure = buy(this.state, upgrade)
    if (failure) {
      play('refuse')
      return
    }
    play(upgrade.kind === 'training' ? 'tap' : 'levelUp')
    if (upgrade.kind !== 'training') this.setPanel(null)
    this.hud.toast(`${upgrade.name}: done`)
    this.finishGoals()
  }

  private buyMaxOf(id: string): void {
    const bought = buyMax(this.state, id)
    if (bought === 0) return
    play('tap')
    this.hud.toast(`Bought ${bought} ${bought === 1 ? 'level' : 'levels'}`)
    this.finishGoals()
  }

  private buyPerkOf(perk: PerkDef): void {
    if (buyPerk(this.state, perk)) {
      play('refuse')
      return
    }
    play('goal')
  }

  private takeBoost(kind: BoostKind): void {
    const failure = buyBoost(this.state, kind)
    if (failure) {
      play('refuse')
      return
    }
    this.boostGiven(kind)
  }

  private watchBoost(kind: BoostKind): void {
    this.watchAd(() => {
      applyBoost(this.state, kind)
      this.boostGiven(kind)
    })
  }

  private boostGiven(kind: BoostKind): void {
    if (kind === 'coins') this.rewardShown('Coin Boost!', `×${BALANCE.coinBoostMultiplier} coins for ${BALANCE.coinBoostSeconds} seconds`)
    else this.rewardShown('Time skipped!', `The farm jumped ${BALANCE.skipSeconds / 60} minutes ahead`)
  }

  private rewardShown(title: string, detail: string): void {
    this.hud.showBanner(title, detail)
    play('goal')
    this.view.celebrate()
  }

  private adHooks(after: () => void, failed: (code: string) => void): AdHooks {
    this.adBusy = true
    this.hud.setAdWaiting(true)
    const finish = (): void => {
      this.adBusy = false
      this.hud.setAdWaiting(false)
      setAdPlaying(false)
      this.lastFrame = performance.now()
    }
    return {
      started: () => setAdPlaying(true),
      finished: () => {
        finish()
        after()
      },
      failed: (code) => {
        finish()
        failed(code)
      },
    }
  }

  /** The reward only comes from a finished ad. */
  private watchAd(reward: () => void): void {
    if (this.adBusy) return
    showRewardedAd(this.adHooks(reward, (code) => {
      if (code === 'adsDisabled' || code === 'adblock') this.hud.toast('Ads are off here, so boosts cost coins. Everything else still works.')
      else this.hud.toast('No ad right now. Try again in a bit.')
    }))
  }

  private startOver(kind: 'rebirth' | 'ascend' | 'bigBang'): void {
    const before = this.state.totalRebirths
    let title: string
    let detail: string
    if (kind === 'rebirth') {
      const seeds = rebirth(this.state)
      if (seeds === 0) return
      title = `Rebirth ${this.state.rebirths}`
      detail = `+${coins(seeds)} Golden Seeds`
    } else if (kind === 'ascend') {
      const stars = ascend(this.state)
      if (stars === 0) return
      title = `Ascension ${this.state.ascensions}`
      detail = `+${stars} stars`
    } else {
      if (!bigBang(this.state)) return
      title = 'BIG BANG'
      detail = `Universe ${this.state.universes + 1}`
    }
    const opened = this.openedCrop(before)
    this.placing = null
    this.setPanel(null)
    this.hud.flash(kind)
    this.hud.showBanner(title, opened ? `${detail}. New seed: ${opened}` : detail)
    play('rebirth')
    this.save()
    this.finishGoals()
    if (kind !== 'rebirth' || this.state.totalRebirths === 1) celebrateOnPortal()
    // A new farm is the one natural pause in the game. The SDK decides if an ad is due.
    if (adsOffered()) showBreakAd(this.adHooks(() => undefined, () => undefined))
  }

  /** The exotic crop this rebirth opened, if any. */
  private openedCrop(rebirthsBefore: number): string | null {
    for (let index = 0; index < rebirthsBefore + 2; index++) {
      const crop = exoticCrop(index)
      if (crop.unlockRebirths > rebirthsBefore && crop.unlockRebirths <= this.state.totalRebirths) return crop.name
    }
    return null
  }
}

async function start(): Promise<void> {
  document.title = GAME_TITLE
  const bar = document.querySelector<HTMLElement>('#loading i')!
  await connectPlatform(setPortalMuted)
  loadingStarted()
  await loadArt((fraction) => {
    bar.style.width = `${fraction * 100}%`
  })
  await document.fonts.load('16px Fredoka').catch(() => undefined)
  document.querySelector('#loading')!.remove()
  loadingFinished()
  new Game(
    document.querySelector<HTMLCanvasElement>('#world')!,
    document.querySelector<HTMLElement>('#hud')!,
    document.querySelector<HTMLElement>('#tooltip')!,
  )
}

void start()
