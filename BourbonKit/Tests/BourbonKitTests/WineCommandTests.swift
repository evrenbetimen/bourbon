import XCTest
@testable import BourbonKit

final class WineCommandTests: XCTestCase {
    let factory = WineCommandFactory(runtime: Fixtures.runtime)

    func testLaunchUsesStartUnixWithSplitArguments() throws {
        var bottle = Fixtures.bottle()
        let program = Program(url: URL(fileURLWithPath: "/bottles/test/drive_c/Games/My Game.exe"),
                              relativePath: "drive_c/Games/My Game.exe")
        bottle.settings.programSettings[program.relativePath] = ProgramSettings(arguments: #"-w 1280 --title "Big Window""#)

        let command = try factory.launch(program, in: bottle)
        XCTAssertEqual(command.executable.path, "/wine/bin/wine64")
        XCTAssertEqual(command.arguments, ["start", "/unix", "/bottles/test/drive_c/Games/My Game.exe",
                                           "-w", "1280", "--title", "Big Window"])
        XCTAssertEqual(command.workingDirectory?.path, "/bottles/test/drive_c/Games")
        XCTAssertEqual(command.environment["WINEPREFIX"], "/bottles/test")
    }

    func testMSIGoesThroughMsiexec() throws {
        let command = try factory.install(packageAt: URL(fileURLWithPath: "/tmp/Setup.MSI"), in: Fixtures.bottle())
        XCTAssertEqual(command.arguments, ["msiexec", "/i", "/tmp/Setup.MSI"])
    }

    func testExeInstallerIsLaunchedDirectly() throws {
        let command = try factory.install(packageAt: URL(fileURLWithPath: "/tmp/setup.exe"), in: Fixtures.bottle())
        XCTAssertEqual(Array(command.arguments.prefix(3)), ["start", "/unix", "/tmp/setup.exe"])
    }

    func testWindowsVersionCommand() throws {
        let command = try factory.setWindowsVersion(.win11, in: Fixtures.bottle())
        XCTAssertEqual(command.arguments, ["winecfg", "-v", "win11"])
    }

    func testRetinaModeWritesDriverFlagAndDPI() throws {
        let on = try factory.setRetinaMode(true, in: Fixtures.bottle())
        XCTAssertEqual(on.map(\.arguments), [
            ["reg", "add", #"HKCU\Software\Wine\Mac Driver"#, "/v", "RetinaMode", "/t", "REG_SZ", "/d", "y", "/f"],
            ["reg", "add", #"HKCU\Control Panel\Desktop"#, "/v", "LogPixels", "/t", "REG_DWORD", "/d", "192", "/f"]
        ])
        let off = try factory.setRetinaMode(false, in: Fixtures.bottle())
        XCTAssertEqual(off.map { $0.arguments[8] }, ["n", "96"])
    }

    func testKillAllUsesWineserver() throws {
        let command = try factory.killAll(in: Fixtures.bottle())
        XCTAssertEqual(command.executable.path, "/wine/bin/wineserver")
        XCTAssertEqual(command.arguments, ["-k"])
    }

    func testToolsMapToWinePrograms() throws {
        XCTAssertEqual(try factory.open(.registryEditor, in: Fixtures.bottle()).arguments, ["regedit"])
        XCTAssertEqual(try factory.open(.commandPrompt, in: Fixtures.bottle()).arguments, ["wineconsole", "cmd"])
        XCTAssertEqual(Set(WineTool.allCases.map(\.symbol)).count, WineTool.allCases.count)
    }

    func testWinetricksPointsAtRuntime() throws {
        let script = URL(fileURLWithPath: "/support/winetricks")
        let command = try factory.winetricks("vcrun2022", script: script, in: Fixtures.bottle())
        XCTAssertEqual(command.executable, script)
        XCTAssertEqual(command.arguments, ["--unattended", "vcrun2022"])
        XCTAssertEqual(command.environment["WINE"], "/wine/bin/wine64")
        XCTAssertEqual(command.environment["WINESERVER"], "/wine/bin/wineserver")
    }

    func testShellLineQuotesEverything() {
        let command = WineCommand(
            executable: URL(fileURLWithPath: "/wine/bin/wine64"),
            arguments: ["start", "/unix", "/Users/me/My Game.exe"],
            environment: ["WINEPREFIX": "/Users/me/Bottle One", "A": "1"],
            workingDirectory: URL(fileURLWithPath: "/Users/me")
        )
        XCTAssertEqual(command.shellLine,
                       "cd /Users/me && A=1 WINEPREFIX='/Users/me/Bottle One' /wine/bin/wine64 start /unix '/Users/me/My Game.exe'")
    }
}
