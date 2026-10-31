// Copies the sprites the web game uses out of the iOS asset catalog, so the
// catalog stays the one source of the art. Runs before dev, build and test.
import { cpSync, existsSync, mkdirSync, readdirSync, rmSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const web = join(dirname(fileURLToPath(import.meta.url)), '..')
const resources = join(web, '..', 'Acres', 'Resources')
const catalog = join(resources, 'Assets.xcassets', 'Art')
const output = join(web, 'src', 'art')

const wanted = [
  /^crop_/,
  /^field_soil_(plowed|watered)(_\d)?$/,
  /^field_edge_/,
  /^terrain_(grass|dirt)$/,
  /^fx_(dust_puff|exclaim|guide_arrow|harvest_pop|shadow_soft|sparkle|tile_highlight|water_drops)$/,
  /^building_farmhouse_t\d$/,
  /^building_(farmers_market_stall|silo|storage_shed|windmill|windmill_ruin)$/,
  /^building_windmill_sails_\d$/,
  /^prop_(crate|fence_wood_h|fence_wood_post|fence_wood_v|hay_bale|mailbox|market_goods|sign_for_sale|signpost|sprinkler|sprinkler_pro|well)$/,
  /^nature_(bush_[ab]|flowers_\w+|grass_tuft_[ab]|rock_\w+)$/,
  /^tree_\w+_summer$/,
  /^character_(farmer|worker\d)_(down|side|up)_(idle|walk\d|hoe\d|can\d|hands\d)$/,
  /^vehicle_truck_old_dir\d+$/,
  /^ui_(board_\w+|card|hud_\w+|inset|paper|portrait_mentor|ribbon_\w+)$/,
  /^ui_icon_(check|close|coin|crate|drop|field|hoe|house|level|lock|note|seeds|shop|sickle|sparkle|watering_can|worker)$/,
]
const cropIDs = ['blueberry', 'cabbage', 'carrot', 'corn', 'garlic', 'kale', 'lettuce', 'melon', 'onion', 'potato',
  'pumpkin', 'strawberry', 'sunflower', 'tomato', 'wheat']
wanted.push(new RegExp(`^item_(seeds_)?(${cropIDs.join('|')})$`))

if (!existsSync(catalog)) throw new Error(`No asset catalog at ${catalog}`)
rmSync(output, { recursive: true, force: true })
mkdirSync(output, { recursive: true })

let copied = 0
for (const entry of readdirSync(catalog)) {
  const name = entry.replace(/\.imageset$/, '')
  if (!entry.endsWith('.imageset') || !wanted.some((pattern) => pattern.test(name))) continue
  const png = readdirSync(join(catalog, entry)).find((file) => file.endsWith('.png'))
  if (!png) continue
  cpSync(join(catalog, entry, png), join(output, `${name}.png`))
  copied += 1
}

mkdirSync(join(web, 'src', 'fonts'), { recursive: true })
cpSync(join(resources, 'Fonts', 'Fredoka.ttf'), join(web, 'src', 'fonts', 'Fredoka.ttf'))
// The font's license has to travel with it.
mkdirSync(join(web, 'public', 'licenses'), { recursive: true })
cpSync(join(resources, 'Fonts', 'Fredoka-OFL.txt'), join(web, 'public', 'licenses', 'Fredoka-OFL.txt'))
console.log(`sync-art: ${copied} sprites`)
