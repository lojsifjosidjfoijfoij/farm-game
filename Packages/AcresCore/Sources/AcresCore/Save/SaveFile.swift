import Foundation

/// The on-disk envelope around a game state.
///
/// The metadata (`revision`, `deviceID`, `savedAt`) is what a future iCloud
/// sync needs for conflict resolution: pick the higher revision, or when two
/// devices diverged, the newer `savedAt` (optionally asking the player).
public struct SaveFile: Codable, Equatable, Sendable {

    /// Bump this whenever the stored format changes, and add a migration from
    /// the previous version to `SaveMigrator.standard`.
    ///
    /// History:
    /// - v1: initial format (Phase 1).
    /// - v2: farmland (`plots`), `inventory`, `ownedProperties` (Phase 2).
    /// - v3: truck `fuel` and `cargo`, `tutorial` (Phase 3).
    /// - v4: `ranch` (pens and animals), `woodland` (changed trees) (Phase 4).
    /// - v5: `farmer` (position, energy, in the truck), `goals` (Phase 5).
    /// - v6: `contracts` (offers, accepted, reputation), `finance` (ledger, loan) (Phase 6).
    /// - v7: `store` (the rented shop: shelves, prices, takings) (Phase 7).
    /// - v8: `estate` (storage and truck upgrades, sprinklers, farmhands) (Phase 8).
    /// - v9: `daily` (chores, streak, market special) (Phase 9).
    public static let currentVersion = 9

    /// Format version of this file.
    public var version: Int
    /// Incremented on every save. Monotonic per save lineage.
    public var revision: Int
    /// Identifies the device that wrote this save (for sync conflicts).
    public var deviceID: String
    /// When this farm was started (wall clock).
    public var createdAt: Date
    /// When this file was written (wall clock). Offline catch-up measures from here.
    public var savedAt: Date
    public var state: GameState
    /// Presentation-only state worth restoring (camera). Not part of the simulation.
    public var presentation: PresentationState

    public init(
        version: Int = SaveFile.currentVersion,
        revision: Int,
        deviceID: String,
        createdAt: Date,
        savedAt: Date,
        state: GameState,
        presentation: PresentationState
    ) {
        self.version = version
        self.revision = revision
        self.deviceID = deviceID
        self.createdAt = createdAt
        self.savedAt = savedAt
        self.state = state
        self.presentation = presentation
    }
}

/// View state that is nice to restore but has no effect on the simulation.
public struct PresentationState: Codable, Equatable, Sendable {
    /// Camera center in tile units.
    public var cameraCenter: Vec2?
    /// Camera zoom (world points per screen point).
    public var cameraZoom: Double?
    /// The crop the seed button is set to. (v2)
    public var selectedSeed: String?

    public init(cameraCenter: Vec2? = nil, cameraZoom: Double? = nil, selectedSeed: String? = nil) {
        self.cameraCenter = cameraCenter
        self.cameraZoom = cameraZoom
        self.selectedSeed = selectedSeed
    }
}

public enum SaveError: Error, Equatable, Sendable {
    /// The file was written by a newer version of the game. Never overwrite it.
    case newerVersion(found: Int, supported: Int)
    /// No migration is registered from this version.
    case missingMigration(fromVersion: Int)
    /// The file could not be parsed or decoded.
    case corrupt(String)
    /// Reading or writing failed.
    case io(String)
}

/// JSON coding settings shared by saving and loading.
enum SaveCoding {
    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        // Sorted keys keep diffs of save files readable when debugging.
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .secondsSince1970
        return encoder
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }
}
