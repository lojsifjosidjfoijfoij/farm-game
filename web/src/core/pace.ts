import { DAY } from './content'

/**
 * Real seconds in a game day. The iOS game takes 24 minutes; a browser player
 * needs to see a crop come up in about a minute. The rules don't change, only
 * how fast sim time runs.
 */
export const REAL_SECONDS_PER_DAY = 45

/** Sim seconds that pass per real second. */
export const TIME_SCALE = DAY / REAL_SECONDS_PER_DAY
