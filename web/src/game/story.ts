/** Arne's story, told in a few short scenes. Rare on purpose: these are the moments the game stops to breathe. */
export const INTRO = [
  'Forty years I farmed this valley.',
  'Then my knees handed in their notice.',
  "So it's yours now, kid. Try not to set fire to anything.",
]

/** Said as a farm is left behind. After the third, players know the way. */
export const REBIRTH_SCENES: Record<number, string[]> = {
  1: ['The sun sets on your first farm.', 'Arne says the soil remembers. Arne also talks to soil.'],
  2: ['Another sunset. Another farm.', 'The crops seem to recognise you now.'],
  3: ['Third time around.', 'Somewhere, a carrot whispers your name.'],
}

export const ASCEND_SCENE = ['You leave the valley behind and rise above the clouds.', 'Arne waves from far below. He thinks you fell off a ladder.']
export const BIG_BANG_SCENE = ['Everything you ever grew folds into a single seed.', 'It goes off.', 'Arne, somehow, is still here. "Morning."']
export const WINDMILL_SCENE = ['Forty years, those sails stood still.', 'Listen to that.']
