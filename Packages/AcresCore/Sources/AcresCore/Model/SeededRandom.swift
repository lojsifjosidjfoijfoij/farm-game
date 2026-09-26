import Foundation

/// A small, fast, deterministic random number generator (SplitMix64).
///
/// The simulation must be reproducible: the same save + the same elapsed time
/// must always give the same result (that is what makes offline catch-up
/// testable). So all simulation randomness comes from a `SeededRandom` stored
/// in the game state — never from `SystemRandomNumberGenerator`.
public struct SeededRandom: RandomNumberGenerator, Equatable, Sendable {
    public private(set) var state: UInt64

    public init(seed: UInt64) {
        self.state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Uniform Double in 0..<1.
    public mutating func nextUnit() -> Double {
        Double(next() >> 11) * (1.0 / Double(1 << 53))
    }

    /// Uniform Double in the given range.
    public mutating func next(in range: ClosedRange<Double>) -> Double {
        range.lowerBound + nextUnit() * (range.upperBound - range.lowerBound)
    }

    /// Stable 64-bit hash of a string (FNV-1a). Unlike `String.hashValue`,
    /// this is identical on every launch and every device, so it can seed
    /// procedural content.
    public static func stableHash(_ string: String) -> UInt64 {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        return hash
    }
}

extension SeededRandom: Codable {
    // Stored as a hex string: JSON numbers above 2^53 are not safe to round-trip
    // through every JSON parser (the save migrator re-parses JSON generically).
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let text = try container.decode(String.self)
        guard let value = UInt64(text, radix: 16) else {
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "Invalid random state '\(text)'")
        }
        self.state = value
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(String(state, radix: 16))
    }
}
