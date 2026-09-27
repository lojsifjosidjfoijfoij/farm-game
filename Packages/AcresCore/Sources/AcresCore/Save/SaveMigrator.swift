import Foundation

/// Upgrades old save files to the current format, one version at a time.
///
/// Migrations operate on the raw JSON dictionary, *not* on Swift types, so a
/// migration keeps working even after the Swift types have moved on.
///
/// Adding a migration (example for v1 → v2 adding `state.silo`):
/// ```swift
/// 1: { json in
///     var state = json["state"] as? [String: Any] ?? [:]
///     state["silo"] = ["capacity": 50, "stored": [:]]
///     json["state"] = state
/// },
/// ```
/// …then add a test that loads a v1 fixture and checks the result.
public struct SaveMigrator: Sendable {
    public typealias Migration = @Sendable (inout [String: Any]) throws -> Void

    public let currentVersion: Int
    /// Keyed by the version being migrated *from*.
    private let migrations: [Int: Migration]

    public init(currentVersion: Int, migrations: [Int: Migration]) {
        self.currentVersion = currentVersion
        self.migrations = migrations
    }

    /// The migrations the shipping game uses.
    ///
    /// Migrations are frozen history: never change one after release, and never
    /// read from `Balance` or catalogs in them (those keep changing).
    public static let standard = SaveMigrator(
        currentVersion: SaveFile.currentVersion,
        migrations: [
            // v1 → v2 (Phase 2): farmland, inventory and land ownership. Phase 1
            // farmers get the same starting seeds as a new game.
            1: { json in
                var state = json["state"] as? [String: Any] ?? [:]
                state["plots"] = [Any]()
                state["inventory"] = ["items": ["seeds_wheat": 12, "seeds_carrot": 8, "seeds_potato": 4]]
                state["ownedProperties"] = ["home_farm"]
                json["state"] = state
            },
            // v2 → v3 (Phase 3): a full tank, an empty truck bed and the tutorial.
            // Existing farmers get the tutorial too; it can be skipped.
            2: { json in
                var state = json["state"] as? [String: Any] ?? [:]
                var truck = state["truck"] as? [String: Any] ?? [:]
                truck["fuel"] = 100
                truck["cargo"] = ["items": [String: Int]()]
                state["truck"] = truck
                state["tutorial"] = ["step": 0, "progress": 0]
                json["state"] = state
            },
        ]
    )

    /// Returns JSON data upgraded to `currentVersion`. Data that is already
    /// current is returned untouched (no re-encoding).
    public func migrate(_ data: Data) throws -> Data {
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw SaveError.corrupt("Not valid JSON: \(error.localizedDescription)")
        }
        guard var json = object as? [String: Any] else {
            throw SaveError.corrupt("Top level is not an object")
        }
        guard let version = Self.intValue(json["version"]) else {
            throw SaveError.corrupt("Missing version")
        }
        if version == currentVersion { return data }
        if version > currentVersion {
            throw SaveError.newerVersion(found: version, supported: currentVersion)
        }
        if version < 1 {
            throw SaveError.corrupt("Invalid version \(version)")
        }

        for from in version..<currentVersion {
            guard let migration = migrations[from] else {
                throw SaveError.missingMigration(fromVersion: from)
            }
            try migration(&json)
            json["version"] = from + 1
        }

        do {
            return try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])
        } catch {
            throw SaveError.corrupt("Could not re-encode migrated save: \(error.localizedDescription)")
        }
    }

    /// Reads the format version without fully decoding the file.
    public static func version(of data: Data) -> Int? {
        guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return nil
        }
        return intValue(json["version"])
    }

    private static func intValue(_ value: Any?) -> Int? {
        if let int = value as? Int { return int }
        if let double = value as? Double, double == double.rounded() { return Int(double) }
        return nil
    }
}
