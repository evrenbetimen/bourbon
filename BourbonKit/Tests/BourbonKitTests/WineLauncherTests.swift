import XCTest
@testable import BourbonKit

final class WineLauncherTests: XCTestCase {
    func testPrepareInitialisesPrefixAndAppliesOptions() async throws {
        let runner = RecordingRunner()
        let launcher = WineLauncher(runtime: Fixtures.runtime, runner: runner)
        try await launcher.prepare(Fixtures.bottle {
            $0.windowsVersion = .win7
            $0.retinaMode = true
        })
        XCTAssertEqual(runner.commands.map { $0.arguments.first }, ["wineboot", "winecfg", "reg", "reg"])
        XCTAssertEqual(runner.commands[1].arguments, ["winecfg", "-v", "win7"])
    }

    func testPrepareStopsOnFailure() async {
        let runner = RecordingRunner()
        runner.results = [ProcessResult(exitCode: 3, output: "line1\nboom")]
        let launcher = WineLauncher(runtime: Fixtures.runtime, runner: runner)
        do {
            try await launcher.prepare(Fixtures.bottle())
            XCTFail("Expected an error")
        } catch let error as ProcessRunnerError {
            guard case .failed(_, let code, _) = error else { return XCTFail("Wrong error") }
            XCTAssertEqual(code, 3)
            XCTAssertTrue(error.localizedDescription.contains("boom"))
        } catch {
            XCTFail("Unexpected error \(error)")
        }
        XCTAssertEqual(runner.commands.count, 1)
    }

    func testApplyOnlyRunsWhatChanged() async throws {
        let runner = RecordingRunner()
        let launcher = WineLauncher(runtime: Fixtures.runtime, runner: runner)
        let bottle = Fixtures.bottle()

        try await launcher.apply(changesFrom: bottle.settings, to: bottle)
        XCTAssertTrue(runner.commands.isEmpty)

        var changed = bottle
        changed.settings.retinaMode = true
        try await launcher.apply(changesFrom: bottle.settings, to: changed)
        XCTAssertEqual(runner.commands.count, 2)

        var newer = changed
        newer.settings.windowsVersion = .win11
        try await launcher.apply(changesFrom: changed.settings, to: newer)
        XCTAssertEqual(runner.commands.last?.arguments, ["winecfg", "-v", "win11"])
    }

    func testLaunchRecordsTimestamps() async throws {
        let runner = RecordingRunner()
        let launcher = WineLauncher(runtime: Fixtures.runtime, runner: runner)
        let program = Program(url: URL(fileURLWithPath: "/bottles/test/drive_c/app.exe"), relativePath: "drive_c/app.exe")
        let date = Date(timeIntervalSince1970: 5000)

        let updated = try await launcher.launch(program, in: Fixtures.bottle(), at: date)
        XCTAssertEqual(updated.settings.lastLaunchedAt, date)
        XCTAssertEqual(updated.settings.programSettings["drive_c/app.exe"]?.lastLaunchedAt, date)
        XCTAssertEqual(runner.commands.first.map { Array($0.arguments.prefix(2)) }, ["start", "/unix"])
    }

    func testDetectVersion() async {
        let runner = RecordingRunner()
        runner.results = [ProcessResult(exitCode: 0, output: "wine-9.21\n")]
        let launcher = WineLauncher(runtime: Fixtures.runtime, runner: runner)
        let version = await launcher.detectVersion()
        XCTAssertEqual(version, SemanticVersion(9, 21))
        XCTAssertEqual(runner.commands.first?.arguments, ["--version"])
    }

    func testSystemRunnerCapturesOutputAndExitCode() async throws {
        let directory = try TemporaryDirectory()
        let runner = SystemProcessRunner(logDirectory: directory.url.appendingPathComponent("Logs"))
        let command = WineCommand(executable: URL(fileURLWithPath: "/bin/sh"),
                                  arguments: ["-c", "echo \"$GREETING\"; exit 4"],
                                  environment: ["GREETING": "merhaba"])
        let result = try await runner.run(command)
        XCTAssertEqual(result.exitCode, 4)
        XCTAssertEqual(result.output.trimmingCharacters(in: .whitespacesAndNewlines), "merhaba")

        let logs = try FileManager.default.contentsOfDirectory(atPath: directory.url.appendingPathComponent("Logs").path)
        XCTAssertEqual(logs.count, 1)
        let log = try String(contentsOf: directory.url.appendingPathComponent("Logs").appendingPathComponent(logs[0]),
                             encoding: .utf8)
        XCTAssertTrue(log.contains("merhaba"))
    }

    func testSystemRunnerThrowsForMissingExecutable() async {
        let runner = SystemProcessRunner()
        do {
            _ = try await runner.run(WineCommand(executable: URL(fileURLWithPath: "/nonexistent/wine"), arguments: []))
            XCTFail("Expected an error")
        } catch {}
    }

    func testLogFileNames() {
        let date = Date(timeIntervalSince1970: 0)
        let launch = WineCommand(executable: URL(fileURLWithPath: "/w/wine64"),
                                 arguments: ["start", "/unix", "/b/drive_c/My Game.exe"])
        XCTAssertEqual(LogFiles.name(for: launch, at: date), "1970-01-01T00-00-00-my-game.log")
        let tool = WineCommand(executable: URL(fileURLWithPath: "/w/wine64"), arguments: ["regedit"])
        XCTAssertEqual(LogFiles.name(for: tool, at: date), "1970-01-01T00-00-00-regedit.log")
    }
}
