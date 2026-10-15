import XCTest
@testable import BourbonKit

final class ProgramScannerTests: XCTestCase {
    func testFindsProgramsAndSkipsNoise() throws {
        let directory = try TemporaryDirectory()
        let bottle = Bottle(url: directory.url, settings: BottleSettings(name: "Scan"))
        try directory.touch("drive_c/Program Files/Steam/steam.exe")
        try directory.touch("drive_c/Program Files/Steam/uninstall.exe")
        try directory.touch("drive_c/Program Files (x86)/Game/Game.EXE")
        try directory.touch("drive_c/Program Files (x86)/Game/UnityCrashHandler64.exe")
        try directory.touch("drive_c/Program Files (x86)/Game/readme.txt")
        try directory.touch("drive_c/windows/system32/notepad.exe")
        try directory.touch("drive_c/ProgramData/Microsoft/Windows/thing.exe")

        let programs = ProgramScanner().scan(bottle)
        XCTAssertEqual(programs.map(\.name), ["Game", "steam"])
        XCTAssertEqual(programs.first?.relativePath, "drive_c/Program Files (x86)/Game/Game.EXE")
        XCTAssertEqual(programs.last?.directory.lastPathComponent, "Steam")
    }

    func testHonoursHiddenPrograms() throws {
        let directory = try TemporaryDirectory()
        var settings = BottleSettings(name: "Scan")
        settings.hiddenPrograms = ["drive_c/a/hidden.exe"]
        let bottle = Bottle(url: directory.url, settings: settings)
        try directory.touch("drive_c/a/hidden.exe")
        try directory.touch("drive_c/a/visible.exe")
        XCTAssertEqual(ProgramScanner().scan(bottle).map(\.name), ["visible"])
    }

    func testRespectsMaxDepth() throws {
        let directory = try TemporaryDirectory()
        let bottle = Bottle(url: directory.url, settings: BottleSettings(name: "Deep"))
        try directory.touch("drive_c/1/shallow.exe")
        try directory.touch("drive_c/1/2/3/4/deep.exe")
        XCTAssertEqual(ProgramScanner(maxDepth: 2).scan(bottle).map(\.name), ["shallow"])
        XCTAssertEqual(ProgramScanner(maxDepth: 10).scan(bottle).map(\.name), ["deep", "shallow"])
    }

    func testDoesNotFollowSymlinkedFolders() throws {
        let directory = try TemporaryDirectory()
        let outside = try TemporaryDirectory()
        try outside.touch("Desktop/outside.exe")
        let bottle = Bottle(url: directory.url, settings: BottleSettings(name: "Links"))
        try FileManager.default.createDirectory(at: bottle.driveC.appendingPathComponent("users/me"),
                                                withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: bottle.driveC.appendingPathComponent("users/me/Desktop"),
                                                   withDestinationURL: outside.url.appendingPathComponent("Desktop"))
        XCTAssertEqual(ProgramScanner().scan(bottle), [])
    }

    func testEmptyBottle() throws {
        let directory = try TemporaryDirectory()
        XCTAssertEqual(ProgramScanner().scan(Bottle(url: directory.url, settings: BottleSettings(name: "E"))), [])
    }

    func testNoiseDetection() {
        XCTAssertTrue(ProgramScanner.isNoise("unins000.exe"))
        XCTAssertTrue(ProgramScanner.isNoise("VC_redist.x64.exe"))
        XCTAssertFalse(ProgramScanner.isNoise("Photoshop.exe"))
    }
}
