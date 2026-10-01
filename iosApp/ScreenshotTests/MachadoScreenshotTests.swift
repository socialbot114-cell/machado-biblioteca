import XCTest

final class MachadoScreenshotTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments.append("--screenshot-capture")
        app.launch()
    }

    func testStoreScreenshots() throws {
        capture("01-inicio")

        let libraryTab = app.buttons["Biblioteca"].firstMatch
        XCTAssertTrue(libraryTab.waitForExistence(timeout: 15))
        libraryTab.tap()
        XCTAssertTrue(app.staticTexts["Biblioteca"].firstMatch.waitForExistence(timeout: 15))
        capture("02-biblioteca")

        app.buttons["Início"].firstMatch.tap()
        let domCasmurro = app.staticTexts["Dom Casmurro"].firstMatch
        XCTAssertTrue(domCasmurro.waitForExistence(timeout: 15))
        domCasmurro.tap()
        let startReading = app.buttons["Começar a ler"]
        XCTAssertTrue(startReading.waitForExistence(timeout: 15))
        capture("03-detalhe")

        startReading.tap()
        XCTAssertTrue(app.staticTexts["I"].firstMatch.waitForExistence(timeout: 30))
        turnPage(from: 0.9, to: 0.1, expecting: "Página 2 de 2")
        turnPage(from: 0.1, to: 0.9, expecting: "Página 1 de 2")
        capture("04-leitor")

        app.buttons["Fechar"].firstMatch.tap()
        let addFavorite = app.buttons["Adicionar aos favoritos"].firstMatch
        if addFavorite.waitForExistence(timeout: 10) {
            addFavorite.tap()
        } else {
            XCTAssertTrue(app.buttons["Remover dos favoritos"].firstMatch.waitForExistence(timeout: 5))
        }
        app.navigationBars.buttons.firstMatch.tap()

        let myLibraryTab = app.buttons["Minha biblioteca"].firstMatch
        XCTAssertTrue(myLibraryTab.waitForExistence(timeout: 10))
        myLibraryTab.tap()
        XCTAssertTrue(app.staticTexts["Favoritos"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Dom Casmurro"].firstMatch.waitForExistence(timeout: 10))
        capture("05-minha-biblioteca")

        let universeTab = app.buttons["Universo"].firstMatch
        XCTAssertTrue(universeTab.waitForExistence(timeout: 10))
        universeTab.tap()
        XCTAssertTrue(app.staticTexts["UNIVERSO MACHADO"].waitForExistence(timeout: 10))
        capture("06-universo")
    }

    private func turnPage(from startX: CGFloat, to endX: CGFloat, expecting label: String) {
        let pageLabel = app.staticTexts[label]
        for _ in 0..<3 {
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: startX, dy: 0.5))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: endX, dy: 0.5))
            start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .fast, thenHoldForDuration: 0)
            if pageLabel.waitForExistence(timeout: 5) { return }
        }
        XCTFail("Reader did not reach \(label)")
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
