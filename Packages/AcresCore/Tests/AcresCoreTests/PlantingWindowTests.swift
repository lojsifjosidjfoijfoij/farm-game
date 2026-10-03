import XCTest
@testable import AcresCore

/// When seeds can go in the ground: the seed shop warns about the rest.
final class PlantingWindowTests: XCTestCase {
    let days = Balance.standard.daysPerSeason

    private func date(_ season: Season, day: Int) -> CalendarDate {
        CalendarDate(dayIndex: season.rawValue * days + day - 1, daysPerSeason: days)
    }

    func testCropsInSeasonCountTheDaysLeft() {
        let carrot = CropCatalog.crop("carrot")!  // spring and autumn
        XCTAssertEqual(carrot.plantingWindow(on: date(.spring, day: 1), daysPerSeason: days), .now(daysLeft: days))
        XCTAssertEqual(carrot.plantingWindow(on: date(.spring, day: days), daysPerSeason: days), .now(daysLeft: 1), "the last day")
        let wheat = CropCatalog.crop("wheat")!  // spring, summer and autumn in a row
        XCTAssertEqual(wheat.plantingWindow(on: date(.spring, day: 1), daysPerSeason: days), .now(daysLeft: 3 * days))
    }

    func testCropsOutOfSeasonSayWhenTheirSeasonComes() {
        let carrot = CropCatalog.crop("carrot")!
        XCTAssertEqual(carrot.plantingWindow(on: date(.summer, day: 3), daysPerSeason: days), .later(.autumn, inDays: days - 2))
        XCTAssertEqual(carrot.plantingWindow(on: date(.summer, day: days), daysPerSeason: days), .later(.autumn, inDays: 1))
        let pumpkin = CropCatalog.crop("pumpkin")!  // autumn only
        XCTAssertEqual(pumpkin.plantingWindow(on: date(.winter, day: 1), daysPerSeason: days), .later(.autumn, inDays: 3 * days))
        // Every crop is plantable some time.
        for crop in CropCatalog.all {
            XCTAssertFalse(crop.seasons.isEmpty, crop.id)
        }
    }
}
