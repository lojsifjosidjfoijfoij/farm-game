/** Sim seconds in one game day. Every rule is written in sim seconds, as in AcresCore. */
export const DAY = 24 * 60

/** Everything the game knows about one crop. Numbers are AcresCore's `CropCatalog`. */
export interface CropDef {
  id: string
  name: string
  plural: string
  /** Sim seconds from planting to ripe when kept watered. */
  growthSeconds: number
  /** If set, the plant stays after harvest and ripens again after this long. */
  regrowSeconds?: number
  seedCost: number
  /** Usual market price per item; the market drifts inside this range. */
  sellPrice: [number, number]
  /** Items per harvest. */
  yield: [number, number]
  xp: number
  unlockLevel: number
  /** Total rebirths needed before it can be planted. */
  unlockRebirths: number
  /** The sprites it uses. */
  art: string
  /** Turns the art this far round the color wheel (degrees), for exotic crops. */
  hue?: number
  /** What one counts for at market. Exotic crops count as their plain cousin, or one would flood it. */
  marketWeight: number
}

function crop(
  id: string, name: string, plural: string, days: number, seedCost: number,
  sellPrice: [number, number], yieldRange: [number, number], xp: number, unlockLevel: number, regrowDays?: number,
): CropDef {
  return {
    id, name, plural, seedCost, sellPrice, yield: yieldRange, xp, unlockLevel,
    unlockRebirths: 0, art: id, marketWeight: (sellPrice[0] + sellPrice[1]) / 2,
    growthSeconds: days * DAY,
    regrowSeconds: regrowDays === undefined ? undefined : regrowDays * DAY,
  }
}

export const CROPS: CropDef[] = [
  crop('wheat', 'Wheat', 'wheat', 1, 4, [10, 14], [3, 4], 2, 1),
  crop('carrot', 'Carrot', 'carrots', 1.5, 8, [18, 24], [2, 4], 3, 1),
  crop('potato', 'Potato', 'potatoes', 2, 15, [20, 28], [3, 5], 5, 1),
  crop('lettuce', 'Lettuce', 'lettuce', 1, 6, [27, 35], [1, 2], 2, 2),
  crop('onion', 'Onion', 'onions', 2, 12, [21, 27], [3, 5], 3, 2),
  crop('strawberry', 'Strawberry', 'strawberries', 3, 40, [13, 19], [4, 6], 4, 3, 1.5),
  crop('kale', 'Kale', 'kale', 2, 20, [42, 54], [2, 3], 4, 3),
  crop('tomato', 'Tomato', 'tomatoes', 3, 30, [12, 17], [3, 5], 4, 3, 1),
  crop('corn', 'Corn', 'corn', 4, 30, [60, 80], [3, 5], 9, 4),
  crop('garlic', 'Garlic', 'garlic', 3, 25, [52, 64], [3, 4], 4, 4),
  crop('sunflower', 'Sunflower', 'sunflowers', 3, 25, [125, 150], [1, 2], 5, 4),
  crop('blueberry', 'Blueberry', 'blueberries', 4, 50, [12, 17], [5, 8], 5, 5, 1.5),
  crop('cabbage', 'Cabbage', 'cabbages', 3, 30, [145, 175], [1, 2], 5, 5),
  crop('pumpkin', 'Pumpkin', 'pumpkins', 6, 80, [360, 430], [1, 2], 20, 6),
  crop('melon', 'Melon', 'melons', 5, 90, [380, 450], [1, 2], 12, 7),
]

const EXOTIC_PREFIXES = ['Frost', 'Ember', 'Moon', 'Storm', 'Sun', 'Shadow', 'Crystal', 'Thunder', 'Star', 'Ghost',
  'Solar', 'Void', 'Diamond', 'Cosmic', 'Galaxy']
const EXOTIC_ROMAN = ['', ' II', ' III', ' IV', ' V', ' VI', ' VII', ' VIII', ' IX', ' X']

const cropIndex = new Map(CROPS.map((def) => [def.id, def]))

/**
 * Exotic crops never run out: a new one every few rebirths, each worth several
 * times the last. They're the plain crops recolored, so they need no new art.
 */
export function exoticCrop(index: number): CropDef {
  const id = `x${index}`
  const known = cropIndex.get(id)
  if (known) return known
  const base = CROPS[index % CROPS.length]
  const prefix = EXOTIC_PREFIXES[index % EXOTIC_PREFIXES.length]
  const round = Math.floor(index / EXOTIC_PREFIXES.length)
  const name = `${prefix} ${base.name}${EXOTIC_ROMAN[round % EXOTIC_ROMAN.length]}`
  const price = BALANCE.exoticBasePrice * Math.pow(BALANCE.exoticPriceGrowth, index + 1)
  const def: CropDef = {
    id, name, plural: name,
    growthSeconds: (2 + (index % 4)) * DAY,
    seedCost: Math.round(price / 10),
    sellPrice: [price * 0.9, price * 1.1],
    yield: [2, 4],
    xp: 10 + index * 2,
    unlockLevel: 1,
    unlockRebirths: (index + 1) * BALANCE.rebirthsPerExoticCrop,
    art: base.id,
    hue: (index * 47 + 60) % 360,
    marketWeight: base.marketWeight,
  }
  cropIndex.set(id, def)
  return def
}

export function cropDef(id: string): CropDef | undefined {
  const known = cropIndex.get(id)
  if (known) return known
  return /^x\d+$/.test(id) ? exoticCrop(Number(id.slice(1))) : undefined
}

/** Visible stage for an amount of accumulated growth: 0 just planted, 4 ripe. */
export function stageFor(def: CropDef, growth: number): number {
  if (growth >= def.growthSeconds) return 4
  const fraction = growth / def.growthSeconds
  if (fraction < 0.12) return 0
  if (fraction < 0.4) return 1
  if (fraction < 0.7) return 2
  return 3
}

/** A block of ground that can be owned and farmed. Tile rectangles are inclusive. */
export interface ParcelDef {
  id: string
  name: string
  /** Null for the land you start with. Priced to climb steadily, from the iOS game's land prices. */
  price: number | null
  unlockLevel: number
  minX: number
  minY: number
  maxX: number
  maxY: number
}

export const PARCELS: ParcelDef[] = [
  { id: 'home_field', name: 'Home field', price: null, unlockLevel: 1, minX: 9, minY: 6, maxX: 13, maxY: 8 },
  { id: 'east_meadow', name: 'East Meadow', price: 2_500, unlockLevel: 2, minX: 15, minY: 6, maxX: 19, maxY: 8 },
  { id: 'west_field', name: 'West Field', price: 4_000, unlockLevel: 3, minX: 3, minY: 6, maxX: 7, maxY: 8 },
  { id: 'mill_lot', name: 'Mill Lot', price: 6_000, unlockLevel: 4, minX: 9, minY: 10, maxX: 13, maxY: 12 },
  { id: 'goat_hill', name: 'Goat Hill', price: 9_000, unlockLevel: 5, minX: 15, minY: 10, maxX: 19, maxY: 12 },
  { id: 'south_pasture', name: 'South Pasture', price: 12_000, unlockLevel: 7, minX: 3, minY: 10, maxX: 7, maxY: 12 },
]

/** A machine that stands in the fields. Numbers are AcresCore's `MachineCatalog`. */
export interface MachineDef {
  id: string
  name: string
  price: number
  unlockLevel: number
  radius: number
  blurb: string
}

export const MACHINES: MachineDef[] = [
  { id: 'sprinkler', name: 'Sprinkler', price: 450, unlockLevel: 3, radius: 1, blurb: 'Keeps the 8 tiles around it watered.' },
  { id: 'sprinkler_pro', name: 'Big sprinkler', price: 1_500, unlockLevel: 7, radius: 2, blurb: 'Waters a 5 × 5 square around it.' },
]

export function machineDef(id: string): MachineDef | undefined {
  return MACHINES.find((machine) => machine.id === id)
}

/** A one-off buy that changes how the farm runs. Rebirth takes them back unless a perk keeps them. */
export interface AutomationDef {
  id: string
  name: string
  blurb: string
  cost: number
  unlockLevel: number
}

export const AUTOMATION: AutomationDef[] = [
  { id: 'drill', name: 'Seed Drill', cost: 25_000, unlockLevel: 4, blurb: 'Harvested plots replant, and farmhands sow bare soil with your selected seed.' },
  { id: 'driver', name: 'Market Driver', cost: 40_000, unlockLevel: 4, blurb: 'Your truck sells everything every 10 seconds.' },
  { id: 'irrigation', name: 'Irrigation', cost: 250_000, unlockLevel: 5, blurb: 'Every plot stays wet.' },
  { id: 'foreman', name: 'Foreman', cost: 2_000_000, unlockLevel: 6, blurb: 'Buys upgrades, plows new land, and replants with whatever pays best.' },
]

/** An upgrade with no last level. It resets on rebirth, and each level costs more than it pays back. */
export interface TrainingDef {
  id: string
  name: string
  blurb: string
  baseCost: number
  costGrowth: number
  unlockLevel: number
}

export const TRAINING: TrainingDef[] = [
  { id: 'seeds', name: 'Better Seeds', blurb: 'Every crop sells for 20% more.', baseCost: 500, costGrowth: 1.5, unlockLevel: 2 },
  { id: 'fertilizer', name: 'Fertilizer', blurb: 'Crops grow 10% faster.', baseCost: 800, costGrowth: 1.6, unlockLevel: 2 },
  { id: 'barn', name: 'Bigger Barn', blurb: 'Store 25% more.', baseCost: 1_500, costGrowth: 1.6, unlockLevel: 3 },
  { id: 'reach', name: 'Market Reach', blurb: 'The market takes 25% more before prices drop.', baseCost: 3_000, costGrowth: 1.6, unlockLevel: 3 },
  { id: 'training', name: 'Farmhand Training', blurb: 'Farmhands work 25% faster.', baseCost: 4_000, costGrowth: 1.7, unlockLevel: 4 },
  { id: 'clover', name: 'Four-Leaf Clover', blurb: 'Rare crops turn up 10% more often.', baseCost: 5_000, costGrowth: 1.9, unlockLevel: 4 },
]

/** A permanent upgrade bought with Golden Seeds. `maxLevel` of null means it never tops out. */
export interface PerkDef {
  id: string
  name: string
  blurb: string
  baseCost: number
  costGrowth: number
  maxLevel: number | null
}

export const PERKS: PerkDef[] = [
  { id: 'green_thumb', name: 'Green Thumb', blurb: 'Every crop sells for 25% more.', baseCost: 2, costGrowth: 1.6, maxLevel: null },
  { id: 'old_habits', name: 'Old Habits', blurb: 'Start every farm with the Seed Drill and Market Driver.', baseCost: 3, costGrowth: 1, maxLevel: 1 },
  { id: 'loyal_hands', name: 'Loyal Farmhands', blurb: 'Start every farm with one more farmhand.', baseCost: 3, costGrowth: 2, maxLevel: 3 },
  { id: 'family_land', name: 'Family Land', blurb: 'Start every farm with one more field.', baseCost: 4, costGrowth: 1.8, maxLevel: 5 },
  { id: 'head_start', name: 'Head Start', blurb: 'Start every farm with 8× more coins.', baseCost: 2, costGrowth: 1.7, maxLevel: null },
  { id: 'deep_wells', name: 'Deep Wells', blurb: 'Start every farm with Irrigation.', baseCost: 10, costGrowth: 1, maxLevel: 1 },
  { id: 'old_foreman', name: 'Old Foreman', blurb: 'Start every farm with the Foreman.', baseCost: 15, costGrowth: 1, maxLevel: 1 },
  { id: 'swift', name: 'Swift Growth', blurb: 'Crops grow 20% faster.', baseCost: 3, costGrowth: 1.7, maxLevel: null },
  { id: 'lucky', name: 'Lucky Streak', blurb: 'Rare crops turn up 25% more often.', baseCost: 3, costGrowth: 1.8, maxLevel: null },
  { id: 'long_naps', name: 'Long Naps', blurb: 'Earn while you are away for 2 more hours.', baseCost: 2, costGrowth: 1.5, maxLevel: 10 },
]

export function perkDef(id: string): PerkDef | undefined {
  return PERKS.find((perk) => perk.id === id)
}

/** A rare crop: rolled as it ripens, paid on top of the normal harvest. The rarest come last. */
export interface MutationDef {
  id: string
  name: string
  chance: number
  multiplier: number
}

export const MUTATIONS: MutationDef[] = [
  { id: 'void', name: 'Void', chance: 1 / 20_000, multiplier: 1_000 },
  { id: 'cosmic', name: 'Cosmic', chance: 1 / 2_500, multiplier: 150 },
  { id: 'rainbow', name: 'Rainbow', chance: 1 / 300, multiplier: 25 },
  { id: 'golden', name: 'Golden', chance: 1 / 40, multiplier: 5 },
]

export function mutationDef(id: string | undefined): MutationDef | undefined {
  return MUTATIONS.find((mutation) => mutation.id === id)
}

/** Every tunable number that isn't in a catalog above. */
export const BALANCE = {
  startingMoney: 50,
  dryGrowthRate: 0.5,
  soilWetDuration: DAY,

  marketDepth: 6_000,
  marketPriceFloor: 0.3,
  marketRecoveryPerDay: 0.75,
  marketSpecialBonus: 0.5,
  /** Game days a price and the market's special hold for. */
  marketDaysPerPrice: 3,

  storageLevels: [300, 450, 650, 900],
  storageUpgradeCosts: [1_500, 4_000, 9_000],
  storageUpgradeLevels: [2, 4, 6],

  workerHireCosts: [2_500, 6_000, 15_000],
  workerUnlockLevels: [4, 6, 8],
  workerTasksPerDay: 20,

  /** Renovation tiers: what each costs and needs. Each pays `farmhouseBonus` more at market. */
  farmhouseCosts: [6_000, 25_000, 80_000],
  farmhouseLevels: [3, 6, 8],
  farmhouseBonus: 0.05,

  windmillCost: 100_000,
  windmillLevel: 8,
  /** With the sails turning, buyers come from further off: the market is this much deeper. */
  windmillMarketDepth: 1.5,

  /** Real seconds of absence counted at most, as in the iOS game. */
  offlineCatchUpCap: 3 * 24 * 60 * 60,

  /** Hours of absence that earn coins before Long Naps, and what share of the usual income they earn. */
  offlineEarningHours: 4,
  offlineEarningRate: 0.5,
  /** Real seconds of play the income figure averages over. */
  incomeAverageSeconds: 120,

  /** Coins that must be earned in one run for the first rebirth, and how much more for each next one. */
  rebirthBase: 25_000_000,
  rebirthGrowth: 16,
  /** Each rebirth in this ascension multiplies crop value by this. */
  rebirthValue: 1.5,
  rebirthsToAscend: 10,
  /** Each ascension raises the first rebirth's price by this. */
  ascensionGrowth: 7e10,
  /** Each star doubles crop value, for good. */
  starValue: 2,
  /** A run has to reach this to set off a big bang. */
  bigBangCoins: 1e100,
  universeValue: 1_000,

  exoticBasePrice: 300,
  exoticPriceGrowth: 3,
  rebirthsPerExoticCrop: 4,

  /** Each farmer level adds this to crop value. Levels never reset. */
  levelValue: 0.02,
  /** Each lifetime trophy multiplies crop value by this. */
  trophyValue: 1.2,
  /** Each mastery level adds this to one crop's value. */
  masteryValue: 0.1,
  masteryFirstHarvest: 50,

  /** Crops stop speeding up here, however much fertilizer goes on. */
  maxGrowthSpeed: 8,

  /** Real seconds between trips to market for the Market Driver. */
  driverSeconds: 10,
  /** Sim seconds between the Foreman's rounds. */
  foremanInterval: 72,

  /** Boosts from the Market. Times are real seconds. */
  coinBoostMultiplier: 5,
  coinBoostSeconds: 60,
  coinBoostCostSeconds: 120,
  skipSeconds: 120,
  skipCostSeconds: 60,
  boostCooldownSeconds: 180,

  /** Money stops growing here rather than breaking. A big bang comes long before it. */
  maxCoins: 1e300,
} as const

/** Experience needed to go from `level` to `level + 1`. */
export function xpToNextLevel(level: number): number {
  const l = Math.max(1, level) - 1
  return 20 + Math.round(25 * Math.pow(l, 1.5))
}
