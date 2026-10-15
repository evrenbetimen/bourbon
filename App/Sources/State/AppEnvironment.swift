//
//  AppEnvironment.swift
//  Bourbon
//

import BourbonKit
import Foundation

/// Where Bourbon keeps its files, and whether it runs against real Wine or a UI-test sandbox.
struct AppEnvironment {
    enum Mode: Equatable {
        case live
        /// Seeded bottles, a fake runtime and no real processes. Used by the UI tests.
        case uiTest(showOnboarding: Bool)
    }

    let mode: Mode
    let supportDirectory: URL

    var bottlesRoot: URL { supportDirectory.appendingPathComponent("Bottles", isDirectory: true) }
    var runtimesRoot: URL { supportDirectory.appendingPathComponent("Runtimes", isDirectory: true) }
    var logsDirectory: URL { supportDirectory.appendingPathComponent("Logs", isDirectory: true) }
    var winetricksScript: URL { supportDirectory.appendingPathComponent("winetricks") }

    var isUITesting: Bool { mode != .live }

    static func current(arguments: [String] = ProcessInfo.processInfo.arguments) -> AppEnvironment {
        if arguments.contains("-UITestMode") {
            let sandbox = FileManager.default.temporaryDirectory
                .appendingPathComponent("BourbonUITests-\(UUID().uuidString)", isDirectory: true)
            return AppEnvironment(mode: .uiTest(showOnboarding: arguments.contains("-UITestOnboarding")),
                                  supportDirectory: sandbox)
        }
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Bourbon", isDirectory: true)
        return AppEnvironment(mode: .live, supportDirectory: support)
    }
}

/// Pretends to run commands, so the UI tests never touch Wine.
struct SimulatedRunner: ProcessRunning {
    func run(_ command: WineCommand) async throws -> ProcessResult {
        try await Task.sleep(nanoseconds: 150_000_000)
        if command.arguments == ["--version"] {
            return ProcessResult(exitCode: 0, output: "wine-10.0\n")
        }
        return ProcessResult(exitCode: 0, output: "")
    }
}

enum UITestSeed {
    static let runtime = WineRuntime(
        binDirectory: URL(fileURLWithPath: "/usr/bin"),
        wineBinary: URL(fileURLWithPath: "/usr/bin/true"),
        wineserverBinary: URL(fileURLWithPath: "/usr/bin/true"),
        source: .managed,
        version: SemanticVersion(10, 0)
    )

    /// Two bottles with a few fake programs each.
    static func populate(_ store: BottleStore) throws {
        let steam = try store.create(BottleSettings(name: "Steam", symbol: "gamecontroller.fill", tint: .ocean,
                                                    dxvkEnabled: true))
        let office = try store.create(BottleSettings(name: "Office", symbol: "doc.richtext.fill", tint: .mint,
                                                     windowsVersion: .win11))
        try touch(steam.driveC.appendingPathComponent("Program Files (x86)/Steam/steam.exe"))
        try touch(steam.driveC.appendingPathComponent("Program Files/Hollow Lands/HollowLands.exe"))
        try touch(steam.driveC.appendingPathComponent("Program Files/Hollow Lands/unins000.exe"))
        try touch(office.driveC.appendingPathComponent("Program Files/Notepad++/notepad++.exe"))
    }

    private static func touch(_ url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: url.path, contents: Data("MZ".utf8))
    }
}
