import { boostCost, boostReadyIn, coinBoostLeft, type BoostKind } from '../core/boosts'
import { BALANCE, cropDef, MUTATIONS, PERKS, xpToNextLevel, type CropDef, type PerkDef } from '../core/content'
import { availableUpgrades, type Upgrade } from '../core/estate'
import { currentGoal } from '../core/goals'
import { basePrice, marketFactor, marketSpecial, quote, sellAllQuote } from '../core/market'
import { formatNumber } from '../core/numbers'
import { REAL_SECONDS_PER_DAY } from '../core/pace'
import { cropsFor, growthSpeed, lockedCrops, masteryLevel, trophies, valueMultiplier } from '../core/progress'
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

export type Panel = 'seeds' | 'market' | 'farm' | 'rebirth'

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

/** The Market lists this many crops you aren't holding, or it would grow without end. */
const MARKET_ROWS = 10

/** The Seeds list shows this many crops still locked, so there's always something to work toward. */
const LOCKED_SHOWN = 3

const TABS: { panel: Panel; label: string }[] = [
  { panel: 'seeds', label: 'Seeds' },
  { panel: 'market', label: 'Market' },
  { panel: 'farm', label: 'Farm' },
  { panel: 'rebirth', label: 'Rebirth' },
]

/** The Farm menu, in the order you'd look for things. */
const FARM_SECTIONS: { title: string; kinds: Upgrade['kind'][] }[] = [
  { title: 'Land', kinds: ['parcel'] },
  { title: 'Buildings', kinds: ['storage', 'farmhouse', 'windmill'] },
  { title: 'Helpers and machines', kinds: ['worker', 'machine', 'automation'] },
  { title: 'Endless upgrades', kinds: ['training'] },
]

/** Rebirth stays out of the way until there's a reason to look at it. */
function rebirthOpen(state: GameState): boolean {
  return state.level >= 5 || state.totalRebirths > 0
}

function seconds(sim: number): string {
  return `${Math.max(1, Math.round((sim / 1440) * REAL_SECONDS_PER_DAY))}s`
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
  private readonly seedButton = element('button', 'seed-pick')
  private readonly seedIcon = element('img', 'icon')
  private readonly seedName = element('strong')
  private readonly seedNote = element('small')
  private readonly arneCount = element('small', 'goal-count')
  private readonly multiplierChip = element('div', 'chip multiplier')
  private readonly sellButton = element('button', 'action sell')
  private readonly sellLabel = element('span', 'action-label', 'Sell')
  private readonly marketButton = element('button', 'action')
  private readonly farmButton = element('button', 'action')
  private readonly farmBadge = element('b', 'badge')
  private readonly soundButton = element('button', 'chip-button')
  private readonly panel = element('section', 'panel')
  private readonly panelBody = element('div', 'panel-body')
  private readonly tabs = element('nav', 'tabs')
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

    this.multiplierChip.title = 'Everything multiplying your crop prices'
    this.multiplierChip.append(icon('ui_icon_sparkle'), this.multiplier)
    stats.append(money, level, storage, this.multiplierChip)

    this.arne.append(icon('ui_portrait_mentor', 'portrait'))
    const words = element('div', 'words')
    this.arneBar.append(this.arneFill)
    words.append(this.arneText, this.arneBar, this.arneCount)
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

    const seedWords = element('span', 'stack')
    seedWords.append(this.seedName, this.seedNote)
    this.seedIcon.alt = ''
    this.seedIcon.draggable = false
    this.seedButton.append(this.seedIcon, seedWords)
    this.seedButton.addEventListener('click', () => this.actions.togglePanel('seeds'))

    const buttons = element('div', 'actions')
    buttons.append(this.sellButton, this.marketButton, this.farmButton, this.rebirthButton)
    bottom.append(this.seedButton, buttons)
    this.root.append(bottom)
  }

  private buildPanel(): void {
    const header = element('header')
    const close = element('button', 'close')
    close.append(icon('ui_icon_close'))
    close.setAttribute('aria-label', 'Close')
    close.addEventListener('click', this.actions.closePanel)
    for (const { panel, label } of TABS) {
      const tab = element('button', 'tab', label)
      tab.dataset.panel = panel
      tab.addEventListener('click', () => this.actions.togglePanel(panel))
      this.tabs.append(tab)
    }
    header.append(this.tabs, close)
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
    for (const tab of this.tabs.querySelectorAll<HTMLElement>('.tab')) tab.classList.toggle('open', tab.dataset.panel === panel)
  }

  /** Runs every frame, so it only touches what changed. */
  update(state: GameState, seed: string, placing: string | null): void {
    setText(this.money, coins(state.money))
    setText(this.income, state.income >= 1 ? `+${coins(state.income)}/s` : '')
    const multiplier = valueMultiplier(state)
    setText(this.multiplier, `×${coins(multiplier)}`)
    this.multiplierChip.hidden = multiplier < 2
    setText(this.level, `Level ${state.level}`)
    const needed = xpToNextLevel(state.level)
    this.xpFill.style.width = `${Math.min(100, (state.xp / needed) * 100)}%`

    const used = storageUsed(state)
    const capacity = storageCapacity(state)
    setText(this.storage, `${coins(used)} / ${coins(capacity)}`)
    this.storage.classList.toggle('full', used >= capacity)

    const goal = currentGoal(state)
    setText(this.arneText, goal.text)
    // A goal to buy something shows the coins saved toward it.
    const cost = goal.saveFor?.(state) ?? 0
    const have = cost > 0 ? state.money : goal.progress(state)
    const target = cost > 0 ? cost : goal.needed
    this.arneBar.hidden = target <= 1
    this.arneFill.style.width = `${Math.min(1, have / target) * 100}%`
    setText(this.arneCount, target > 1 ? `${coins(Math.min(have, target))} / ${coins(target)}${cost > 0 ? ' coins' : ''}` : '')

    const quoted = sellAllQuote(state)
    setText(this.sellLabel, quoted > 0 ? `Sell ${coins(quoted)}` : 'Sell')
    this.sellButton.disabled = quoted === 0
    this.sellButton.classList.toggle('pulse', goal.target === 'sell' && quoted > 0)
    this.marketButton.classList.toggle('pulse', goal.target === 'market' && this.panelOpen === null)

    const ready = availableUpgrades(state).filter((item) => item.level <= state.level && item.cost <= state.money).length
    setText(this.farmBadge, ready > 0 ? String(ready) : '')
    this.farmBadge.hidden = ready === 0
    this.farmButton.classList.toggle('pulse', goal.target === 'farm' && this.panelOpen === null)
    this.rebirthButton.classList.toggle('pulse', this.panelOpen === null && (canRebirth(state) || canAscend(state) || canBigBang(state)))
    const hasRebirth = rebirthOpen(state)
    this.rebirthButton.hidden = !hasRebirth
    this.tabs.querySelector<HTMLElement>('[data-panel="rebirth"]')!.hidden = !hasRebirth

    setText(this.soundButton, isMuted() ? 'Sound off' : 'Sound on')

    this.renderSeedButton(state, seed, goal.target === 'seeds' && this.panelOpen === null)
    if (!this.panelHeld) {
      if (this.panelOpen === 'seeds') this.renderSeeds(state, seed)
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

  /** What's being planted, always in view. The choosing happens in the Seeds tab. */
  private renderSeedButton(state: GameState, seed: string, pulse: boolean): void {
    this.seedButton.classList.toggle('pulse', pulse)
    const signature = [seed, state.level].join('|')
    if (signature === this.seedSignature) return
    this.seedSignature = signature
    const crop = cropDef(seed)
    if (!crop) return
    this.seedIcon.src = cropIconURL(crop)
    setText(this.seedName, `Planting ${crop.name}`)
    setText(this.seedNote, `${coins(crop.seedCost)} coins each. Click to change`)
  }

  private cropNote(state: GameState, crop: CropDef): string {
    const items = (crop.yield[0] + crop.yield[1]) / 2
    const plot = items * basePrice(state, crop.id)
    const regrows = crop.regrowSeconds === undefined ? '' : ', keeps growing back'
    return `Seed ${coins(crop.seedCost)}. Ripe in ${seconds(crop.growthSeconds / growthSpeed(state))}. Sells for about ${coins(plot)} a plot${regrows}`
  }

  /** Everything you can grow, cheapest first, then what's coming. */
  private renderSeeds(state: GameState, seed: string): void {
    const open = [...cropsFor(state)].sort((a, b) => a.seedCost - b.seedCost)
    const locked = lockedCrops(state, LOCKED_SHOWN)
    const signature = JSON.stringify([seed, state.level, state.totalRebirths, open.map((crop) => basePrice(state, crop.id))])
    if (signature === this.panelSignature) return
    this.panelSignature = signature
    this.panelBody.replaceChildren()

    this.panelBody.append(element('p', 'intro', 'Pick a crop, then click your soil to plant it. You pay for each seed as you plant.'))
    this.panelBody.append(element('h3', '', 'Your seeds'))
    for (const crop of open) {
      const chosen = crop.id === seed
      const row = element('div', chosen ? 'row is-chosen' : 'row')
      const text = element('div', 'row-text')
      text.append(element('strong', '', crop.name), element('small', '', this.cropNote(state, crop)))
      row.append(picture(cropIconURL(crop)), text)
      const button = element('button', 'small', chosen ? 'Planting' : 'Pick')
      button.disabled = chosen
      button.addEventListener('click', () => this.actions.selectSeed(crop.id))
      row.append(button)
      this.panelBody.append(row)
    }
    this.panelBody.append(element('h3', '', 'Coming up'))
    for (const crop of locked) {
      const row = element('div', 'row empty')
      const text = element('div', 'row-text')
      const needs = crop.unlockRebirths > state.totalRebirths
        ? `${crop.unlockRebirths - state.totalRebirths} more rebirths` : `Level ${crop.unlockLevel}`
      text.append(element('strong', '', crop.name), element('small', '', needs))
      row.append(picture(cropIconURL(crop)), text)
      this.panelBody.append(row)
    }
  }

  private renderMarket(state: GameState): void {
    const items = Object.entries(state.inventory).filter(([, amount]) => amount > 0)
    const special = marketSpecial(state)
    const held = items.map(([id]) => cropDef(id)).filter((crop) => crop !== undefined)
    const others = cropsFor(state).filter((crop) => !held.includes(crop)).slice(-MARKET_ROWS)
    const rows = [...held, ...others]
    const signature = JSON.stringify([
      items, special, rows.map((crop) => [basePrice(state, crop.id), Math.round(marketFactor(state, crop.id) * 100)]),
      BOOSTS.map(({ kind }) => [Math.ceil(boostReadyIn(state, kind)), boostCost(state, kind)]), coins(state.money),
      Math.ceil(coinBoostLeft(state)), adsOffered(),
    ])
    if (signature === this.panelSignature) return
    this.panelSignature = signature
    this.panelBody.replaceChildren()

    this.panelBody.append(element('h3', '', 'Boosts'))
    for (const boost of BOOSTS) this.panelBody.append(this.boostRow(state, boost))

    this.panelBody.append(element('h3', '', 'Sell crops'))
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
    row.append(this.priceButton(state.money, cost, () => this.actions.buyBoost(boost.kind)))
    return row
  }

  /** A buy button. Until you can afford it, it shows what you've saved toward the price. */
  private priceButton(have: number, cost: number, onBuy: () => void): HTMLElement {
    if (have >= cost) {
      const button = element('button', 'small', coins(cost))
      button.addEventListener('click', onBuy)
      return button
    }
    const saving = element('div', 'small saving')
    const fill = element('i')
    fill.style.width = `${(have / cost) * 100}%`
    saving.append(fill, element('span', '', `${coins(have)} / ${coins(cost)}`))
    return saving
  }

  private renderFarm(state: GameState): void {
    const upgrades = availableUpgrades(state)
    const signature = JSON.stringify([coins(state.money), upgrades.map((item) => [item.name, item.cost, item.level <= state.level])])
    if (signature === this.panelSignature) return
    this.panelSignature = signature
    this.panelBody.replaceChildren()

    for (const section of FARM_SECTIONS) {
      const rows = upgrades.filter((item) => section.kinds.includes(item.kind))
      if (rows.length === 0) continue
      this.panelBody.append(element('h3', '', section.title))
      for (const upgrade of rows) this.panelBody.append(this.upgradeRow(state, upgrade))
    }
  }

  private upgradeRow(state: GameState, upgrade: Upgrade): HTMLElement {
    const open = upgrade.level <= state.level
    const row = element('div', open ? 'row' : 'row empty')
    const text = element('div', 'row-text')
    const name = upgrade.kind === 'training' ? `${upgrade.name} · level ${upgrade.owned}` : upgrade.name
    text.append(element('strong', '', name), element('small', '', upgrade.blurb))
    const art = upgrade.kind === 'machine' ? `prop_${upgrade.id}`
      : upgrade.kind === 'training' ? TRAINING_ICONS[upgrade.id] : UPGRADE_ICONS[upgrade.kind]
    row.append(icon(art), text)
    if (!open) {
      text.append(element('small', '', `${coins(upgrade.cost)} coins`))
      row.append(element('div', 'small saving', `Level ${upgrade.level}`))
      return row
    }
    row.append(this.priceButton(state.money, upgrade.cost, () => this.actions.buy(upgrade)))
    if (upgrade.kind === 'training' && upgrade.cost <= state.money) {
      const max = element('button', 'small quiet', 'Max')
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
      const ascend = element('div', 'reset-card')
      ascend.append(element('strong', '', `Ascend ${state.ascensions + 1}`))
      ascend.append(element('small', '', `Gives up your rebirths, Golden Seeds and endless perks for stars. Each star doubles every crop, for good. You have ${state.stars}.`))
      const possible = canAscend(state)
      ascend.append(element('small', '', possible ? `Worth ${starsFor(state)} stars now` : `${state.rebirths} of ${BALANCE.rebirthsToAscend} rebirths`))
      ascend.append(this.resetButton('ascend', possible ? 'Ascend' : 'Not yet', possible, this.actions.ascend))
      this.panelBody.append(ascend)
    }
    if (state.ascensions > 0 || state.universes > 0) {
      const bang = element('div', 'reset-card')
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
    if (maxed) {
      row.append(element('div', 'small saving', 'Done'))
      return row
    }
    row.append(this.priceButton(state.goldenSeeds, cost, () => this.actions.buyPerk(perk)))
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
