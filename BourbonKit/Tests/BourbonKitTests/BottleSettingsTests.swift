import XCTest
@testable import BourbonKit

final class BottleSettingsTests: XCTestCase {
    func testDefaultsAreSensible() {
        let settings = BottleSettings(name: "Games")
        XCTAssertEqual(settings.windowsVersion, .win10)
        XCTAssertEqual(settings.syncMode, .msync)
        XCTAssertFalse(settings.dxvkEnabled)
        XCTAssertEqual(settings.fileVersion, BottleSettings.currentFileVersion)
    }

    func testRoundTripsThroughPropertyList() throws {
        var settings = BottleSettings(name: "Steam", tint: .ocean, windowsVersion: .win11, dxvkEnabled: true,
                                      dxvkHUD: .partial, environment: ["FOO": "bar"],
                                      createdAt: Date(timeIntervalSince1970: 1000))
        settings.togglePin(name: "Steam", relativePath: "drive_c/Steam/steam.exe")
        settings.programSettings["drive_c/Steam/steam.exe"] = ProgramSettings(arguments: "-silent", locale: "ja_JP.UTF-8")

        let decoded = try BottleSettings.decode(from: settings.encoded())
        XCTAssertEqual(decoded, settings)
    }

    func testDecodesMinimalLegacyFile() throws {
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0"><dict><key>name</key><string>Old Bottle</string></dict></plist>
        """
        let settings = try BottleSettings.decode(from: Data(plist.utf8))
        XCTAssertEqual(settings.name, "Old Bottle")
        XCTAssertEqual(settings.windowsVersion, .win10)
        XCTAssertEqual(settings.syncMode, .msync)
        XCTAssertTrue(settings.pinnedPrograms.isEmpty)
    }

    func testUnknownEnumValuesFallBackToDefaults() throws {
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plist version="1.0"><dict>
          <key>name</key><string>Future</string>
          <key>windowsVersion</key><string>win12</string>
          <key>tint</key><string>plaid</string>
          <key>syncMode</key><string>fsync</string>
        </dict></plist>
        """
        let settings = try BottleSettings.decode(from: Data(plist.utf8))
        XCTAssertEqual(settings.windowsVersion, .win10)
        XCTAssertEqual(settings.tint, .amber)
        XCTAssertEqual(settings.syncMode, .msync)
    }

    func testTogglePinAddsThenRemoves() {
        var settings = BottleSettings(name: "B")
        settings.togglePin(name: "App", relativePath: "drive_c/app.exe")
        XCTAssertTrue(settings.isPinned("drive_c/app.exe"))
        settings.togglePin(name: "App", relativePath: "drive_c/app.exe")
        XCTAssertFalse(settings.isPinned("drive_c/app.exe"))
    }

    func testHighlightsSummariseOptions() {
        let plain = BottleSettings(name: "B", syncMode: .none)
        XCTAssertEqual(plain.highlights, ["Windows 10"])

        let tuned = BottleSettings(name: "B", windowsVersion: .win7, syncMode: .esync, dxvkEnabled: true,
                                   metalHUD: true, retinaMode: true)
        XCTAssertEqual(tuned.highlights, ["Windows 7", "ESync", "DXVK", "Retina", "Metal HUD"])
    }

    func testWindowsVersionsAreOrderedAndComplete() {
        XCTAssertEqual(WindowsVersion.allCases.first, .winXP)
        XCTAssertEqual(WindowsVersion.allCases.last, .newest)
        let builds = WindowsVersion.allCases.map(\.buildNumber)
        XCTAssertEqual(builds, builds.sorted(), "Build numbers should increase with each release")
        XCTAssertEqual(Set(WindowsVersion.allCases.map(\.displayName)).count, WindowsVersion.allCases.count)
    }

    func testDXVKHUDValues() {
        XCTAssertNil(DXVKHUD.off.environmentValue)
        XCTAssertEqual(DXVKHUD.fps.environmentValue, "fps")
        XCTAssertEqual(DXVKHUD.full.environmentValue, "full")
    }
}
