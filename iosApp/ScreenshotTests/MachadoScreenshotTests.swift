import XCTest

final class MachadoScreenshotTests: XCTestCase {
    private var app: XCUIApplication!
    private var outputDirectory: URL!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments.append("--screenshot-capture")
        app.launch()

        let path = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"]
            ?? NSTemporaryDirectory().appending("machado-screenshots")
        outputDirectory = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
    }

    func testStoreScreenshots() throws {
        try capture("01-inicio")

        let libraryTab = app.tabBars.buttons["Biblioteca"]
        XCTAssertTrue(libraryTab.waitForExistence(timeout: 15))
        libraryTab.tap()
        XCTAssertTrue(app.staticTexts["Biblioteca"].firstMatch.waitForExistence(timeout: 15))
        try capture("02-biblioteca")

        app.tabBars.buttons["Início"].tap()
        let domCasmurro = app.staticTexts["Dom Casmurro"].firstMatch
        XCTAssertTrue(domCasmurro.waitForExistence(timeout: 15))
        domCasmurro.tap()
        let startReading = app.buttons["Começar a ler"]
        XCTAssertTrue(startReading.waitForExistence(timeout: 15))
        try capture("03-detalhe")

        startReading.tap()
        XCTAssertTrue(app.staticTexts["I"].firstMatch.waitForExistence(timeout: 30))
        try capture("04-leitor")
    }

    private func capture(_ name: String) throws {
        let screenshot = XCUIScreen.main.screenshot()
        try screenshot.pngRepresentation.write(to: outputDirectory.appendingPathComponent("\(name).png"))
    }
}
