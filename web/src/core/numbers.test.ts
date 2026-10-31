import { describe, expect, it } from 'vitest'
import { formatNumber } from './numbers'

describe('formatNumber', () => {
  it('writes small numbers in full', () => {
    expect(formatNumber(0)).toBe('0')
    expect(formatNumber(950)).toBe('950')
    expect(formatNumber(12_400)).toBe('12,400')
    expect(formatNumber(999_999)).toBe('999,999')
  })

  it('names big numbers', () => {
    expect(formatNumber(1_000_000)).toBe('1.00M')
    expect(formatNumber(3_210_000)).toBe('3.21M')
    expect(formatNumber(45_600_000_000)).toBe('45.6B')
    expect(formatNumber(1e12)).toBe('1.00T')
    expect(formatNumber(1e15)).toBe('1.00Qa')
    expect(formatNumber(1e33)).toBe('1.00Dc')
  })

  it('carries over instead of writing 1000', () => {
    expect(formatNumber(999_999_999)).toBe('1.00B')
  })

  it('never runs out of names', () => {
    const seen = new Set<string>()
    for (let exponent = 6; exponent <= 300; exponent += 3) seen.add(formatNumber(Math.pow(10, exponent)))
    expect(seen.size).toBe(99)
    expect(formatNumber(1e100)).toMatch(/^10\.0[a-z]+$/)
  })

  it('handles negative numbers and infinity', () => {
    expect(formatNumber(-2_500_000)).toBe('-2.50M')
    expect(formatNumber(Infinity)).toBe('∞')
  })
})
