import { type CropDef } from '../core/content'

const urls = import.meta.glob('../art/*.png', { eager: true, query: '?url', import: 'default' }) as Record<string, string>

const sprites = new Map<string, HTMLImageElement>()

export function artURL(name: string): string {
  const url = urls[`../art/${name}.png`]
  if (!url) throw new Error(`Missing sprite: ${name}`)
  return url
}

/** Loads every sprite, reporting progress as a fraction. */
export async function loadArt(onProgress: (fraction: number) => void): Promise<void> {
  const entries = Object.entries(urls)
  let loaded = 0
  await Promise.all(entries.map(async ([path, url]) => {
    const image = new Image()
    image.src = url
    await image.decode()
    sprites.set(path.replace('../art/', '').replace('.png', ''), image)
    loaded += 1
    onProgress(loaded / entries.length)
  }))
}

export function sprite(name: string): HTMLImageElement {
  const image = sprites.get(name)
  if (!image) throw new Error(`Sprite not loaded: ${name}`)
  return image
}

type Hsl = [number, number, number]

function toHsl(r: number, g: number, b: number): Hsl {
  const max = Math.max(r, g, b)
  const min = Math.min(r, g, b)
  const lightness = (max + min) / 2
  if (max === min) return [0, 0, lightness]
  const delta = max - min
  const saturation = lightness > 0.5 ? delta / (2 - max - min) : delta / (max + min)
  const hue = max === r ? (g - b) / delta + (g < b ? 6 : 0) : max === g ? (b - r) / delta + 2 : (r - g) / delta + 4
  return [hue / 6, saturation, lightness]
}

function channel(p: number, q: number, t: number): number {
  const hue = (t + 1) % 1
  if (hue < 1 / 6) return p + (q - p) * 6 * hue
  if (hue < 1 / 2) return q
  if (hue < 2 / 3) return p + (q - p) * (2 / 3 - hue) * 6
  return p
}

function toRgb([hue, saturation, lightness]: Hsl): [number, number, number] {
  if (saturation === 0) return [lightness, lightness, lightness]
  const q = lightness < 0.5 ? lightness * (1 + saturation) : lightness + saturation - lightness * saturation
  const p = 2 * lightness - q
  return [channel(p, q, hue + 1 / 3), channel(p, q, hue), channel(p, q, hue - 1 / 3)]
}

const recolors = new Map<string, HTMLCanvasElement>()

/** A sprite run through a color change, made once and kept. */
function recolored(name: string, key: string, change: (color: Hsl) => Hsl): HTMLCanvasElement {
  const cacheKey = `${name}|${key}`
  const known = recolors.get(cacheKey)
  if (known) return known
  const source = sprite(name)
  const canvas = document.createElement('canvas')
  canvas.width = source.width
  canvas.height = source.height
  const context = canvas.getContext('2d', { willReadFrequently: true })!
  context.drawImage(source, 0, 0)
  const image = context.getImageData(0, 0, canvas.width, canvas.height)
  const { data } = image
  for (let i = 0; i < data.length; i += 4) {
    if (data[i + 3] === 0) continue
    const [r, g, b] = toRgb(change(toHsl(data[i] / 255, data[i + 1] / 255, data[i + 2] / 255)))
    data[i] = Math.round(r * 255)
    data[i + 1] = Math.round(g * 255)
    data[i + 2] = Math.round(b * 255)
  }
  context.putImageData(image, 0, 0)
  recolors.set(cacheKey, canvas)
  return canvas
}

function exoticArt(name: string, def: CropDef): HTMLImageElement | HTMLCanvasElement {
  if (def.hue === undefined) return sprite(name)
  const turn = def.hue / 360
  return recolored(name, `hue${def.hue}`, ([h, s, l]) => [(h + turn) % 1, Math.min(1, s * 1.25 + 0.1), l])
}

const RAINBOW_FRAMES = 6

function rareArt(name: string, mutation: string, now: number): HTMLCanvasElement {
  switch (mutation) {
    case 'golden':
      return recolored(name, 'golden', ([, s, l]) => [0.125, Math.max(0.85, s), Math.min(0.9, l * 1.15 + 0.08)])
    case 'rainbow': {
      const frame = Math.floor(now / 140) % RAINBOW_FRAMES
      return recolored(name, `rainbow${frame}`, ([, s, l]) => [frame / RAINBOW_FRAMES, Math.max(0.8, s), Math.min(0.8, l + 0.1)])
    }
    case 'cosmic':
      return recolored(name, 'cosmic', ([, s, l]) => [0.78, Math.max(0.75, s), l * 0.75 + 0.1])
    default:
      return recolored(name, 'void', ([, , l]) => [0.72, 0.5, l * 0.3])
  }
}

/** What a crop looks like in the field, rare or not. */
export function cropSprite(def: CropDef, stage: number, mutation: string | undefined, now: number): HTMLImageElement | HTMLCanvasElement {
  const name = `crop_${def.art}_stage${stage}`
  return mutation ? rareArt(name, mutation, now) : exoticArt(name, def)
}

const iconURLs = new Map<string, string>()

/** The crop's icon for the HUD. Exotic ones have to be painted before they can be shown. */
export function cropIconURL(def: CropDef): string {
  const name = `item_${def.art}`
  if (def.hue === undefined) return artURL(name)
  let url = iconURLs.get(def.id)
  if (!url) {
    url = (exoticArt(name, def) as HTMLCanvasElement).toDataURL()
    iconURLs.set(def.id, url)
  }
  return url
}

/** The glow under a rare crop. */
export const RARE_GLOW: Record<string, string> = {
  golden: '255, 205, 60',
  rainbow: '255, 120, 220',
  cosmic: '170, 110, 255',
  void: '40, 10, 70',
}
