import { cropDef, machineDef, PARCELS, stageFor, type CropDef, type ParcelDef } from '../core/content'
import type { FarmActionKind } from '../core/farming'
import type { GoalTarget } from '../core/goals'
import { isReady, isWet, parcelAt, plotAt, stableHash, tileKey, type GameState } from '../core/state'
import { cropSprite, RARE_GLOW, sprite } from './assets'

const TILE = 32

/** The part of the world that must always fit on screen. Wider windows see more valley around it. */
const CONTENT_WIDTH = 22 * TILE
const CONTENT_HEIGHT = 13 * TILE

/** Space the HUD takes along the top and bottom of the window, in CSS pixels. */
const HUD_TOP = 58
const HUD_BOTTOM = 92

const BACKGROUND = { x: -848, y: -640, width: 2400, height: 1700 }

/** Where things stand, in tiles (foot points). */
const PLACES = {
  farmhouse: { x: 3.6, y: 4.8 },
  well: { x: 6.9, y: 4.6 },
  shed: { x: 9.2, y: 4.8 },
  silos: [{ x: 11.7, y: 4.75 }, { x: 13.3, y: 4.6 }],
  windmill: { x: 16.2, y: 4.5 },
  market: { x: 19.9, y: 4.75 },
  truck: { x: 16.9, y: 5.25 },
}

/** Fraction of a sprite's height from its bottom edge to the foot point (docs/ASSETS.md). */
const ANCHOR = { building: 0.06, crop: 0.1, tree: 0.06, character: 0.05, nature: 0.1, sign: 0.05, sprinkler: 0.2, truck: 0.4, well: 0.1 }

type Facing = 'down' | 'up' | 'side'
type Tool = 'hoe' | 'can' | 'hands'

const TRUCK_TRIP_MS = 3200

const TOOL_FOR_ACTION: Record<FarmActionKind, Tool> = { plow: 'hoe', plant: 'hands', water: 'can', harvest: 'hands' }

/** Someone walking the fields: the farmer, or a farmhand. Purely for show; the rules never wait for them. */
class Actor {
  x: number
  y: number
  targetX: number
  targetY: number
  facing: Facing = 'down'
  flip = false
  tool: Tool | null = null
  toolUntil = 0

  constructor(readonly who: string, x: number, y: number, readonly speed: number) {
    this.x = this.targetX = x
    this.y = this.targetY = y
  }

  goTo(x: number, y: number, kind: FarmActionKind, now: number): void {
    this.targetX = x + 0.5
    this.targetY = y + 0.75
    this.tool = TOOL_FOR_ACTION[kind]
    this.toolUntil = now + 350
  }

  update(dt: number): void {
    const dx = this.targetX - this.x
    const dy = this.targetY - this.y
    const distance = Math.hypot(dx, dy)
    if (distance < 0.05) return
    const travel = Math.min(distance, this.speed * dt)
    this.x += (dx / distance) * travel
    this.y += (dy / distance) * travel
    if (Math.abs(dx) > Math.abs(dy)) {
      this.facing = 'side'
      this.flip = dx > 0
    } else {
      this.facing = dy > 0 ? 'down' : 'up'
      this.flip = false
    }
  }

  frame(now: number): string {
    const beat = Math.floor(now / 130) % 2 === 0 ? 1 : 2
    const walking = Math.hypot(this.targetX - this.x, this.targetY - this.y) > 0.05
    // Only the farmer has a hoe drawn; farmhands plow by hand.
    const tool = this.tool === 'hoe' && this.who !== 'farmer' ? 'hands' : this.tool
    const pose = walking ? `walk${beat}` : tool && now < this.toolUntil ? `${tool}${beat}` : 'idle'
    return `character_${this.who}_${this.facing}_${pose}`
  }
}

interface Particle {
  name: string
  x: number
  y: number
  vx: number
  vy: number
  gravity: number
  age: number
  life: number
}

interface Drawable {
  y: number
  draw: () => void
}

export interface ViewFrame {
  hover: { x: number; y: number } | null
  placing: string | null
  guide: GoalTarget
}

export class WorldView {
  private readonly context: CanvasRenderingContext2D
  private readonly low = document.createElement('canvas')
  private readonly lowContext: CanvasRenderingContext2D
  /** Nearest-neighbour blow-up, then a smooth fit: pixels stay even at fractional scales. */
  private readonly mid = document.createElement('canvas')
  private readonly midContext: CanvasRenderingContext2D
  private readonly background = document.createElement('canvas')
  private readonly parcelBits = new Map<string, { name: string; x: number; y: number; anchor: number }[]>()
  private readonly particles: Particle[] = []
  private readonly farmer = new Actor('farmer', 8.2, 5.3, 9)
  private readonly hands: Actor[] = []
  private scale = 1
  private wholeScale = 1
  private dpr = 1
  private cameraX = 0
  private cameraY = 0
  private lastDraw = performance.now()
  private nextSparkle = 0
  private truckLeft = -Infinity

  constructor(private readonly canvas: HTMLCanvasElement) {
    this.context = canvas.getContext('2d', { alpha: false })!
    this.lowContext = this.low.getContext('2d', { alpha: false })!
    this.midContext = this.mid.getContext('2d', { alpha: false })!
    this.paintBackground()
    this.prepareParcels()
    this.resize()
  }

  resize(): void {
    const bounds = this.canvas.getBoundingClientRect()
    this.dpr = Math.min(window.devicePixelRatio || 1, 3)
    const width = Math.max(1, Math.round(bounds.width * this.dpr))
    const height = Math.max(1, Math.round(bounds.height * this.dpr))
    this.canvas.width = width
    this.canvas.height = height

    const compact = bounds.height < 480
    const hudTop = (compact ? 44 : HUD_TOP) * this.dpr
    const hudBottom = (compact ? 66 : HUD_BOTTOM) * this.dpr
    let scale = Math.min(width / CONTENT_WIDTH, (height - hudTop - hudBottom) / CONTENT_HEIGHT)
    scale = Math.max(0.5, scale)
    if (Math.abs(scale - Math.round(scale)) < 0.06) scale = Math.round(scale)
    this.scale = scale
    this.wholeScale = Math.max(1, Math.ceil(scale))

    this.low.width = Math.ceil(width / scale)
    this.low.height = Math.ceil(height / scale)
    this.mid.width = this.low.width * this.wholeScale
    this.mid.height = this.low.height * this.wholeScale
    this.lowContext.imageSmoothingEnabled = false
    this.midContext.imageSmoothingEnabled = false

    this.cameraX = Math.round((CONTENT_WIDTH - this.low.width) / 2)
    const fieldCenter = (hudTop + (height - hudBottom)) / 2
    this.cameraY = Math.round(CONTENT_HEIGHT / 2 - fieldCenter / scale)
  }

  /** The tile under a point in the window. */
  tileAt(clientX: number, clientY: number): { x: number; y: number } {
    const bounds = this.canvas.getBoundingClientRect()
    const worldX = ((clientX - bounds.left) * this.dpr) / this.scale + this.cameraX
    const worldY = ((clientY - bounds.top) * this.dpr) / this.scale + this.cameraY
    return { x: Math.floor(worldX / TILE), y: Math.floor(worldY / TILE) }
  }

  /** Where a tile's center sits in the window, for HUD pop-ups. */
  screenPoint(x: number, y: number): { x: number; y: number } {
    const bounds = this.canvas.getBoundingClientRect()
    return {
      x: bounds.left + (((x + 0.5) * TILE - this.cameraX) * this.scale) / this.dpr,
      y: bounds.top + (((y + 0.2) * TILE - this.cameraY) * this.scale) / this.dpr,
    }
  }

  // MARK: Reactions

  farmerActs(x: number, y: number, kind: FarmActionKind): void {
    this.farmer.goTo(x, y, kind, performance.now())
    this.burst(x, y, kind)
  }

  workerActs(index: number, x: number, y: number, kind: FarmActionKind): void {
    this.hands[index]?.goTo(x, y, kind, performance.now())
    this.burst(x, y, kind)
  }

  private burst(x: number, y: number, kind: FarmActionKind): void {
    const cx = x + 0.5
    const cy = y + 0.5
    if (kind === 'plow') {
      for (let i = 0; i < 3; i++) this.spawn('fx_dust_puff', cx, cy + 0.2, (Math.random() - 0.5) * 1.4, -0.6 - Math.random(), 0, 0.4)
    } else if (kind === 'water') {
      for (let i = 0; i < 3; i++) this.spawn('fx_water_drops', cx + (Math.random() - 0.5) * 0.6, cy - 0.3, 0, 0.6, 3, 0.4)
    } else if (kind === 'harvest') {
      this.spawn('fx_harvest_pop', cx, cy - 0.2, 0, -1.5, 0, 0.35)
      for (let i = 0; i < 3; i++) this.spawn('fx_sparkle', cx, cy - 0.2, (Math.random() - 0.5) * 3.5, -2 - Math.random() * 2, 7, 0.5)
    }
  }

  celebrate(): void {
    for (let i = 0; i < 26; i++) {
      this.spawn('fx_sparkle', this.farmer.x, this.farmer.y - 1, (Math.random() - 0.5) * 7, -3 - Math.random() * 4, 6, 0.9)
    }
  }

  sparkleAt(x: number, y: number): void {
    for (let i = 0; i < 18; i++) {
      this.spawn('fx_sparkle', x, y, (Math.random() - 0.5) * 6, -2 - Math.random() * 4, 6, 0.8)
    }
  }

  /** The truck runs its load to the stall and comes back. */
  sendTruck(): void {
    if (performance.now() - this.truckLeft > TRUCK_TRIP_MS) this.truckLeft = performance.now()
  }

  private paintCrop(context: CanvasRenderingContext2D, def: CropDef, stage: number, mutation: string | undefined, x: number, y: number, now: number): void {
    const glow = mutation ? RARE_GLOW[mutation] : undefined
    if (glow) {
      context.fillStyle = `rgba(${glow}, ${0.35 + Math.sin(now / 240) * 0.15})`
      context.beginPath()
      context.ellipse(x, y - 8, 14, 11, 0, 0, Math.PI * 2)
      context.fill()
    }
    const image = cropSprite(def, stage, mutation, now)
    context.drawImage(image, Math.round(x - image.width / 2), Math.round(y - image.height * (1 - ANCHOR.crop)))
  }

  private spawn(name: string, x: number, y: number, vx: number, vy: number, gravity: number, life: number): void {
    if (this.particles.length < 220) this.particles.push({ name, x, y, vx, vy, gravity, age: 0, life })
  }

  private syncHands(count: number): void {
    while (this.hands.length < count) {
      this.hands.push(new Actor(`worker${(this.hands.length % 3) + 1}`, 8.2, 5.3, 7))
    }
    this.hands.length = count
  }

  // MARK: Painting

  private paintBackground(): void {
    this.background.width = BACKGROUND.width
    this.background.height = BACKGROUND.height
    const context = this.background.getContext('2d')!
    context.imageSmoothingEnabled = false
    context.fillStyle = context.createPattern(sprite('terrain_grass'), 'repeat')!
    context.fillRect(0, 0, BACKGROUND.width, BACKGROUND.height)
    context.translate(-BACKGROUND.x, -BACKGROUND.y)

    // The farm lane, as columns of dirt with a wandering edge.
    const dirt = sprite('terrain_dirt')
    for (let x = 32; x < 21.4 * TILE; x++) {
      const top = 157 + Math.round(Math.sin(x / 17) * 1.5 + Math.sin(x / 7.3) * 1.2)
      const bottom = 180 + Math.round(Math.sin(x / 13 + 2) * 1.5 + Math.sin(x / 5.9) * 1.2)
      context.drawImage(dirt, x % dirt.width, top, 1, bottom - top, x, top, 1, bottom - top)
    }

    let seed = 7
    const random = (): number => {
      seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0
      return seed / 4294967296
    }
    const bits: { name: string; x: number; y: number; anchor: number; shadow?: number }[] = []
    const inFarm = (x: number, y: number): boolean => x > -24 && x < CONTENT_WIDTH + 24 && y > -8 && y < CONTENT_HEIGHT + 48

    // A dark wall of pines behind the farm, as on the title screen.
    for (let y = -560; y < -8; y += 22) {
      for (let x = BACKGROUND.x; x < BACKGROUND.x + BACKGROUND.width; x += 34) {
        if (random() < 0.8) bits.push({ name: 'tree_pine_summer', x: x + random() * 26, y: y + random() * 14, anchor: ANCHOR.tree })
      }
    }
    const broadleaf = ['tree_oak_summer', 'tree_maple_summer', 'tree_birch_summer', 'tree_apple_summer', 'tree_pine_summer']
    for (let i = 0; i < 130; i++) {
      const x = BACKGROUND.x + random() * BACKGROUND.width
      const y = random() * 900
      if (!inFarm(x, y)) bits.push({ name: broadleaf[Math.floor(random() * broadleaf.length)], x, y, anchor: ANCHOR.tree, shadow: 3 })
    }
    const small = ['nature_bush_a', 'nature_bush_b', 'nature_rock_small', 'nature_grass_tuft_a', 'nature_grass_tuft_b',
      'nature_flowers_yellow', 'nature_flowers_white', 'nature_flowers_purple']
    for (let i = 0; i < 420; i++) {
      const x = BACKGROUND.x + random() * BACKGROUND.width
      const y = 8 + random() * 1000
      const clearOfLane = y < 150 || y > 190
      const clearOfFields = !PARCELS.some((p) => x > (p.minX - 0.6) * TILE && x < (p.maxX + 1.6) * TILE && y > (p.minY - 0.6) * TILE && y < (p.maxY + 1.4) * TILE)
      const clearOfBuildings = y > 170 || x < -16 || x > CONTENT_WIDTH
      if (clearOfLane && clearOfFields && clearOfBuildings) {
        bits.push({ name: small[Math.floor(random() * small.length)], x, y, anchor: ANCHOR.nature })
      }
    }
    bits.sort((a, b) => a.y - b.y)
    for (const bit of bits) {
      if (bit.shadow) this.paintShadow(context, bit.x, bit.y, bit.shadow)
      this.paint(context, bit.name, bit.x, bit.y, bit.anchor)
    }
  }

  private paintShadow(context: CanvasRenderingContext2D, x: number, y: number, tiles: number): void {
    const width = tiles * TILE * 0.7
    context.globalAlpha = 0.3
    context.drawImage(sprite('fx_shadow_soft'), Math.round(x - width / 2), Math.round(y - width / 4), Math.round(width), Math.round(width / 2))
    context.globalAlpha = 1
  }

  private paint(context: CanvasRenderingContext2D, name: string, x: number, y: number, anchor: number, flip = false): void {
    const image = sprite(name)
    const left = Math.round(x - image.width / 2)
    const top = Math.round(y - image.height * (1 - anchor))
    if (flip) {
      context.save()
      context.translate(left + image.width, top)
      context.scale(-1, 1)
      context.drawImage(image, 0, 0)
      context.restore()
    } else {
      context.drawImage(image, left, top)
    }
  }

  /** Scruffy ground for land you don't own yet. */
  private prepareParcels(): void {
    const names = ['nature_grass_tuft_a', 'nature_grass_tuft_b', 'nature_bush_a', 'nature_rock_small', 'nature_grass_tuft_a', 'nature_flowers_yellow']
    for (const parcel of PARCELS) {
      const bits: { name: string; x: number; y: number; anchor: number }[] = []
      for (let i = 0; i < 14; i++) {
        const hash = stableHash(`${parcel.id}:${i}`)
        bits.push({
          name: names[hash % names.length],
          x: (parcel.minX + ((hash >>> 8) % 500) / 100) * TILE,
          y: (parcel.minY + 0.4 + ((hash >>> 18) % 280) / 100) * TILE,
          anchor: ANCHOR.nature,
        })
      }
      this.parcelBits.set(parcel.id, bits.sort((a, b) => a.y - b.y))
    }
  }

  private paintField(context: CanvasRenderingContext2D, state: GameState, parcel: ParcelDef): void {
    const owned = state.ownedParcels.includes(parcel.id)
    const left = parcel.minX * TILE
    const top = parcel.minY * TILE
    const width = (parcel.maxX - parcel.minX + 1) * TILE
    const height = (parcel.maxY - parcel.minY + 1) * TILE
    if (!owned) {
      for (const bit of this.parcelBits.get(parcel.id) ?? []) this.paint(context, bit.name, bit.x, bit.y, bit.anchor)
      return
    }
    context.fillStyle = 'rgba(70, 50, 20, 0.24)'
    context.fillRect(left, top, width, height)
    context.strokeStyle = 'rgba(70, 45, 15, 0.5)'
    context.lineWidth = 1
    context.strokeRect(left + 0.5, top + 0.5, width - 1, height - 1)
  }

  private paintSoil(context: CanvasRenderingContext2D, state: GameState): void {
    const variants = ['', '_2', '_3']
    for (const plot of Object.values(state.plots)) {
      const wet = isWet(plot, state.worldTime)
      const variant = variants[stableHash(tileKey(plot.x, plot.y)) % 3]
      context.drawImage(sprite(`field_soil_${wet ? 'watered' : 'plowed'}${variant}`), plot.x * TILE, plot.y * TILE)
    }
    const sides: [string, number, number][] = [['n', 0, -1], ['s', 0, 1], ['e', 1, 0], ['w', -1, 0]]
    for (const plot of Object.values(state.plots)) {
      for (const [side, dx, dy] of sides) {
        if (!plotAt(state, plot.x + dx, plot.y + dy)) context.drawImage(sprite(`field_edge_${side}`), plot.x * TILE, plot.y * TILE)
      }
    }
  }

  private guideTile(state: GameState, guide: GoalTarget): { x: number; y: number } | null {
    const plots = Object.values(state.plots).sort((a, b) => a.y - b.y || a.x - b.x)
    switch (guide) {
      case 'ripe': return plots.find((plot) => plot.crop && isReady(plot.crop)) ?? null
      case 'soil': return plots.find((plot) => !plot.crop) ?? null
      case 'dry': return plots.find((plot) => plot.crop && !isReady(plot.crop) && !isWet(plot, state.worldTime)) ?? null
      case 'ground':
        for (const parcel of PARCELS.filter((p) => state.ownedParcels.includes(p.id))) {
          for (let y = parcel.minY; y <= parcel.maxY; y++) {
            for (let x = parcel.minX; x <= parcel.maxX; x++) {
              if (!plotAt(state, x, y)) return { x, y }
            }
          }
        }
        return null
      default: return null
    }
  }

  private paintPlacing(context: CanvasRenderingContext2D, state: GameState, frame: ViewFrame): void {
    if (!frame.placing || !frame.hover) return
    const radius = machineDef(frame.placing)?.radius ?? 1
    const { x, y } = frame.hover
    const parcel = parcelAt(x, y)
    const allowed = parcel && state.ownedParcels.includes(parcel.id) && !plotAt(state, x, y)?.crop
    context.fillStyle = allowed ? 'rgba(120, 200, 255, 0.28)' : 'rgba(255, 90, 70, 0.28)'
    context.fillRect((x - radius) * TILE, (y - radius) * TILE, (radius * 2 + 1) * TILE, (radius * 2 + 1) * TILE)
  }

  private collectDrawables(context: CanvasRenderingContext2D, state: GameState, now: number): Drawable[] {
    const items: Drawable[] = []
    const add = (y: number, draw: () => void): void => {
      items.push({ y, draw })
    }
    const building = (name: string, place: { x: number; y: number }, anchor = ANCHOR.building): void => {
      add(place.y, () => this.paint(context, name, place.x * TILE, place.y * TILE, anchor))
    }

    building(`building_farmhouse_t${state.farmhouseLevel}`, PLACES.farmhouse)
    building('prop_well', PLACES.well, ANCHOR.well)
    building('building_farmers_market_stall', PLACES.market)
    const trip = (now - this.truckLeft) / TRUCK_TRIP_MS
    const driving = trip >= 0 && trip < 1
    const truckX = PLACES.truck.x + (driving ? Math.sin(trip * Math.PI) * 2.2 : 0)
    const truck = driving && trip > 0.5 ? 'vehicle_truck_old_dir08' : 'vehicle_truck_old_dir00'
    add(PLACES.truck.y, () => this.paint(context, truck, truckX * TILE, PLACES.truck.y * TILE, ANCHOR.truck))
    if (state.storageLevel >= 1) building('building_storage_shed', PLACES.shed)
    else add(4.6, () => this.paint(context, 'prop_hay_bale', 8.6 * TILE, 4.6 * TILE, 0.12))
    for (let i = 0; i < state.storageLevel - 1; i++) building('building_silo', PLACES.silos[i])
    if (state.windmill) {
      const sails = Math.floor(now / 170) % 6
      building('building_windmill', PLACES.windmill)
      add(PLACES.windmill.y + 0.01, () => this.paint(context, `building_windmill_sails_${sails}`, PLACES.windmill.x * TILE, PLACES.windmill.y * TILE, ANCHOR.building))
    } else {
      building('building_windmill_ruin', PLACES.windmill)
    }

    for (const parcel of PARCELS) {
      if (state.ownedParcels.includes(parcel.id)) continue
      const x = ((parcel.minX + parcel.maxX + 1) / 2) * TILE
      const y = (parcel.maxY + 0.2) * TILE
      add(parcel.maxY + 0.2, () => this.paint(context, 'prop_sign_for_sale', x, y, ANCHOR.sign))
    }

    for (const plot of Object.values(state.plots)) {
      const crop = plot.crop
      const def = crop && cropDef(crop.cropId)
      if (!crop || !def) continue
      const footY = (plot.y + 0.92) * TILE
      add(plot.y + 0.92, () => {
        this.paintCrop(context, def, stageFor(def, crop.growth), crop.mutation, (plot.x + 0.5) * TILE, footY, now)
      })
    }
    for (const sprinkler of state.sprinklers) {
      add(sprinkler.y + 0.8, () => this.paint(context, `prop_${sprinkler.kind}`, (sprinkler.x + 0.5) * TILE, (sprinkler.y + 0.8) * TILE, ANCHOR.sprinkler))
    }
    for (const actor of [this.farmer, ...this.hands]) {
      add(actor.y, () => {
        context.drawImage(sprite('fx_shadow_soft'), Math.round(actor.x * TILE - 11), Math.round(actor.y * TILE - 5), 22, 10)
        this.paint(context, actor.frame(now), actor.x * TILE, actor.y * TILE, ANCHOR.character, actor.flip)
      })
    }
    return items.sort((a, b) => a.y - b.y)
  }

  draw(state: GameState, frame: ViewFrame): void {
    const now = performance.now()
    const dt = Math.min((now - this.lastDraw) / 1000, 0.1)
    this.lastDraw = now
    this.syncHands(state.workers.length)
    this.farmer.update(dt)
    for (const hand of this.hands) hand.update(dt)

    const context = this.lowContext
    context.setTransform(1, 0, 0, 1, 0, 0)
    context.fillStyle = '#4c7a34'
    context.fillRect(0, 0, this.low.width, this.low.height)
    context.setTransform(1, 0, 0, 1, -this.cameraX, -this.cameraY)
    // Only the part on screen: this is the biggest image the game draws.
    const sourceX = Math.max(0, this.cameraX - BACKGROUND.x)
    const sourceY = Math.max(0, this.cameraY - BACKGROUND.y)
    const sourceWidth = Math.min(this.low.width, BACKGROUND.width - sourceX)
    const sourceHeight = Math.min(this.low.height, BACKGROUND.height - sourceY)
    context.drawImage(this.background, sourceX, sourceY, sourceWidth, sourceHeight,
      BACKGROUND.x + sourceX, BACKGROUND.y + sourceY, sourceWidth, sourceHeight)

    for (const parcel of PARCELS) this.paintField(context, state, parcel)
    this.paintSoil(context, state)

    if (frame.hover && !frame.placing) {
      const parcel = parcelAt(frame.hover.x, frame.hover.y)
      if (parcel) context.drawImage(sprite('fx_tile_highlight'), frame.hover.x * TILE, frame.hover.y * TILE, TILE, TILE)
    }
    this.paintPlacing(context, state, frame)

    for (const item of this.collectDrawables(context, state, now)) item.draw()

    const guide = this.guideTile(state, frame.guide)
    if (guide) {
      const bob = Math.abs(Math.sin(now / 260)) * 5
      this.paintGuideArrow(context, (guide.x + 0.5) * TILE, guide.y * TILE - 2 - bob)
    }

    if (now > this.nextSparkle) {
      this.nextSparkle = now + 500
      const ripe = Object.values(state.plots).filter((plot) => plot.crop && isReady(plot.crop))
      if (ripe.length > 0) {
        const plot = ripe[Math.floor(Math.random() * ripe.length)]
        this.spawn('fx_sparkle', plot.x + Math.random(), plot.y + Math.random() * 0.6, 0, -0.5, 0, 0.6)
      }
      for (const plot of ripe.filter((item) => item.crop?.mutation)) {
        this.spawn('fx_sparkle', plot.x + Math.random(), plot.y + Math.random() * 0.8, 0, -1, 0, 0.7)
      }
    }
    this.paintParticles(context, dt)
    this.present()
  }

  /** The arrow's art points right; here it points down, its tip at (x, y). */
  private paintGuideArrow(context: CanvasRenderingContext2D, x: number, y: number): void {
    const image = sprite('fx_guide_arrow')
    context.save()
    context.translate(Math.round(x), Math.round(y) - image.width)
    context.rotate(Math.PI / 2)
    context.drawImage(image, 0, -image.height / 2)
    context.restore()
  }

  private paintParticles(context: CanvasRenderingContext2D, dt: number): void {
    for (let i = this.particles.length - 1; i >= 0; i--) {
      const particle = this.particles[i]
      particle.age += dt
      if (particle.age >= particle.life) {
        this.particles.splice(i, 1)
        continue
      }
      particle.vy += particle.gravity * dt
      particle.x += particle.vx * dt
      particle.y += particle.vy * dt
      context.globalAlpha = Math.min(1, (1 - particle.age / particle.life) * 2)
      this.paint(context, particle.name, particle.x * TILE, particle.y * TILE, 0.5)
    }
    context.globalAlpha = 1
  }

  private present(): void {
    const drawnWidth = this.low.width * this.scale
    const drawnHeight = this.low.height * this.scale
    if (Number.isInteger(this.scale)) {
      this.context.imageSmoothingEnabled = false
      this.context.drawImage(this.low, 0, 0, drawnWidth, drawnHeight)
      return
    }
    this.midContext.drawImage(this.low, 0, 0, this.mid.width, this.mid.height)
    this.context.imageSmoothingEnabled = true
    this.context.imageSmoothingQuality = 'low'
    this.context.drawImage(this.mid, 0, 0, drawnWidth, drawnHeight)
  }
}
