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
        // Key-value defaults first: a bare flag in front of them would swallow the next key as its value,
        // which silently dropped -ApplePersistenceIgnoreState and restored a session with no windows.
        app.launchArguments = ["-AppleLanguages", "(en)", "-ApplePersistenceIgnoreState", "YES", "-UITestMode"]
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func launch() {
        app.launch()
        app.activate()
        // SwiftUI's window isn't always exposed through `app.windows` on macOS, so the seeded
        // sidebar row is what proves the main window opened and the bottles loaded.
        let loaded = element("bottleRow-Steam").waitForExistence(timeout: 15)
        // Include the accessibility tree so a CI failure shows what was on screen instead.
        XCTAssertTrue(loaded, "The main window should open with the seeded bottles:\n\(app.debugDescription)")
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

    func testFilePickerAcceptsWindowsPrograms() {
        launch()
        element("bottleRow-Steam").click()
        let run = element("runProgramButton")
        XCTAssertTrue(run.waitForExistence(timeout: 5))
        run.click()
        let panel = app.sheets.firstMatch
        XCTAssertTrue(panel.waitForExistence(timeout: 10), "An open panel should appear")

        // Go straight to the installer the seed put in /tmp; an upper-case .EXE is the hardest case.
        app.typeKey("g", modifierFlags: [.command, .shift])
        app.typeText("/tmp/BourbonUITestFiles/SETUP.EXE\r")

        let open = panel.buttons["Open"]
        XCTAssertTrue(open.waitForExistence(timeout: 5))
        let enabled = NSPredicate(format: "isEnabled == true")
        let selectable = expectation(for: enabled, evaluatedWith: open)
        wait(for: [selectable], timeout: 10)
        open.click()
        XCTAssertTrue(panel.waitForNonExistence(timeout: 10), "Choosing the program should close the panel")
    }
}

final class OnboardingUITests: XCTestCase {
    func testOnboardingFlowDownloadsWine() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-ApplePersistenceIgnoreState", "YES",
                               "-UITestMode", "-UITestOnboarding"]
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
