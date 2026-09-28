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
            // v3 → v4 (Phase 4): no animals yet (pens start run-down) and every
            // tree still standing.
            3: { json in
                var state = json["state"] as? [String: Any] ?? [:]
                state["ranch"] = ["pens": [String: Any](), "nextAnimalID": 1] as [String: Any]
                state["woodland"] = ["trees": [Any](), "hiddenMapTrees": [Any]()]
                json["state"] = state
            },
            // v4 → v5 (Phase 5): the farmer appears at the farmhouse door, rested,
            // and the goal ladder starts from the beginning.
            4: { json in
                var state = json["state"] as? [String: Any] ?? [:]
                state["farmer"] = ["position": ["x": 21.0, "y": 35.5], "energy": 100.0, "inTruck": false] as [String: Any]
                state["goals"] = ["counters": [String: Int](), "claimed": [String]()] as [String: Any]
                json["state"] = state
            },
            // v5 → v6 (Phase 6): an empty contract board (the first orders go up
            // at once) and fresh books starting this week, so no bills are
            // charged for the past.
            5: { json in
                var state = json["state"] as? [String: Any] ?? [:]
                let clock = state["clock"] as? [String: Any] ?? [:]
                let minutes = (clock["totalMinutes"] as? Double) ?? Double(clock["totalMinutes"] as? Int ?? 0)
                let day = Int((minutes / 1440).rounded(.down))
                state["contracts"] = ["offers": [Any](), "active": [Any](), "reputation": 10, "completed": 0,
                                      "failed": 0, "nextID": 1] as [String: Any]
                state["finance"] = ["thisWeek": ["week": day / 7 + 1, "income": [String: Int](), "expenses": [String: Int]()] as [String: Any],
                                    "lastProcessedDay": day] as [String: Any]
                json["state"] = state
            },
            6: { json in
                var state = json["state"] as? [String: Any] ?? [:]
                let clock = state["clock"] as? [String: Any] ?? [:]
                let minutes = (clock["totalMinutes"] as? Double) ?? Double(clock["totalMinutes"] as? Int ?? 0)
                let day = Int((minutes / 1440).rounded(.down))
                state["store"] = ["isRented": false, "shelves": [Any](),
                                  "today": ["day": day, "coins": 0, "items": 0, "sales": [String: Int]()] as [String: Any],
                                  "totalCoins": 0] as [String: Any]
                json["state"] = state
            },
            7: { json in
                var state = json["state"] as? [String: Any] ?? [:]
                state["estate"] = ["storageLevel": 0, "truckBedLevel": 0, "sprinklers": [Any](), "workers": [Any](),
                                   "nextWorkerID": 1] as [String: Any]
                json["state"] = state
            },
            8: { json in
                var state = json["state"] as? [String: Any] ?? [:]
                state["daily"] = ["day": -1, "chores": [Any](), "streak": 0, "bestStreak": 0, "bonusClaimed": false] as [String: Any]
                json["state"] = state
            },
            9: { json in
                var state = json["state"] as? [String: Any] ?? [:]
                var estate = state["estate"] as? [String: Any] ?? [:]
                estate["workshops"] = [Any]()
                state["estate"] = estate
                json["state"] = state
            },
            10: { json in
                var state = json["state"] as? [String: Any] ?? [:]
                state["forage"] = ["day": -1, "picked": [Any]()] as [String: Any]
                json["state"] = state
            },
            11: { json in
                // Discoveries fill in on the first step from storage and the counters.
                var state = json["state"] as? [String: Any] ?? [:]
                state["almanac"] = ["discovered": [Any](), "claimedSets": [Any]()] as [String: Any]
                state["rank"] = ["rank": 0] as [String: Any]
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
