import { boostCost, boostReadyIn, coinBoostLeft, type BoostKind } from '../core/boosts'
import { BALANCE, cropDef, MUTATIONS, PERKS, xpToNextLevel, type PerkDef } from '../core/content'
import { availableUpgrades, type Upgrade } from '../core/estate'
import { currentGoal } from '../core/goals'
import { basePrice, marketFactor, marketSpecial, quote, sellAllQuote } from '../core/market'
import { formatNumber } from '../core/numbers'
import { REAL_SECONDS_PER_DAY } from '../core/pace'
import { cropsFor, masteryLevel, nextCrop, trophies, valueMultiplier } from '../core/progress'
import {
  canAscend, canBigBang, canRebirth, goldenSeedsFor, perkCost, rebirthRequirement, starsFor,
} from '../core/rebirth'
import { offlineHours } from '../core/simulation'
import { perkLevel, storageCapacity, storageUsed, type GameState } from '../core/state'
import { artURL, cropIconURL } from './assets'
import { adsOffered } from './platform'
import { isMuted } from './sound'

export interface HudActions {
  selectSeed: (id: string) => void
  sellAll: () => void
  sellItem: (id: string) => void
  buy: (upgrade: Upgrade) => void
  buyMax: (id: string) => void
  buyPerk: (perk: PerkDef) => void
  buyBoost: (kind: BoostKind) => void
  watchBoost: (kind: BoostKind) => void
  rebirth: () => void
  ascend: () => void
  bigBang: () => void
  togglePanel: (panel: Panel) => void
  closePanel: () => void
  toggleSound: () => void
  cancelPlacing: () => void
}

export type Panel = 'market' | 'farm' | 'rebirth'

function element<K extends keyof HTMLElementTagNameMap>(tag: K, className?: string, text?: string): HTMLElementTagNameMap[K] {
  const node = document.createElement(tag)
  if (className) node.className = className
  if (text !== undefined) node.textContent = text
  return node
}

function picture(url: string, className = 'icon'): HTMLImageElement {
  const image = element('img', className)
  image.src = url
  image.alt = ''
  image.draggable = false
  return image
}

function icon(name: string, className = 'icon'): HTMLImageElement {
  return picture(artURL(name), className)
}

export const coins = formatNumber

/** The seed bar holds this many. Older crops still sell, and the Foreman still uses them. */
const SEEDS_SHOWN = 10

/** The crops worth showing: the latest few, so the bar never grows without end. */
export function seedsShown(state: GameState): ReturnType<typeof cropsFor> {
  return cropsFor(state).slice(-SEEDS_SHOWN)
}

function setText(node: HTMLElement, text: string): void {
  if (node.textContent !== text) node.textContent = text
}

const UPGRADE_ICONS: Record<Upgrade['kind'], string> = {
  parcel: 'ui_icon_field', storage: 'ui_icon_crate', machine: 'prop_sprinkler', worker: 'ui_icon_worker',
  farmhouse: 'ui_icon_house', windmill: 'ui_icon_sparkle', automation: 'ui_icon_hoe', training: 'ui_icon_level',
}

const TRAINING_ICONS: Record<string, string> = {
  seeds: 'ui_icon_seeds', fertilizer: 'ui_icon_drop', barn: 'ui_icon_crate', reach: 'ui_icon_shop',
  training: 'ui_icon_worker', clover: 'ui_icon_sparkle',
}

type Reset = 'rebirth' | 'ascend' | 'bigBang'

function minutes(seconds: number): string {
  const whole = Math.ceil(seconds)
  return `${Math.floor(whole / 60)}:${String(whole % 60).padStart(2, '0')}`
}

const BOOSTS: { kind: BoostKind; name: string; blurb: string; art: string }[] = [
  { kind: 'coins', name: 'Coin Boost', blurb: `×${BALANCE.coinBoostMultiplier} coins for ${BALANCE.coinBoostSeconds} seconds`, art: 'ui_icon_coin' },
  { kind: 'skip', name: 'Skip Time', blurb: `Jump the farm ${BALANCE.skipSeconds / 60} minutes ahead`, art: 'ui_icon_sparkle' },
]

export class Hud {
  private readonly money = element('span', 'value')
  private readonly income = element('small', 'income')
  private readonly multiplier = element('span', 'value')
  private readonly rebirthButton = element('button', 'action rebirth-button')
  private readonly level = element('span', 'value')
  private readonly xpFill = element('i')
  private readonly storage = element('span', 'value')
  private readonly arne = element('div', 'arne')
  private readonly arneText = element('p')
  private readonly arneBar = element('div', 'goal-bar')
  private readonly arneFill = element('i')
  private readonly seedBar = element('div', 'seeds')
  private readonly sellButton = element('button', 'action sell')
  private readonly sellLabel = element('span', 'action-label', 'Sell')
  private readonly marketButton = element('button', 'action')
  private readonly farmButton = element('button', 'action')
  private readonly farmBadge = element('b', 'badge')
  private readonly soundButton = element('button', 'chip-button')
  private readonly panel = element('section', 'panel')
  private readonly panelBody = element('div', 'panel-body')
  private readonly panelTitle = element('h2')
  private readonly toasts = element('div', 'toasts')
  private readonly banner = element('div', 'banner')
  private readonly placingNote = element('div', 'placing-note')
  private readonly adWait = element('div', 'ad-wait')
  private seedSignature = ''
  private panelSignature = ''
  private panelOpen: Panel | null = null
  /** The reset waiting for a second click. Starting over shouldn't be one slip away. */
  private confirming: Reset | null = null
  /** A button in the panel is being pressed. Redrawing now would swallow the click. */
  private panelHeld = false
  private confirmTimer = 0

  constructor(private readonly root: HTMLElement, private readonly actions: HudActions) {
    this.buildTop()
    this.buildBottom()
    // A mouse wheel only scrolls up and down; the seed row runs sideways.
    this.seedBar.addEventListener('wheel', (event) => {
      this.seedBar.scrollLeft += event.deltaY
    }, { passive: true })
    this.buildPanel()
    this.panel.addEventListener('pointerdown', () => {
      this.panelHeld = true
    })
    const letGo = (): void => {
      this.panelHeld = false
    }
    window.addEventListener('pointerup', letGo)
    window.addEventListener('pointercancel', letGo)
    this.adWait.append(element('span', '', 'Loading ad…'))
    this.adWait.hidden = true
    root.append(this.toasts, this.banner, this.placingNote, this.adWait)
  }

  private buildTop(): void {
    const top = element('div', 'top')
    const stats = element('div', 'stats')

    const money = element('div', 'chip')
    const moneyStack = element('div', 'stack')
    moneyStack.append(this.money, this.income)
    money.append(icon('ui_icon_coin'), moneyStack)

    const level = element('div', 'chip level')
    const bar = element('div', 'xp')
    bar.append(this.xpFill)
    level.append(icon('ui_icon_level'), this.level, bar)

    const storage = element('div', 'chip')
    storage.append(icon('ui_icon_crate'), this.storage)

    const multiplier = element('div', 'chip multiplier')
    multiplier.title = 'Everything multiplying your crop prices'
    multiplier.append(icon('ui_icon_sparkle'), this.multiplier)
    stats.append(money, multiplier, level, storage)

    this.arne.append(icon('ui_portrait_mentor', 'portrait'))
    const words = element('div', 'words')
    this.arneBar.append(this.arneFill)
    words.append(this.arneText, this.arneBar)
    this.arne.append(words)

    this.soundButton.addEventListener('click', this.actions.toggleSound)
    this.soundButton.title = 'Sound'
    top.append(stats, this.arne, this.soundButton)
    this.root.append(top)
  }

  private buildBottom(): void {
    const bottom = element('div', 'bottom')
    this.sellButton.append(icon('ui_icon_coin'), this.sellLabel)
    this.sellButton.addEventListener('click', this.actions.sellAll)

    this.marketButton.append(icon('ui_icon_shop'), element('span', 'action-label', 'Market'))
    this.marketButton.addEventListener('click', () => this.actions.togglePanel('market'))

    this.farmButton.append(icon('ui_icon_house'), element('span', 'action-label', 'Farm'), this.farmBadge)
    this.farmButton.addEventListener('click', () => this.actions.togglePanel('farm'))

    this.rebirthButton.append(icon('ui_icon_sparkle'), element('span', 'action-label', 'Rebirth'))
    this.rebirthButton.addEventListener('click', () => this.actions.togglePanel('rebirth'))

    const buttons = element('div', 'actions')
    buttons.append(this.sellButton, this.marketButton, this.farmButton, this.rebirthButton)
    bottom.append(this.seedBar, buttons)
    this.root.append(bottom)
  }

  private buildPanel(): void {
    const header = element('header')
    const close = element('button', 'close')
    close.append(icon('ui_icon_close'))
    close.setAttribute('aria-label', 'Close')
    close.addEventListener('click', this.actions.closePanel)
    header.append(this.panelTitle, close)
    this.panel.append(header, this.panelBody)
    this.panel.hidden = true
    this.root.append(this.panel)
  }

  setPanel(panel: Panel | null): void {
    this.panelOpen = panel
    this.panelSignature = ''
    this.panel.hidden = panel === null
    this.panelBody.scrollTop = 0
    this.confirming = null
    if (panel) setText(this.panelTitle, { market: 'Market', farm: 'Your farm', rebirth: 'Rebirth' }[panel])
  }

  /** Runs every frame, so it only touches what changed. */
  update(state: GameState, seed: string, placing: string | null): void {
    setText(this.money, coins(state.money))
    setText(this.income, state.income >= 1 ? `+${coins(state.income)}/s` : '')
    setText(this.multiplier, `×${coins(valueMultiplier(state))}`)
    setText(this.level, `Level ${state.level}`)
    const needed = xpToNextLevel(state.level)
    this.xpFill.style.width = `${Math.min(100, (state.xp / needed) * 100)}%`

    const used = storageUsed(state)
    const capacity = storageCapacity(state)
    setText(this.storage, `${coins(used)} / ${coins(capacity)}`)
    this.storage.classList.toggle('full', used >= capacity)

    const goal = currentGoal(state)
    setText(this.arneText, goal.text)
    this.arneBar.hidden = goal.needed <= 1
    this.arneFill.style.width = `${Math.min(1, goal.progress(state) / goal.needed) * 100}%`

    const quoted = sellAllQuote(state)
    setText(this.sellLabel, quoted > 0 ? `Sell ${coins(quoted)}` : 'Sell')
    this.sellButton.disabled = quoted === 0
    this.sellButton.classList.toggle('pulse', goal.target === 'sell' && quoted > 0)
    this.marketButton.classList.toggle('pulse', goal.target === 'market' && this.panelOpen === null && quoted > 0)

    const ready = availableUpgrades(state).filter((item) => item.level <= state.level && item.cost <= state.money).length
    setText(this.farmBadge, ready > 0 ? String(ready) : '')
    this.farmBadge.hidden = ready === 0
    this.farmButton.classList.toggle('pulse', goal.target === 'farm' && ready > 0 && this.panelOpen === null)
    this.rebirthButton.classList.toggle('pulse', this.panelOpen === null && (canRebirth(state) || canAscend(state) || canBigBang(state)))

    setText(this.soundButton, isMuted() ? 'Sound off' : 'Sound on')

    this.renderSeeds(state, seed, goal.target === 'seeds')
    if (!this.panelHeld) {
      if (this.panelOpen === 'market') this.renderMarket(state)
      if (this.panelOpen === 'farm') this.renderFarm(state)
      if (this.panelOpen === 'rebirth') this.renderRebirth(state)
    }

    this.placingNote.hidden = placing === null
    if (placing) this.renderPlacing(placing)
  }

  private renderPlacing(placing: string): void {
    if (this.placingNote.dataset.kind === placing) return
    this.placingNote.dataset.kind = placing
    this.placingNote.replaceChildren()
    const cancel = element('button', 'small', 'Cancel')
    cancel.addEventListener('click', this.actions.cancelPlacing)
    this.placingNote.append(element('span', '', 'Click a spot in your field. Not on a crop.'), cancel)
  }

  /** The latest crops you can grow, plus the next one coming up. */
  private renderSeeds(state: GameState, seed: string, pulse: boolean): void {
    const shown = seedsShown(state)
    const next = nextCrop(state)
    const signature = [seed, state.level, state.totalRebirths, pulse].join('|')
    if (signature === this.seedSignature) return
    this.seedSignature = signature
    this.seedBar.replaceChildren()
    this.seedBar.classList.toggle('pulse', pulse)

    shown.forEach((crop, index) => {
      const slot = element('button', crop.id === seed ? 'seed selected' : 'seed')
      const days = (crop.growthSeconds / 1440) * REAL_SECONDS_PER_DAY
      slot.title = `${crop.name}: ${coins(crop.seedCost)} coins a seed, ripe in ${Math.round(days)}s when watered`
      slot.append(picture(cropIconURL(crop)), element('span', 'seed-cost', coins(crop.seedCost)))
      if (index < 9) slot.append(element('kbd', '', String(index + 1)))
      slot.addEventListener('click', () => this.actions.selectSeed(crop.id))
      this.seedBar.append(slot)
      if (crop.id === seed) slot.scrollIntoView({ block: 'nearest', inline: 'nearest' })
    })
    const slot = element('div', 'seed locked')
    const needs = next.unlockRebirths > state.totalRebirths ? `${next.unlockRebirths - state.totalRebirths} more` : `Lv ${next.unlockLevel}`
    slot.title = next.unlockRebirths > state.totalRebirths
      ? `${next.name}: ${next.unlockRebirths - state.totalRebirths} more rebirths`
      : `${next.name}: level ${next.unlockLevel}`
    slot.append(picture(cropIconURL(next)), element('span', 'seed-cost', needs))
    this.seedBar.append(slot)
  }

  private renderMarket(state: GameState): void {
    const items = Object.entries(state.inventory).filter(([, amount]) => amount > 0)
    const special = marketSpecial(state)
    const held = items.map(([id]) => cropDef(id)).filter((crop) => crop !== undefined)
    const rows = [...new Set([...held, ...seedsShown(state)])]
    const signature = JSON.stringify([
      items, special, rows.map((crop) => [basePrice(state, crop.id), Math.round(marketFactor(state, crop.id) * 100)]),
      BOOSTS.map(({ kind }) => [Math.ceil(boostReadyIn(state, kind)), boostCost(state, kind), boostCost(state, kind) <= state.money]),
      Math.ceil(coinBoostLeft(state)), adsOffered(),
    ])
    if (signature === this.panelSignature) return
    this.panelSignature = signature
    this.panelBody.replaceChildren()

    for (const boost of BOOSTS) this.panelBody.append(this.boostRow(state, boost))

    const specialDef = cropDef(special)
    if (specialDef) {
      const note = element('div', 'special')
      note.append(icon('ui_icon_sparkle'), element('span', '', `Today's special: ${specialDef.plural}, 50% extra`))
      this.panelBody.append(note)
    }
    for (const crop of rows) {
      const amount = state.inventory[crop.id] ?? 0
      const row = element('div', amount > 0 ? 'row' : 'row empty')
      const price = Math.round(basePrice(state, crop.id) * marketFactor(state, crop.id))
      const factor = Math.round(marketFactor(state, crop.id) * 100)
      const text = element('div', 'row-text')
      const mastery = masteryLevel(state, crop.id)
      text.append(element('strong', '', mastery > 0 ? `${crop.name} · mastery ${mastery}` : crop.name))
      text.append(element('small', '', factor < 90 ? `${coins(price)} each, down to ${factor}%: you've sold a lot` : `${coins(price)} each`))
      row.append(picture(cropIconURL(crop)), text)
      if (crop.id === special) row.classList.add('is-special')
      if (amount > 0) {
        const sell = element('button', 'small', `Sell ${coins(amount)} · ${coins(quote(state, crop.id, amount))}`)
        sell.addEventListener('click', () => this.actions.sellItem(crop.id))
        row.append(sell)
      }
      this.panelBody.append(row)
    }
  }

  /** Same size and style for both ways of getting it: the ad is an option, not the point. */
  private boostRow(state: GameState, boost: (typeof BOOSTS)[number]): HTMLElement {
    const row = element('div', 'row boost')
    const text = element('div', 'row-text')
    const left = boost.kind === 'coins' ? coinBoostLeft(state) : 0
    const waiting = boostReadyIn(state, boost.kind)
    const status = left > 0 ? `Running: ${minutes(left)} left` : waiting > 0 ? `Ready in ${minutes(waiting)}` : boost.blurb
    text.append(element('strong', '', boost.name), element('small', '', status))
    row.append(icon(boost.art), text)
    if (waiting > 0) return row
    if (adsOffered()) {
      const watch = element('button', 'small watch', '▶ Watch ad')
      watch.addEventListener('click', () => this.actions.watchBoost(boost.kind))
      row.append(watch)
    }
    const cost = boostCost(state, boost.kind)
    const pay = element('button', 'small', coins(cost))
    pay.disabled = cost > state.money
    pay.addEventListener('click', () => this.actions.buyBoost(boost.kind))
    row.append(pay)
    return row
  }

  private renderFarm(state: GameState): void {
    const upgrades = availableUpgrades(state)
    const signature = JSON.stringify(upgrades.map((item) => [item.name, item.cost, item.level <= state.level, item.cost <= state.money]))
    if (signature === this.panelSignature) return
    this.panelSignature = signature
    this.panelBody.replaceChildren()

    const training = upgrades.filter((item) => item.kind === 'training')
    const rest = upgrades.filter((item) => item.kind !== 'training')
    if (rest.length > 0) this.panelBody.append(element('h3', '', 'Build'))
    for (const upgrade of rest) this.panelBody.append(this.upgradeRow(state, upgrade))
    this.panelBody.append(element('h3', '', 'Endless upgrades'))
    for (const upgrade of training) this.panelBody.append(this.upgradeRow(state, upgrade))
  }

  private upgradeRow(state: GameState, upgrade: Upgrade): HTMLElement {
    const open = upgrade.level <= state.level
    const row = element('div', open ? 'row' : 'row empty')
    const text = element('div', 'row-text')
    const name = upgrade.kind === 'training' ? `${upgrade.name} · ${upgrade.owned}` : upgrade.name
    text.append(element('strong', '', name), element('small', '', upgrade.blurb))
    const art = upgrade.kind === 'machine' ? `prop_${upgrade.id}`
      : upgrade.kind === 'training' ? TRAINING_ICONS[upgrade.id] : UPGRADE_ICONS[upgrade.kind]
    row.append(icon(art), text)
    const button = element('button', 'small', open ? coins(upgrade.cost) : `Level ${upgrade.level}`)
    button.disabled = !open || upgrade.cost > state.money
    button.addEventListener('click', () => this.actions.buy(upgrade))
    row.append(button)
    if (upgrade.kind === 'training') {
      const max = element('button', 'small max', 'Max')
      max.disabled = button.disabled
      max.addEventListener('click', () => this.actions.buyMax(upgrade.id))
      row.append(max)
    }
    return row
  }

  private resetButton(reset: Reset, label: string, enabled: boolean, onConfirm: () => void): HTMLElement {
    const confirming = this.confirming === reset
    const button = element('button', confirming ? 'reset confirm' : 'reset', confirming ? 'Sure? Click again to start over' : label)
    button.disabled = !enabled
    button.addEventListener('click', () => {
      if (this.confirming === reset) {
        this.confirming = null
        onConfirm()
        return
      }
      this.confirming = reset
      this.panelSignature = ''
      window.clearTimeout(this.confirmTimer)
      this.confirmTimer = window.setTimeout(() => {
        this.confirming = null
        this.panelSignature = ''
      }, 4000)
    })
    return button
  }

  private renderRebirth(state: GameState): void {
    const needed = rebirthRequirement(state)
    const ready = canRebirth(state)
    const shown = Math.floor(Math.min(1, state.runCoins / needed) * 100)
    const signature = JSON.stringify([
      shown, ready, goldenSeedsFor(state), state.goldenSeeds, state.perks, state.rebirths, state.ascensions, this.confirming,
      canBigBang(state), state.universes,
    ])
    if (signature === this.panelSignature) return
    this.panelSignature = signature
    this.panelBody.replaceChildren()

    const card = element('div', 'reset-card')
    card.append(element('strong', '', `Rebirth ${state.rebirths + 1}`))
    card.append(element('small', '', `New farm, but every crop is worth ×${BALANCE.rebirthValue} more for good. Levels, mastery and trophies stay.`))
    const bar = element('div', 'reset-bar')
    const fill = element('i')
    fill.style.width = `${shown}%`
    bar.append(fill)
    card.append(bar, element('small', '', `${coins(state.runCoins)} / ${coins(needed)} earned on this farm`))
    card.append(this.resetButton('rebirth', ready ? `Rebirth for ${coins(goldenSeedsFor(state))} Golden Seeds` : 'Not yet', ready, this.actions.rebirth))
    this.panelBody.append(card)

    const seeds = element('h3', 'seeds-heading')
    seeds.append(icon('ui_icon_seeds'), element('span', '', `${coins(state.goldenSeeds)} Golden Seeds`))
    this.panelBody.append(seeds)
    for (const perk of PERKS) this.panelBody.append(this.perkRow(state, perk))

    if (state.rebirths >= 5 || state.ascensions > 0) {
      const ascend = element('div', 'reset-card ascend')
      ascend.append(element('strong', '', `Ascend ${state.ascensions + 1}`))
      ascend.append(element('small', '', `Gives up your rebirths, Golden Seeds and endless perks for stars. Each star doubles every crop, for good. You have ${state.stars}.`))
      const possible = canAscend(state)
      ascend.append(element('small', '', possible ? `Worth ${starsFor(state)} stars now` : `${state.rebirths} of ${BALANCE.rebirthsToAscend} rebirths`))
      ascend.append(this.resetButton('ascend', possible ? 'Ascend' : 'Not yet', possible, this.actions.ascend))
      this.panelBody.append(ascend)
    }
    if (state.ascensions > 0 || state.universes > 0) {
      const bang = element('div', 'reset-card bang')
      bang.append(element('strong', '', `Big Bang ${state.universes + 1}`))
      bang.append(element('small', '', `Earn ${coins(BALANCE.bigBangCoins)} on one farm to start a new universe. Everything resets but your levels, mastery and trophies, and every crop is worth ×${coins(BALANCE.universeValue)} more.`))
      bang.append(this.resetButton('bigBang', canBigBang(state) ? 'Big Bang' : 'Not yet', canBigBang(state), this.actions.bigBang))
      this.panelBody.append(bang)
    }

    this.panelBody.append(element('h3', '', 'Your records'))
    const found = MUTATIONS.map((mutation) => `${state.counters[`mutation:${mutation.id}`] ?? 0} ${mutation.name}`).reverse().join(', ')
    const records = [
      `${coins(state.lifetimeCoins)} coins earned in all`,
      `${trophies(state)} trophies, ${state.totalRebirths} rebirths, ${state.ascensions} ascensions, ${state.universes} big bangs`,
      `Rare crops: ${found}`,
      `Earns for ${offlineHours(state)} hours while you're away`,
    ]
    for (const record of records) this.panelBody.append(element('p', 'record', record))
  }

  private perkRow(state: GameState, perk: PerkDef): HTMLElement {
    const level = perkLevel(state, perk.id)
    const maxed = perk.maxLevel !== null && level >= perk.maxLevel
    const row = element('div', 'row')
    const text = element('div', 'row-text')
    text.append(element('strong', '', level > 0 ? `${perk.name} · ${level}` : perk.name), element('small', '', perk.blurb))
    row.append(text)
    const cost = perkCost(perk, level)
    const button = element('button', 'small gold', maxed ? 'Done' : coins(cost))
    button.disabled = maxed || cost > state.goldenSeeds
    button.addEventListener('click', () => this.actions.buyPerk(perk))
    row.append(button)
    return row
  }

  toast(message: string): void {
    const toast = element('div', 'toast', message)
    this.toasts.replaceChildren(toast)
    window.setTimeout(() => toast.remove(), 2400)
  }

  showBanner(title: string, detail: string): void {
    const banner = element('div', 'banner-card')
    banner.append(element('strong', '', title), element('span', '', detail))
    this.banner.replaceChildren(banner)
    window.setTimeout(() => banner.remove(), 3000)
  }

  /** A little "+3" rising from where something happened. */
  floater(x: number, y: number, text: string, url: string, rare = false): void {
    const node = element('div', rare ? 'floater rare' : 'floater')
    node.style.left = `${x}px`
    node.style.top = `${y}px`
    node.append(picture(url), element('span', '', text))
    this.root.append(node)
    node.addEventListener('animationend', () => node.remove())
  }

  flash(kind: 'rebirth' | 'ascend' | 'bigBang'): void {
    const flash = element('div', `flash ${kind}`)
    this.root.append(flash)
    flash.addEventListener('animationend', () => flash.remove())
  }

  /** Blocks the game while an ad is requested or playing. */
  setAdWaiting(waiting: boolean): void {
    this.adWait.hidden = !waiting
  }

  /** The welcome-back card, when there's an ad to offer. The other choice is the same size. */
  showWelcome(earned: number, onDouble: () => void, onKeep: () => void): void {
    const card = element('div', 'welcome')
    card.append(element('strong', '', 'Welcome back'), element('span', '', `Your farm earned ${coins(earned)} coins while you were away.`))
    const buttons = element('div', 'welcome-buttons')
    const keep = element('button', 'small', 'Keep it')
    const double = element('button', 'small watch', '▶ Watch ad: double it')
    const close = (then: () => void): void => {
      card.remove()
      then()
    }
    keep.addEventListener('click', () => close(onKeep))
    double.addEventListener('click', () => close(onDouble))
    buttons.append(keep, double)
    card.append(buttons)
    this.root.append(card)
  }

  nudgeSell(): void {
    this.sellButton.classList.remove('nudge')
    void this.sellButton.offsetWidth
    this.sellButton.classList.add('nudge')
  }
}

/** The lines a refused job gets. Plain enough to read while playing. */
export function failureMessage(failure: string, seed: string): string | null {
  switch (failure) {
    case 'noMoney': return `Not enough coins for ${cropDef(seed)?.name.toLowerCase() ?? 'that'} seeds.`
    case 'storageFull': return 'Storage is full. Sell something first.'
    case 'locked': return 'You need a higher level for that.'
    default: return null
  }
}

export function hoverText(ripeInSeconds: number, name: string, wet: boolean): string {
  if (ripeInSeconds <= 0) return `${name}: ripe`
  return `${name}: ripe in ${Math.ceil(ripeInSeconds)}s${wet ? '' : ', faster if watered'}`
}
