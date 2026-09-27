import Foundation

/// A linear RGB color with components in 0…1 (no UIKit dependency).
public struct RGB: Equatable, Sendable {
    public var r: Double
    public var g: Double
    public var b: Double

    public init(_ r: Double, _ g: Double, _ b: Double) {
        self.r = r
        self.g = g
        self.b = b
    }

    public static func lerp(_ a: RGB, _ b: RGB, _ t: Double) -> RGB {
        RGB(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t)
    }
}

/// How the world is lit at a given hour: a color the whole scene is
/// multiplied by, plus how strongly night lights (windows, lamps,
/// headlights) glow.
public struct Lighting: Equatable, Sendable {
    /// Multiplied over the scene. (1, 1, 1) = unchanged.
    public var tint: RGB
    /// 0 in daylight, 1 in full night.
    public var nightLights: Double
}

/// Keyframed lighting over a 24-hour day: warm morning, neutral noon, orange
/// evening, blue night. Pure data, so it is unit-tested and tweakable.
public enum DayNightCurve {

    struct Key {
        let hour: Double
        let tint: RGB
        let lights: Double
    }

    /// Keyframes in wall-clock hours; the curve wraps around midnight.
    static let keys: [Key] = [
        // Nights stay fairly bright: the cycle is only for looks, never in the way.
        Key(hour: 0.0, tint: RGB(0.52, 0.57, 0.78), lights: 1),     // night
        Key(hour: 4.5, tint: RGB(0.53, 0.58, 0.78), lights: 1),
        Key(hour: 5.6, tint: RGB(0.68, 0.64, 0.78), lights: 0.8),   // first light
        Key(hour: 6.5, tint: RGB(0.95, 0.80, 0.74), lights: 0.2),   // dawn blush
        Key(hour: 8.0, tint: RGB(1.00, 0.94, 0.84), lights: 0),     // warm morning
        Key(hour: 11.0, tint: RGB(1.00, 1.00, 0.98), lights: 0),    // bright noon
        Key(hour: 15.5, tint: RGB(1.00, 0.98, 0.93), lights: 0),
        Key(hour: 18.0, tint: RGB(1.00, 0.83, 0.64), lights: 0.05), // golden hour
        Key(hour: 19.3, tint: RGB(0.86, 0.60, 0.60), lights: 0.5),  // sunset
        Key(hour: 20.5, tint: RGB(0.6, 0.6, 0.8), lights: 0.95),    // blue hour
        Key(hour: 22.0, tint: RGB(0.53, 0.57, 0.78), lights: 1),
    ]

    public static func lighting(atHour hour: Double) -> Lighting {
        let h = ((hour.truncatingRemainder(dividingBy: 24)) + 24).truncatingRemainder(dividingBy: 24)
        // Find the keys around `h`, wrapping the last key to the first + 24h.
        var previous = keys[keys.count - 1]
        var previousHour = previous.hour - 24
        for key in keys {
            if h < key.hour {
                return interpolate(previous, from: previousHour, to: key, at: h)
            }
            previous = key
            previousHour = key.hour
        }
        let first = keys[0]
        return interpolate(previous, from: previousHour, to: first, atHour: first.hour + 24, at: h)
    }

    private static func interpolate(_ a: Key, from aHour: Double, to b: Key, atHour bHour: Double? = nil, at h: Double) -> Lighting {
        let end = bHour ?? b.hour
        let span = end - aHour
        let raw = span > 0 ? (h - aHour) / span : 0
        let t = raw * raw * (3 - 2 * raw)  // smoothstep: no visible "kinks" at keyframes
        return Lighting(tint: .lerp(a.tint, b.tint, t), nightLights: a.lights + (b.lights - a.lights) * t)
    }
}
