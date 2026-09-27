import AVFoundation
import Foundation

/// Sound effects. A real recording in the app bundle, named like the audio
/// manifest (`sfx_coin.m4a`), always wins; until one exists, a small
/// synthesized placeholder plays instead, so the game is never silent.
@MainActor
enum Sound {
    enum Effect: String, CaseIterable {
        case tap = "sfx_ui_tap"
        case open = "sfx_ui_open"
        case plow = "sfx_plow"
        case plant = "sfx_plant"
        case water = "sfx_water"
        case harvest = "sfx_harvest_pop"
        case coin = "sfx_coin"
        case coins = "sfx_coins_many"
        case levelUp = "sfx_level_up"
        case achievement = "sfx_achievement"
        case chop = "sfx_axe_chop"
        case treeFall = "sfx_tree_fall"
        case bump = "sfx_bump"
        case door = "sfx_truck_door"
        case chicken = "sfx_chicken"
        case notification = "sfx_notification"
        case refuse = "sfx_refuse"
    }

    static var isEnabled = true

    static func play(_ effect: Effect, volume: Float = 1) {
        guard isEnabled else { return }
        SoundEngine.shared.play(effect, volume: volume)
    }
}

/// A few voices on one audio engine, with every effect decoded (or
/// synthesized) once.
@MainActor
private final class SoundEngine {
    static let shared = SoundEngine()

    private let engine = AVAudioEngine()
    private var voices: [AVAudioPlayerNode] = []
    private var nextVoice = 0
    private var buffers: [Sound.Effect: AVAudioPCMBuffer] = [:]
    private var started = false
    private var failed = false
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!

    private func start() {
        guard !started, !failed else { return }
        do {
            // Ambient: respects the mute switch and mixes with the player's music.
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            for _ in 0..<8 {
                let voice = AVAudioPlayerNode()
                engine.attach(voice)
                engine.connect(voice, to: engine.mainMixerNode, format: format)
                voices.append(voice)
            }
            try engine.start()
            started = true
        } catch {
            failed = true
            print("⚠️ Sound unavailable: \(error)")
        }
    }

    func play(_ effect: Sound.Effect, volume: Float) {
        start()
        guard started, let buffer = buffer(effect) else { return }
        if !engine.isRunning { try? engine.start() }
        let voice = voices[nextVoice]
        nextVoice = (nextVoice + 1) % voices.count
        voice.stop()
        voice.volume = volume
        voice.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        voice.play()
    }

    private func buffer(_ effect: Sound.Effect) -> AVAudioPCMBuffer? {
        if let cached = buffers[effect] { return cached }
        let buffer = recording(effect) ?? Synth.make(effect, format: format)
        buffers[effect] = buffer
        return buffer
    }

    /// A real recording from the bundle, converted to the engine's format.
    private func recording(_ effect: Sound.Effect) -> AVAudioPCMBuffer? {
        for ext in ["m4a", "caf", "wav"] {
            guard let url = Bundle.main.url(forResource: effect.rawValue, withExtension: ext),
                  let file = try? AVAudioFile(forReading: url),
                  file.processingFormat.sampleRate == format.sampleRate, file.processingFormat.channelCount == 1,
                  let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)),
                  (try? file.read(into: buffer)) != nil else { continue }
            return buffer
        }
        return nil
    }
}

/// Tiny synthesizer for the placeholder effects: sines, noise and envelopes.
private enum Synth {
    static let rate = 44_100.0

    static func make(_ effect: Sound.Effect, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let samples = render(effect)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
              let channel = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        for (index, sample) in samples.enumerated() { channel[index] = sample }
        return buffer
    }

    private static func render(_ effect: Sound.Effect) -> [Float] {
        var noise = SeededNoise(seed: effect.rawValue.unicodeScalars.reduce(UInt64(7)) { $0 &* 31 &+ UInt64($1.value) })
        switch effect {
        case .tap:
            return tone(1_250, 0.035, decay: 90, gain: 0.35) + silence(0.01)
        case .open:
            return filteredNoise(0.12, cutoff: 0.08, decay: 22, gain: 0.35, noise: &noise)
        case .plow:
            return mix(filteredNoise(0.16, cutoff: 0.05, decay: 20, gain: 0.7, noise: &noise), tone(95, 0.16, decay: 22, gain: 0.5))
        case .plant:
            return filteredNoise(0.09, cutoff: 0.12, decay: 35, gain: 0.45, noise: &noise)
        case .water:
            return bubbly(0.32, noise: &noise)
        case .harvest:
            return sweep(from: 320, to: 980, duration: 0.07, gain: 0.5) + tone(980, 0.08, decay: 40, gain: 0.25)
        case .coin:
            return mix(tone(1_318, 0.28, decay: 11, gain: 0.3), silence(0.06) + tone(1_760, 0.24, decay: 11, gain: 0.3))
        case .coins:
            var out = silence(0.45)
            for k in 0..<5 {
                let at = Int(Double(k) * 0.07 * rate)
                let blip = tone([1_568, 1_760, 2_093, 1_760, 2_349][k], 0.16, decay: 18, gain: 0.22)
                for (i, s) in blip.enumerated() where at + i < out.count { out[at + i] += s }
            }
            return out
        case .levelUp:
            var out: [Float] = []
            for (k, f) in [523.25, 659.25, 783.99, 1_046.5].enumerated() {
                out += bell(f, k == 3 ? 0.45 : 0.1, gain: 0.35)
            }
            return out
        case .achievement:
            return mix(bell(783.99, 0.6, gain: 0.3), silence(0.12) + bell(1_174.7, 0.5, gain: 0.3))
        case .chop:
            return mix(filteredNoise(0.1, cutoff: 0.3, decay: 40, gain: 0.5, noise: &noise), tone(170, 0.12, decay: 30, gain: 0.5))
        case .treeFall:
            return sweep(from: 180, to: 90, duration: 0.45, gain: 0.25) + mix(tone(60, 0.25, decay: 14, gain: 0.7),
                                                                            filteredNoise(0.25, cutoff: 0.04, decay: 14, gain: 0.6, noise: &noise))
        case .bump:
            return tone(70, 0.16, decay: 24, gain: 0.7)
        case .door:
            return mix(tone(110, 0.18, decay: 25, gain: 0.6), filteredNoise(0.12, cutoff: 0.1, decay: 30, gain: 0.4, noise: &noise))
        case .chicken:
            var out: [Float] = []
            for f in [720.0, 820, 640] {
                out += sweep(from: f, to: f * 0.8, duration: 0.05, gain: 0.25) + silence(0.04)
            }
            return out
        case .notification:
            return bell(880, 0.45, gain: 0.3)
        case .refuse:
            return tone(330, 0.09, decay: 20, gain: 0.3, harmonic: 0.3) + tone(262, 0.12, decay: 20, gain: 0.3, harmonic: 0.3)
        }
    }

    // MARK: Building blocks

    private static func count(_ seconds: Double) -> Int { max(1, Int(seconds * rate)) }

    private static func silence(_ seconds: Double) -> [Float] { [Float](repeating: 0, count: count(seconds)) }

    /// A sine with an exponential fade (and an optional octave harmonic).
    private static func tone(_ frequency: Double, _ seconds: Double, decay: Double, gain: Double, harmonic: Double = 0) -> [Float] {
        (0..<count(seconds)).map { i in
            let t = Double(i) / rate
            let attack = min(1, t / 0.004)
            let wave = sin(2 * .pi * frequency * t) + harmonic * sin(4 * .pi * frequency * t)
            return Float(wave * gain * attack * exp(-decay * t))
        }
    }

    /// A bell: a sine plus a quieter inharmonic partial, ringing out.
    private static func bell(_ frequency: Double, _ seconds: Double, gain: Double) -> [Float] {
        (0..<count(seconds + 0.15)).map { i in
            let t = Double(i) / rate
            let attack = min(1, t / 0.003)
            let wave = sin(2 * .pi * frequency * t) + 0.35 * sin(2 * .pi * frequency * 2.76 * t) * exp(-8 * t)
            return Float(wave * gain * attack * exp(-4.5 * t))
        }
    }

    private static func sweep(from: Double, to: Double, duration: Double, gain: Double) -> [Float] {
        var phase = 0.0
        let n = count(duration)
        return (0..<n).map { i in
            let p = Double(i) / Double(n)
            phase += 2 * .pi * (from + (to - from) * p) / rate
            return Float(sin(phase) * gain * sin(.pi * p))
        }
    }

    /// Noise through a one-pole low-pass (`cutoff` 0…1), fading out.
    private static func filteredNoise(_ seconds: Double, cutoff: Double, decay: Double, gain: Double, noise: inout SeededNoise) -> [Float] {
        var low = 0.0
        return (0..<count(seconds)).map { i in
            let t = Double(i) / rate
            low += cutoff * (noise.next() - low)
            return Float(low * gain * 3 * exp(-decay * t) * min(1, t / 0.003))
        }
    }

    /// Water: noise with a wobbling volume.
    private static func bubbly(_ seconds: Double, noise: inout SeededNoise) -> [Float] {
        var low = 0.0
        return (0..<count(seconds)).map { i in
            let t = Double(i) / rate
            low += 0.25 * (noise.next() - low)
            let wobble = 0.6 + 0.4 * sin(2 * .pi * 23 * t)
            let envelope = sin(.pi * t / seconds)
            return Float(low * 0.9 * wobble * envelope)
        }
    }

    private static func mix(_ a: [Float], _ b: [Float]) -> [Float] {
        var out = [Float](repeating: 0, count: max(a.count, b.count))
        for (i, sample) in a.enumerated() { out[i] += sample }
        for (i, sample) in b.enumerated() { out[i] += sample }
        return out
    }
}

/// White noise in -1…1 (deterministic, so effects sound the same every time).
private struct SeededNoise {
    var state: UInt64

    init(seed: UInt64) { state = seed &* 0x9E37_79B9_7F4A_7C15 | 1 }

    mutating func next() -> Double {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return Double(state % 2_000_001) / 1_000_000 - 1
    }
}
