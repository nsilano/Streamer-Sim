import XCTest
#if canImport(StreamEmpireCore)
@testable import StreamEmpireCore
#else
@testable import StreamEmpire
#endif

final class Phase30Tests: XCTestCase {
    private func newState() -> GameState {
        var s = GameState.newGame(startCountry: "DE", companyName: "Test Co", seed: 6)
        s.eventsEnabled = false
        s.finances.cash = 1e9
        return s
    }

    private func titles(_ n: Int, language: Language = .english) -> [Title] {
        (0..<n).map {
            Title(id: 100 + $0, name: "T\($0)", kind: $0 % 2 == 0 ? .movie : .series, genre: .drama, language: language,
                  quality: 40 + $0, popularity: 50, ageWeeks: 10, isOriginal: true, license: nil, weeksRemaining: nil,
                  listingWeeksLeft: 0)
        }
    }

    func testSubtitleTheWholeCatalogInOneTap() throws {
        var s = newState()
        s.catalog = titles(30) + titles(2, language: .german).map { var t = $0; t.id += 500; return t }
        let targets = s.localizationTargets(code: "DE", dub: false)
        XCTAssertEqual(targets.count, 30, "titles already in German are skipped")
        let price = s.bulkLocalizePrice(code: "DE", dub: false)
        let cash = s.finances.cash
        XCTAssertEqual(try s.bulkLocalize(code: "DE", dub: false), 30)
        XCTAssertEqual(s.finances.cash, cash - price, accuracy: 0.01)
        XCTAssertEqual(s.finances.ledger.localization, price, accuracy: 0.01)
        XCTAssertTrue(s.catalog.filter { $0.language == .english }.allSatisfy { $0.subtitles.contains(.german) })
        XCTAssertThrowsError(try s.bulkLocalize(code: "DE", dub: false), "nothing left")
    }

    func testDubTheTopTitlesFirst() throws {
        var s = newState()
        s.catalog = titles(30)
        XCTAssertEqual(try s.bulkLocalize(code: "DE", dub: true, limit: 20), 20)
        let dubbed = s.catalog.filter { $0.dubs.contains(.german) }
        let undubbed = s.catalog.filter { !$0.dubs.contains(.german) }
        XCTAssertEqual(dubbed.count, 20)
        XCTAssertGreaterThanOrEqual(dubbed.map(\.quality).min()!, undubbed.map(\.quality).max()!, "best fit first")
        XCTAssertTrue(s.localizationTargets(code: "DE", dub: false).allSatisfy { !$0.dubs.contains(.german) },
                      "dubbed titles don't need subtitles too")
    }

    func testLocalizingRaisesAppeal() throws {
        var s = newState()
        s.catalog = titles(10)
        let de = CountryData.country("DE")!
        let before = Formulas.catalogAppeal(s.catalog, in: de)
        try s.bulkLocalize(code: "DE", dub: true)
        XCTAssertGreaterThan(Formulas.catalogAppeal(s.catalog, in: de), before)
    }

    func testBulkNeedsCash() {
        var s = newState()
        s.catalog = titles(10)
        s.finances.cash = 0
        XCTAssertThrowsError(try s.bulkLocalize(code: "DE", dub: false))
    }

    func testYouCanPickExactlyWhichTitlesToDub() throws {
        var s = newState()
        s.catalog = titles(10)
        let keep: Set<Int> = [100, 105]
        let cash = s.finances.cash
        XCTAssertEqual(try s.bulkLocalize(code: "DE", dub: true, only: keep), 2)
        XCTAssertEqual(Set(s.catalog.filter { $0.dubs.contains(.german) }.map(\.id)), keep)
        let expected = s.catalog.filter { keep.contains($0.id) }.reduce(0) { $0 + s.localizationPrice(kind: $1.kind, dub: true) }
        XCTAssertEqual(s.finances.cash, cash - expected, accuracy: 0.01)
        XCTAssertThrowsError(try s.bulkLocalize(code: "DE", dub: true, only: []), "nothing chosen")
    }
}
