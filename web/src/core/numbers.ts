const NAMED = ['', 'K', 'M', 'B', 'T', 'Qa', 'Qi', 'Sx', 'Sp', 'Oc', 'No', 'Dc', 'Ud', 'Dd', 'Td', 'Qad', 'Qid', 'Sxd', 'Spd', 'Ocd', 'Nod', 'Vg']

/** After the named sizes run out, sizes go aa, ab … zz, then aaa, so a number always has a short name. */
function letters(index: number): string {
  let remaining = index + 26
  let text = ''
  while (remaining >= 0) {
    text = String.fromCharCode(97 + (remaining % 26)) + text
    remaining = Math.floor(remaining / 26) - 1
  }
  return text
}

function suffix(tier: number): string {
  return tier < NAMED.length ? NAMED[tier] : letters(tier - NAMED.length)
}

/** 950 → "950", 12,400 → "12,400", 3,210,000 → "3.21M", 1e15 → "1.00Qa". */
export function formatNumber(value: number): string {
  if (!Number.isFinite(value)) return '∞'
  const sign = value < 0 ? '-' : ''
  const size = Math.abs(value)
  if (size < 1_000_000) return sign + Math.round(size).toLocaleString('en-US')
  let tier = Math.floor(Math.log10(size) / 3)
  let mantissa = size / Math.pow(10, tier * 3)
  // Rounding can carry over: 999.999M must read 1.00B, not 1000M.
  if (mantissa >= 999.995) {
    tier += 1
    mantissa /= 1000
  }
  const digits = mantissa >= 100 ? 0 : mantissa >= 10 ? 1 : 2
  return `${sign}${mantissa.toFixed(digits)}${suffix(tier)}`
}
