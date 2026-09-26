import XCTest
@testable import AcresCore

final class WorldMapTests: XCTestCase {

    let map = HomeValleyMap.map

    func testHomeValleyDimensions() {
        XCTAssertEqual(map.width, 64)
        XCTAssertEqual(map.height, 64)
        XCTAssertEqual(map.chunkColumns, 4)
        XCTAssertEqual(map.chunkRows, 4)
        XCTAssertGreaterThan(map.objects.count, 300)
    }

    func testMapIsDeterministic() {
        let again = HomeValleyMap.build()
        XCTAssertEqual(again.objects, map.objects)
    }

    func testEveryObjectHasArt() {
        for kind in Set(map.objects.map(\.kind)) {
            XCTAssertNotNil(AssetManifest.assetName(forObjectKind: kind, season: .summer),
                            "No asset in the manifest for map object '\(kind)'")
        }
    }

    func testObjectsAreIndexedIntoTheirChunks() {
        var total = 0
        for cy in 0..<map.chunkRows {
            for cx in 0..<map.chunkColumns {
                let chunk = ChunkCoord(cx, cy)
                let rect = map.rect(of: chunk)
                for object in map.objects(in: chunk) {
                    XCTAssertTrue(rect.contains(object.position), "\(object.kind) at \(object.position) not in \(chunk)")
                    total += 1
                }
            }
        }
        // Every object sits inside the map, so all are indexed.
        XCTAssertEqual(total, map.objects.count)
    }

    func testChunksOverlappingClipsToTheMap() {
        XCTAssertEqual(map.chunks(overlapping: TileRect(minX: -40, minY: -40, maxX: -1, maxY: -1)), [])
        XCTAssertEqual(map.chunks(overlapping: TileRect(minX: 1, minY: 1, maxX: 2, maxY: 2)), [ChunkCoord(0, 0)])
        XCTAssertEqual(map.chunks(overlapping: TileRect(minX: -10, minY: -10, maxX: 200, maxY: 200)).count, 16)
        XCTAssertEqual(Set(map.chunks(overlapping: TileRect(minX: 15, minY: 15, maxX: 17, maxY: 17))),
                       [ChunkCoord(0, 0), ChunkCoord(1, 0), ChunkCoord(0, 1), ChunkCoord(1, 1)])
    }

    func testTerrainLandmarks() {
        XCTAssertEqual(map.terrain(at: TileCoord(containing: HomeValleyMap.truckParkingSpot)), .dirt, "truck parks in the yard")
        XCTAssertEqual(map.terrain(at: TileCoord(57, 5)), .asphalt, "county road")
        XCTAssertEqual(map.terrain(at: TileCoord(40, 22)), .gravel, "gravel road")
        XCTAssertEqual(map.terrain(at: TileCoord(5, 5)), .grass)
        // Outside the map the edge continues.
        XCTAssertEqual(map.terrain(at: TileCoord(57, -5)), .asphalt)
    }

    func testCoverageBlendsTerrain() {
        let grass = map.coverage(at: Vec2(5.5, 5.5))
        XCTAssertEqual(grass.grass, 1)
        let yard = map.coverage(at: Vec2(24.5, 33.5))
        XCTAssertEqual(yard.dirt, 1)
        // On a road edge coverage is partial.
        let edges = (0..<40).map { map.coverage(at: Vec2(54 + Double($0) * 0.1, 10)).asphalt }
        XCTAssertTrue(edges.contains { $0 > 0 && $0 < 1 })
    }

    func testNothingIsScatteredOntoTheFarmhouse() {
        let house = map.objects.first { $0.kind == "building_farmhouse_t0" }!
        let intruders = map.objects.filter {
            $0.kind.hasPrefix("tree_") && $0.position.distance(to: house.position) < 3
        }
        XCTAssertEqual(intruders, [])
    }

    func testNewGameTruckIsAtTheFarm() {
        XCTAssertTrue(HomeValleyMap.homeFarmArea.contains(GameState.newGame(seed: 1).truck.position))
    }
}

final class AssetManifestTests: XCTestCase {

    func testNamesAreUniqueAndSnakeCase() {
        var seen = Set<String>()
        for spec in AssetManifest.all {
            XCTAssertTrue(seen.insert(spec.name).inserted, "Duplicate asset \(spec.name)")
            let allowed = Set("abcdefghijklmnopqrstuvwxyz0123456789_")
            XCTAssertTrue(spec.name.allSatisfy { allowed.contains($0) }, "Asset name not snake_case: \(spec.name)")
            XCTAssertGreaterThan(spec.pixelWidth, 0)
            XCTAssertGreaterThan(spec.pixelHeight, 0)
            XCTAssertFalse(spec.notes.isEmpty)
        }
    }

    func testSeasonalResolution() {
        XCTAssertEqual(AssetManifest.assetName(forObjectKind: "tree_oak", season: .summer), "tree_oak_summer")
        XCTAssertEqual(AssetManifest.assetName(forObjectKind: "tree_stump", season: .winter), "tree_stump")
        XCTAssertNil(AssetManifest.assetName(forObjectKind: "no_such_thing", season: .spring))
    }

    func testEveryCropHasFiveStages() {
        for crop in AssetManifest.cropNames {
            for stage in 0...4 {
                XCTAssertNotNil(AssetManifest.spec(named: "crop_\(crop)_stage\(stage)"))
            }
        }
    }

    func testTruckHasSixteenDirections() {
        for dir in 0..<16 {
            let name = "vehicle_truck_old_dir" + (dir < 10 ? "0\(dir)" : "\(dir)")
            XCTAssertNotNil(AssetManifest.spec(named: name), name)
        }
    }

    func testGeneratedAssetDocIsUpToDate() throws {
        let docURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // AcresCoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // AcresCore
            .deletingLastPathComponent()  // Packages
            .deletingLastPathComponent()  // repo root
            .appendingPathComponent("docs/ASSETS.md")
        let onDisk = try String(contentsOf: docURL, encoding: .utf8)
        XCTAssertEqual(onDisk, AssetDocs.markdown(),
                       "docs/ASSETS.md is stale: run `swift run acres-tools assets > ../../docs/ASSETS.md` in Packages/AcresCore")
    }
}

final class DayNightCurveTests: XCTestCase {

    func testNoonIsNeutralAndNightIsBlue() {
        let noon = DayNightCurve.lighting(atHour: 12)
        XCTAssertGreaterThan(noon.tint.r, 0.97)
        XCTAssertGreaterThan(noon.tint.b, 0.95)
        XCTAssertEqual(noon.nightLights, 0)

        let night = DayNightCurve.lighting(atHour: 2)
        XCTAssertGreaterThan(night.tint.b, night.tint.r)
        XCTAssertEqual(night.nightLights, 1, accuracy: 1e-9)
    }

    func testEveningIsWarm() {
        let evening = DayNightCurve.lighting(atHour: 18)
        XCTAssertGreaterThan(evening.tint.r, evening.tint.b + 0.2)
    }

    func testCurveIsContinuousEverywhere() {
        var previous = DayNightCurve.lighting(atHour: 0)
        for step in 1...(24 * 60) {
            let current = DayNightCurve.lighting(atHour: Double(step) / 60)
            XCTAssertLessThan(abs(current.tint.r - previous.tint.r), 0.02, "jump at minute \(step)")
            XCTAssertLessThan(abs(current.tint.b - previous.tint.b), 0.02, "jump at minute \(step)")
            XCTAssertLessThan(abs(current.nightLights - previous.nightLights), 0.03, "jump at minute \(step)")
            previous = current
        }
    }
}
