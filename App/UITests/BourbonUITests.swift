//
//  BourbonUITests.swift
//  BourbonUITests
//
//  End-to-end checks of the main flows. The app runs with `-UITestMode`, which seeds two
//  bottles ("Steam" and "Office") in a temporary folder and simulates Wine.
//

import XCTest

final class BourbonUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITestMode", "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
                               "-ApplePersistenceIgnoreState", "YES"]
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func launch() {
        app.launch()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10), "The main window should open")
        XCTAssertTrue(element("bottleRow-Steam").waitForExistence(timeout: 10), "Seeded bottles should load")
    }

    func testSidebarListsSeededBottles() {
        launch()
        XCTAssertTrue(element("bottleRow-Office").exists)
        XCTAssertTrue(element("newBottleButton").exists)
        XCTAssertTrue(element("runtimeStatus").exists)
    }

    func testSelectingBottleShowsItsLibrary() {
        launch()
        element("bottleRow-Steam").click()
        XCTAssertTrue(element("programCard-HollowLands").waitForExistence(timeout: 10))
        XCTAssertTrue(element("programCard-steam").exists)
        XCTAssertFalse(element("programCard-unins000").exists, "Uninstallers are hidden from the library")

        element("bottleRow-Office").click()
        XCTAssertTrue(element("programCard-notepad++").waitForExistence(timeout: 10))
        XCTAssertFalse(element("programCard-steam").exists)
    }

    func testCreatingABottle() {
        launch()
        element("newBottleButton").click()

        let name = element("bottleNameField")
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        let create = element("createBottleButton")
        XCTAssertFalse(create.isEnabled, "An empty name can't be submitted")

        name.click()
        name.typeText("Retro Games")
        XCTAssertTrue(create.isEnabled)
        create.click()

        XCTAssertTrue(element("bottleRow-Retro Games").waitForExistence(timeout: 10))
        XCTAssertFalse(name.exists, "The sheet closes after creating")
    }

    func testInvalidBottleNameShowsError() {
        launch()
        element("newBottleButton").click()
        let name = element("bottleNameField")
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.click()
        name.typeText("bad/name")
        XCTAssertTrue(element("bottleNameError").waitForExistence(timeout: 5))
        XCTAssertFalse(element("createBottleButton").isEnabled)
        app.typeKey(.escape, modifierFlags: [])
    }

    func testInspectorTogglesPersistAcrossSelection() {
        launch()
        element("bottleRow-Office").click()
        let dxvk = element("dxvkToggle")
        if !dxvk.waitForExistence(timeout: 5) {
            element("inspectorToggle").click()
        }
        XCTAssertTrue(dxvk.waitForExistence(timeout: 5))
        let before = dxvk.value as? Int
        dxvk.click()

        element("bottleRow-Steam").click()
        XCTAssertTrue(element("programCard-steam").waitForExistence(timeout: 10))
        element("bottleRow-Office").click()
        XCTAssertTrue(dxvk.waitForExistence(timeout: 5))
        XCTAssertNotEqual(dxvk.value as? Int, before, "The DXVK setting should be saved")
    }

    func testRunProgramButtonOpensFilePicker() {
        launch()
        element("bottleRow-Steam").click()
        let run = element("runProgramButton")
        XCTAssertTrue(run.waitForExistence(timeout: 5))
        run.click()
        XCTAssertTrue(app.sheets.firstMatch.waitForExistence(timeout: 10) || app.dialogs.firstMatch.exists,
                      "An open panel should appear")
        app.typeKey(.escape, modifierFlags: [])
    }
}

final class OnboardingUITests: XCTestCase {
    func testOnboardingFlowDownloadsWine() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMode", "-UITestOnboarding", "-AppleLanguages", "(en)",
                               "-ApplePersistenceIgnoreState", "YES"]
        app.launch()
        defer { app.terminate() }

        func element(_ identifier: String) -> XCUIElement {
            app.descendants(matching: .any).matching(identifier: identifier).firstMatch
        }

        XCTAssertTrue(element("onboardingTitle").waitForExistence(timeout: 10))
        element("onboardingContinue").click()

        let download = element("downloadWineButton")
        XCTAssertTrue(download.waitForExistence(timeout: 5))
        download.click()

        let finish = element("finishOnboardingButton")
        XCTAssertTrue(finish.waitForExistence(timeout: 15), "The simulated download should finish")
        finish.click()

        XCTAssertTrue(element("bottleRow-Steam").waitForExistence(timeout: 10))
        XCTAssertFalse(element("onboardingTitle").exists)
    }
}
