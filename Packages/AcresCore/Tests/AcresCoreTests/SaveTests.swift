import XCTest
@testable import AcresCore

/// Frozen save files from every released format version.
///
/// NEVER edit an existing fixture. When the format changes:
/// 1. bump `SaveFile.currentVersion` and add a migration to `SaveMigrator.standard`,
/// 2. add a new fixture (`v2`, …) and point `latest` at it,
/// 3. keep the old fixtures: `testEveryOldFixtureStillLoads` proves old saves upgrade.
enum SaveFixtures {
    static let v1 = """
    {
      "createdAt": 1800000000,
      "deviceID": "fixture-device",
      "presentation": { "cameraCenter": { "x": 26, "y": 32.5 }, "cameraZoom": 1.5 },
      "revision": 12,
      "savedAt": 1800003600,
      "state": {
        "clock": { "totalMinutes": 4380 },
        "money": 1234,
        "progress": { "level": 1, "xp": 0 },
        "rng": "2a",
        "stats": { "offlineSeconds": 7200, "playSeconds": 3000, "returns": 2 },
        "truck": { "heading": 3.5, "position": { "x": 26.25, "y": 30.25 } },
        "worldTime": 10200
      },
      "version": 1
    }
    """

    static let v2 = """
    {
      "createdAt": 1800000000,
      "deviceID": "fixture-device",
      "presentation": { "cameraCenter": { "x": 26, "y": 32.5 }, "cameraZoom": 1.5, "selectedSeed": "carrot" },
      "revision": 40,
      "savedAt": 1800007200,
      "state": {
        "clock": { "totalMinutes": 4380 },
        "inventory": { "items": { "seeds_carrot": 5, "wheat": 7 } },
        "money": 1234,
        "ownedProperties": ["home_farm"],
        "plots": [
          {
            "crop": { "cropID": "carrot", "growth": 120, "harvests": 0, "plantedAt": 10000, "wateredGrowth": 60 },
            "tile": { "x": 20, "y": 31 },
            "wetUntil": 11200
          },
          { "tile": { "x": 21, "y": 31 }, "wetUntil": 0 }
        ],
        "progress": { "level": 2, "xp": 5 },
        "rng": "2a",
        "stats": { "offlineSeconds": 7200, "playSeconds": 3000, "returns": 2 },
        "truck": { "heading": 3.5, "position": { "x": 26.25, "y": 30.25 } },
        "worldTime": 10200
      },
      "version": 2
    }
    """

    static let v3 = """
    {
      "createdAt": 1800000000,
      "deviceID": "fixture-device",
      "presentation": { "cameraCenter": { "x": 70, "y": 24 }, "cameraZoom": 1.5, "selectedSeed": "wheat" },
      "revision": 77,
      "savedAt": 1800009000,
      "state": {
        "clock": { "totalMinutes": 4380 },
        "inventory": { "items": { "seeds_carrot": 5 } },
        "money": 2345,
        "ownedProperties": ["home_farm"],
        "plots": [ { "tile": { "x": 21, "y": 31 }, "wetUntil": 0 } ],
        "progress": { "level": 3, "xp": 12 },
        "rng": "2b",
        "stats": { "offlineSeconds": 7200, "playSeconds": 5000, "returns": 3 },
        "truck": {
          "cargo": { "items": { "wheat": 9 } },
          "fuel": 62.5,
          "heading": 0,
          "position": { "x": 95, "y": 24 }
        },
        "tutorial": { "progress": 0, "step": 8 },
        "worldTime": 12000
      },
      "version": 3
    }
    """

    /// All fixtures, oldest first.
    static let all: [(version: Int, json: String)] = [(1, v1), (2, v2), (3, v3)]
    static var latest: (version: Int, json: String) { all.last! }

    /// What `v1` must decode to after migrating to the current version.
    static let v1Migrated = SaveFile(
        version: SaveFile.currentVersion,
        revision: 12,
        deviceID: "fixture-device",
        createdAt: Date(timeIntervalSince1970: 1_800_000_000),
        savedAt: Date(timeIntervalSince1970: 1_800_003_600),
        state: GameState(
            worldTime: 10_200,
            clock: GameClock(totalMinutes: 4380),
            money: 1234,
            progress: FarmerProgress(level: 1, xp: 0),
            truck: TruckState(position: Vec2(26.25, 30.25), heading: 3.5),
            rng: SeededRandom(seed: 0x2A),
            stats: PlayStats(playSeconds: 3000, offlineSeconds: 7200, returns: 2),
            // Added by the v1 → v2 migration: empty farmland, the starting seeds, the home farm.
            plots: FarmPlots(),
            inventory: Inventory(items: ["seeds_wheat": 12, "seeds_carrot": 8, "seeds_potato": 4]),
            ownedProperties: ["home_farm"],
            tutorial: .new  // added by v2 → v3
        ),
        presentation: PresentationState(cameraCenter: Vec2(26, 32.5), cameraZoom: 1.5)
    )

    /// What `v2` must decode to after migrating to the current version.
    static let v2Migrated = SaveFile(
        version: SaveFile.currentVersion,
        revision: 40,
        deviceID: "fixture-device",
        createdAt: Date(timeIntervalSince1970: 1_800_000_000),
        savedAt: Date(timeIntervalSince1970: 1_800_007_200),
        state: GameState(
            worldTime: 10_200,
            clock: GameClock(totalMinutes: 4380),
            money: 1234,
            progress: FarmerProgress(level: 2, xp: 5),
            truck: TruckState(position: Vec2(26.25, 30.25), heading: 3.5),
            rng: SeededRandom(seed: 0x2A),
            stats: PlayStats(playSeconds: 3000, offlineSeconds: 7200, returns: 2),
            plots: FarmPlots([
                Plot(tile: TileCoord(20, 31), wetUntil: 11_200,
                     crop: PlantedCrop(cropID: "carrot", plantedAt: 10_000, growth: 120, wateredGrowth: 60)),
                Plot(tile: TileCoord(21, 31)),
            ]),
            inventory: Inventory(items: ["seeds_carrot": 5, "wheat": 7]),
            ownedProperties: ["home_farm"],
            tutorial: .new
        ),
        presentation: PresentationState(cameraCenter: Vec2(26, 32.5), cameraZoom: 1.5, selectedSeed: "carrot")
    )

    /// What `v3` must decode to.
    static let v3Expected = SaveFile(
        version: 3,
        revision: 77,
        deviceID: "fixture-device",
        createdAt: Date(timeIntervalSince1970: 1_800_000_000),
        savedAt: Date(timeIntervalSince1970: 1_800_009_000),
        state: GameState(
            worldTime: 12_000,
            clock: GameClock(totalMinutes: 4380),
            money: 2345,
            progress: FarmerProgress(level: 3, xp: 12),
            truck: TruckState(position: Vec2(95, 24), heading: 0, fuel: 62.5, cargo: Inventory(items: ["wheat": 9])),
            rng: SeededRandom(seed: 0x2B),
            stats: PlayStats(playSeconds: 5000, offlineSeconds: 7200, returns: 3),
            plots: FarmPlots([Plot(tile: TileCoord(21, 31))]),
            inventory: Inventory(items: ["seeds_carrot": 5]),
            ownedProperties: ["home_farm"],
            tutorial: TutorialState(step: .sell)
        ),
        presentation: PresentationState(cameraCenter: Vec2(70, 24), cameraZoom: 1.5, selectedSeed: "wheat")
    )

    /// The value whose encoding must have the same shape as the latest fixture.
    static var latestExpected: SaveFile { v3Expected }
}

/// In-memory store for tests.
final class MemorySaveStore: SaveStore, @unchecked Sendable {
    var main: Data?
    var backup: Data?

    func read() throws -> Data? { main }
    func readBackup() throws -> Data? { backup }
    func write(_ data: Data) throws {
        backup = main
        main = data
    }
    func quarantine() throws {
        main = nil
        backup = nil
    }
    func deleteAll() throws {
        main = nil
        backup = nil
    }
}

final class SaveTests: XCTestCase {

    private var tempDirectory: URL!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("acres-tests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    // MARK: Format stability

    func testEveryOldFixtureStillLoads() {
        let system = SaveSystem(store: MemorySaveStore(), deviceID: "test")
        for fixture in SaveFixtures.all {
            switch system.decode(Data(fixture.json.utf8)) {
            case .success(let file):
                XCTAssertEqual(file.version, SaveFile.currentVersion, "v\(fixture.version) should be migrated to current")
            case .failure(let error):
                XCTFail("Fixture v\(fixture.version) no longer loads: \(error)")
            }
        }
    }

    func testVersion1FixtureMigratesExactly() throws {
        let system = SaveSystem(store: MemorySaveStore(), deviceID: "test")
        let file = try system.decode(Data(SaveFixtures.v1.utf8)).get()
        XCTAssertEqual(file, SaveFixtures.v1Migrated)
    }

    func testVersion2FixtureMigratesExactly() throws {
        let system = SaveSystem(store: MemorySaveStore(), deviceID: "test")
        let file = try system.decode(Data(SaveFixtures.v2.utf8)).get()
        XCTAssertEqual(file, SaveFixtures.v2Migrated)
    }

    func testVersion3FixtureDecodesExactly() throws {
        let system = SaveSystem(store: MemorySaveStore(), deviceID: "test")
        let file = try system.decode(Data(SaveFixtures.v3.utf8)).get()
        XCTAssertEqual(file, SaveFixtures.v3Expected)
    }

    func testCurrentFormatMatchesLatestFixture() throws {
        XCTAssertEqual(SaveFixtures.latest.version, SaveFile.currentVersion,
                       "Add a fixture for the new save version")
        // Encode a value that uses every field and compare the *shape* (key paths)
        // with the latest fixture. Adding/removing/renaming a stored property
        // changes the shape: that requires a version bump + migration.
        let encoded = try SaveCoding.makeEncoder().encode(SaveFixtures.latestExpected)
        let current = try keyPaths(of: encoded)
        let fixture = try keyPaths(of: Data(SaveFixtures.latest.json.utf8))
        XCTAssertEqual(current, fixture, """
            The save format changed. Bump SaveFile.currentVersion, add a migration \
            in SaveMigrator.standard and add a new fixture in SaveFixtures.
            """)
    }

    // MARK: Round trips and files

    func testRoundTripThroughFiles() throws {
        let store = FileSaveStore(directory: tempDirectory)
        let system = SaveSystem(store: store, deviceID: "device-a")
        var state = GameState.newGame(seed: 99)
        state.money = 777
        let file = system.makeFile(state: state, presentation: PresentationState(cameraCenter: Vec2(1, 2), cameraZoom: 2),
                                   previous: nil, now: Date(timeIntervalSince1970: 1_700_000_000))
        try system.write(file)

        guard case .loaded(let loaded, let fromBackup) = system.load() else {
            return XCTFail("Expected a loaded save")
        }
        XCTAssertFalse(fromBackup)
        XCTAssertEqual(loaded, file)
    }

    func testNoSaveMeansNewGame() {
        let system = SaveSystem(store: FileSaveStore(directory: tempDirectory), deviceID: "d")
        XCTAssertEqual(system.load(), .noSave)
    }

    func testRevisionIncrementsAndCreationDateIsKept() {
        let system = SaveSystem(store: MemorySaveStore(), deviceID: "d")
        let state = GameState.newGame(seed: 1)
        let first = system.makeFile(state: state, presentation: .init(), previous: nil, now: Date(timeIntervalSince1970: 100))
        let second = system.makeFile(state: state, presentation: .init(), previous: first, now: Date(timeIntervalSince1970: 200))
        XCTAssertEqual(first.revision, 1)
        XCTAssertEqual(second.revision, 2)
        XCTAssertEqual(second.createdAt, first.createdAt)
        XCTAssertEqual(second.savedAt, Date(timeIntervalSince1970: 200))
    }

    func testEachWriteKeepsThePreviousSaveAsBackup() throws {
        let store = FileSaveStore(directory: tempDirectory)
        try store.write(Data("first".utf8))
        try store.write(Data("second".utf8))
        XCTAssertEqual(try store.read(), Data("second".utf8))
        XCTAssertEqual(try store.readBackup(), Data("first".utf8))
    }

    func testCorruptSaveFallsBackToBackup() throws {
        let store = MemorySaveStore()
        let system = SaveSystem(store: store, deviceID: "d")
        let good = system.makeFile(state: .newGame(seed: 5), presentation: .init(), previous: nil, now: Date(timeIntervalSince1970: 10))
        try system.write(good)
        store.backup = store.main
        store.main = Data("{ this is not json".utf8)

        guard case .loaded(let loaded, let fromBackup) = system.load() else {
            return XCTFail("Expected recovery from backup")
        }
        XCTAssertTrue(fromBackup)
        XCTAssertEqual(loaded, good)
    }

    func testCorruptSaveWithoutBackupFails() {
        let store = MemorySaveStore()
        store.main = Data("[]".utf8)
        let system = SaveSystem(store: store, deviceID: "d")
        guard case .failed(.corrupt) = system.load() else {
            return XCTFail("Expected a corrupt error")
        }
    }

    func testSaveFromNewerGameVersionIsNeverReplacedByBackup() throws {
        let store = MemorySaveStore()
        let system = SaveSystem(store: store, deviceID: "d")
        try system.write(system.makeFile(state: .newGame(seed: 1), presentation: .init(), previous: nil, now: Date()))
        store.backup = store.main
        store.main = Data(#"{"version": 99, "state": {}}"#.utf8)

        XCTAssertEqual(system.load(), .failed(.newerVersion(found: 99, supported: SaveFile.currentVersion)))
    }

    func testLoneBackupIsRecovered() throws {
        let store = MemorySaveStore()
        let system = SaveSystem(store: store, deviceID: "d")
        try system.write(system.makeFile(state: .newGame(seed: 1), presentation: .init(), previous: nil, now: Date()))
        store.backup = store.main
        store.main = nil
        guard case .loaded(_, fromBackup: true) = system.load() else {
            return XCTFail("Expected backup recovery")
        }
    }

    func testQuarantineMovesFilesAside() throws {
        let store = FileSaveStore(directory: tempDirectory)
        try store.write(Data("a".utf8))
        try store.write(Data("b".utf8))
        try store.quarantine()
        XCTAssertNil(try store.read())
        XCTAssertNil(try store.readBackup())
        let files = try FileManager.default.contentsOfDirectory(atPath: tempDirectory.path)
        XCTAssertEqual(files.filter { $0.contains("corrupt") }.count, 2)
    }

    // MARK: Migrations

    func testMigrationsRunInOrder() throws {
        let migrator = SaveMigrator(currentVersion: 3, migrations: [
            1: { json in json["added"] = "hello" },
            2: { json in
                json["renamed"] = json["added"]
                json["added"] = nil
            },
        ])
        let migrated = try migrator.migrate(Data(#"{"version": 1}"#.utf8))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: migrated) as? [String: Any])
        XCTAssertEqual(json["version"] as? Int, 3)
        XCTAssertEqual(json["renamed"] as? String, "hello")
        XCTAssertNil(json["added"])
    }

    func testMissingMigrationIsAnError() {
        let migrator = SaveMigrator(currentVersion: 3, migrations: [1: { _ in }])
        XCTAssertThrowsError(try migrator.migrate(Data(#"{"version": 1}"#.utf8))) { error in
            XCTAssertEqual(error as? SaveError, .missingMigration(fromVersion: 2))
        }
    }

    func testCurrentVersionDataIsReturnedUntouched() throws {
        let data = Data(#"{"version": \#(SaveFile.currentVersion), "x": 0.1}"#.utf8)
        XCTAssertEqual(try SaveMigrator.standard.migrate(data), data)
    }

    // MARK: Helpers

    /// Sorted list of every key path in a JSON document, e.g. "state.truck.position.x".
    private func keyPaths(of data: Data) throws -> [String] {
        var paths: [String] = []
        func walk(_ value: Any, _ prefix: String) {
            if let dict = value as? [String: Any] {
                for (key, child) in dict {
                    let path = prefix.isEmpty ? key : "\(prefix).\(key)"
                    paths.append(path)
                    walk(child, path)
                }
            } else if let array = value as? [Any] {
                for child in array { walk(child, prefix + "[]") }
            }
        }
        walk(try JSONSerialization.jsonObject(with: data), "")
        return Array(Set(paths)).sorted()
    }
}
