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

        let libraryTab = app.buttons["Biblioteca"]
        XCTAssertTrue(libraryTab.waitForExistence(timeout: 15))
        libraryTab.tap()
        XCTAssertTrue(app.staticTexts["Biblioteca"].firstMatch.waitForExistence(timeout: 15))
        capture("02-biblioteca")

        app.buttons["Início"].tap()
        let domCasmurro = app.staticTexts["Dom Casmurro"].firstMatch
        XCTAssertTrue(domCasmurro.waitForExistence(timeout: 15))
        domCasmurro.tap()
        let startReading = app.buttons["Começar a ler"]
        XCTAssertTrue(startReading.waitForExistence(timeout: 15))
        capture("03-detalhe")

        startReading.tap()
        XCTAssertTrue(app.staticTexts["I"].firstMatch.waitForExistence(timeout: 30))
        capture("04-leitor")
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
