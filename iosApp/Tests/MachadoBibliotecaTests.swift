import XCTest
@testable import MachadoBiblioteca

final class MachadoBibliotecaTests: XCTestCase {
    func testCatalogContainsThirtyIntegralWorks() throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "catalog", withExtension: "json"))
        let data = try Data(contentsOf: url)
        let entries = try JSONDecoder().decode([CatalogFixture].self, from: data)
        XCTAssertEqual(entries.count, 30)
        XCTAssertEqual(entries.filter { $0.status == "integral" }.count, 30)
        XCTAssertEqual(Set(entries.map(\.id)).count, 30)
    }

    func testOfflineQuoteRoundTripPreservesOrigin() throws {
        let quote = Quote(id: "dom-0-2", workID: "dom", workTitle: "Dom Casmurro", chapterTitle: "Capítulo II", paragraphIndex: 2, text: "Uma citação de teste.")
        let data = try JSONEncoder().encode(quote)
        let decoded = try JSONDecoder().decode(Quote.self, from: data)
        XCTAssertEqual(decoded, quote)
        XCTAssertEqual(decoded.chapterTitle, "Capítulo II")
        XCTAssertEqual(decoded.paragraphIndex, 2)
    }

    func testUniverseHasCharactersAndTimeline() {
        XCTAssertGreaterThanOrEqual(LibraryViewModel.defaultCharacters.count, 6)
        XCTAssertEqual(LibraryViewModel.defaultTimeline.first?.year, 1839)
        XCTAssertEqual(LibraryViewModel.defaultTimeline.last?.year, 1908)
    }

    func testReaderThemesArePersistable() throws {
        for theme in ReaderTheme.allCases {
            let data = try JSONEncoder().encode(theme)
            XCTAssertEqual(try JSONDecoder().decode(ReaderTheme.self, from: data), theme)
        }
    }
}

private struct CatalogFixture: Decodable {
    let id: String
    let status: String
}
