/** Every sound is synthesized, like the iOS game's `Sound.swift`, so the build carries no audio files. */
export type SoundEffect = 'tap' | 'open' | 'plow' | 'plant' | 'water' | 'harvest' | 'coins' | 'levelUp' | 'goal' | 'refuse' | 'rare' | 'rebirth'

const MUTE_KEY = 'valley-farm-muted'

let context: AudioContext | null = null
let noise: AudioBuffer | null = null
let muted = readMuted()
/** Muted from outside the game: the portal's own setting wins over the in-game toggle. */
let portalMuted = false
let adPlaying = false

function readMuted(): boolean {
  try {
    return localStorage.getItem(MUTE_KEY) === '1'
  } catch {
    return false
  }
}

export function isMuted(): boolean {
  return muted || portalMuted
}

export function setPortalMuted(value: boolean): void {
  portalMuted = value
}

export function setAdPlaying(value: boolean): void {
  adPlaying = value
}

export function setMuted(value: boolean): void {
  muted = value
  try {
    localStorage.setItem(MUTE_KEY, value ? '1' : '0')
  } catch {
    // It just won't be remembered.
  }
}

/** Browsers only allow audio after a user gesture, so this runs on the first press. */
export function unlockAudio(): void {
  if (!context) {
    context = new AudioContext()
    noise = context.createBuffer(1, context.sampleRate, context.sampleRate)
    const samples = noise.getChannelData(0)
    for (let i = 0; i < samples.length; i++) samples[i] = Math.random() * 2 - 1
  }
  if (context.state === 'suspended') void context.resume()
}

function tone(frequency: number, start: number, length: number, gain: number, type: OscillatorType = 'triangle', slideTo?: number): void {
  if (!context) return
  const t = context.currentTime + start
  const oscillator = context.createOscillator()
  const envelope = context.createGain()
  oscillator.type = type
  oscillator.frequency.setValueAtTime(frequency, t)
  if (slideTo) oscillator.frequency.exponentialRampToValueAtTime(slideTo, t + length)
  envelope.gain.setValueAtTime(gain, t)
  envelope.gain.exponentialRampToValueAtTime(0.0001, t + length)
  oscillator.connect(envelope).connect(context.destination)
  oscillator.start(t)
  oscillator.stop(t + length)
}

function hiss(start: number, length: number, gain: number, cutoff: number): void {
  if (!context || !noise) return
  const t = context.currentTime + start
  const source = context.createBufferSource()
  const filter = context.createBiquadFilter()
  const envelope = context.createGain()
  source.buffer = noise
  filter.type = 'lowpass'
  filter.frequency.value = cutoff
  envelope.gain.setValueAtTime(gain, t)
  envelope.gain.exponentialRampToValueAtTime(0.0001, t + length)
  source.connect(filter).connect(envelope).connect(context.destination)
  source.start(t, Math.random() * 0.5, length)
}

/** Dragging across a field fires many jobs at once; one sound per kind per beat is plenty. */
const lastPlayed = new Map<SoundEffect, number>()
const MIN_GAP_MS = 55

export function play(effect: SoundEffect): void {
  if (isMuted() || adPlaying || !context) return
  const now = performance.now()
  if (now - (lastPlayed.get(effect) ?? -1000) < MIN_GAP_MS) return
  lastPlayed.set(effect, now)
  switch (effect) {
    case 'tap':
      tone(660, 0, 0.05, 0.05)
      break
    case 'open':
      tone(392, 0, 0.07, 0.05)
      tone(523, 0.05, 0.09, 0.05)
      break
    case 'plow':
      hiss(0, 0.09, 0.09, 700)
      break
    case 'plant':
      tone(300, 0, 0.07, 0.07, 'sine', 180)
      hiss(0, 0.04, 0.03, 1800)
      break
    case 'water':
      tone(900, 0, 0.05, 0.03, 'sine', 1500)
      hiss(0, 0.1, 0.04, 2600)
      break
    case 'harvest':
      tone(440, 0, 0.09, 0.09, 'sine', 880)
      break
    case 'coins':
      for (let i = 0; i < 5; i++) {
        tone(1320 + i * 120, i * 0.05, 0.13, 0.05, 'square')
        tone(1980 + i * 180, i * 0.05 + 0.02, 0.1, 0.02, 'sine')
      }
      break
    case 'levelUp':
      [523, 659, 784, 1047].forEach((frequency, i) => tone(frequency, i * 0.09, 0.3, 0.09))
      break
    case 'goal':
      tone(659, 0, 0.14, 0.07)
      tone(988, 0.1, 0.24, 0.07)
      break
    case 'rare':
      [880, 1175, 1760].forEach((frequency, i) => tone(frequency, i * 0.06, 0.35, 0.05, 'sine'))
      break
    case 'rebirth':
      tone(110, 0, 1.4, 0.12, 'sawtooth', 880)
      hiss(0, 1.2, 0.05, 4000);
      [523, 659, 784, 1047, 1319, 1568].forEach((frequency, i) => tone(frequency, 0.5 + i * 0.1, 0.5, 0.08))
      break
    case 'refuse':
      tone(160, 0, 0.13, 0.08, 'square')
      break
  }
}
