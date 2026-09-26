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

    /// All fixtures, oldest first.
    static let all: [(version: Int, json: String)] = [(1, v1)]
    static var latest: (version: Int, json: String) { all.last! }

    /// What `v1` must decode to.
    static let v1Expected = SaveFile(
        version: 1,
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
            stats: PlayStats(playSeconds: 3000, offlineSeconds: 7200, returns: 2)
        ),
        presentation: PresentationState(cameraCenter: Vec2(26, 32.5), cameraZoom: 1.5)
    )
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

    func testVersion1FixtureDecodesExactly() throws {
        let system = SaveSystem(store: MemorySaveStore(), deviceID: "test")
        let file = try system.decode(Data(SaveFixtures.v1.utf8)).get()
        XCTAssertEqual(file, SaveFixtures.v1Expected)
    }

    func testCurrentFormatMatchesLatestFixture() throws {
        XCTAssertEqual(SaveFixtures.latest.version, SaveFile.currentVersion,
                       "Add a fixture for the new save version")
        // Encode a value that uses every field and compare the *shape* (key paths)
        // with the latest fixture. Adding/removing/renaming a stored property
        // changes the shape: that requires a version bump + migration.
        let encoded = try SaveCoding.makeEncoder().encode(SaveFixtures.v1Expected)
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
        let data = Data(#"{"version": 1, "x": 0.1}"#.utf8)
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
