import XCTest
#if canImport(StreamEmpireCore)
@testable import StreamEmpireCore
#else
@testable import StreamEmpire
#endif

final class Phase31Tests: XCTestCase {
    func testTheLibraryHasThousandsOfTitles() {
        XCTAssertGreaterThan(ParodyLibrary.all.count, 3_500)
        for genre in Genre.allCases {
            XCTAssertGreaterThan(ParodyLibrary.byGenre[genre]?.count ?? 0, 150, "\(genre)")
        }
    }

    func testEveryNameIsUniqueAndSane() {
        let names = ParodyLibrary.all.map { $0.name.lowercased() }
        XCTAssertEqual(Set(names).count, names.count, "no duplicate names (case-insensitive)")
        XCTAssertTrue(ParodyLibrary.all.allSatisfy { !$0.name.isEmpty && !$0.name.contains("|") })
    }

    func testBothMoviesAndSeriesExistInEveryGenreThatNeedsThem() {
        for genre in [Genre.drama, .comedy, .action, .kids, .anime, .docs, .local] {
            let list = ParodyLibrary.byGenre[genre] ?? []
            XCTAssertTrue(list.contains { $0.kind == .movie }, "\(genre) movies")
            XCTAssertTrue(list.contains { $0.kind == .series }, "\(genre) series")
        }
    }

    func testLocalTitlesCarryTheirOwnLanguages() {
        let local = ParodyLibrary.byGenre[.local] ?? []
        let languages = Set(local.map(\.language))
        for language in [Language.spanish, .french, .german, .italian, .portuguese, .japanese, .korean, .hindi, .turkish] {
            XCTAssertTrue(languages.contains(language), "\(language)")
        }
        XCTAssertGreaterThan(languages.count, 12)
    }

    func testLongGamesRarelyRepeatATitle() {
        var rng = SeededRNG(seed: 77)
        var taken = Set<String>()
        var repeats = 0
        for i in 0..<1_500 {
            let t = TitleGenerator.generate(id: i, rng: &rng, avoiding: taken)
            if t.name.range(of: #" [IVX]+$"#, options: .regularExpression) != nil { repeats += 1 }
            taken.insert(t.name)
        }
        XCTAssertEqual(taken.count, 1_500)
        XCTAssertLessThan(repeats, 150, "sequel-numbered repeats stay rare")
    }
}
