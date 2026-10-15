//
//  WineLauncher.swift
//  BourbonKit
//

import Foundation

/// Runs Wine commands against bottles and keeps their metadata in sync.
public struct WineLauncher: Sendable {
    public let runtime: WineRuntime
    public let runner: ProcessRunning

    public init(runtime: WineRuntime, runner: ProcessRunning) {
        self.runtime = runtime
        self.runner = runner
    }

    public var factory: WineCommandFactory { WineCommandFactory(runtime: runtime) }

    /// Runs `command`, throwing if it exits with a non-zero code.
    @discardableResult
    public func runChecked(_ command: WineCommand) async throws -> ProcessResult {
        let result = try await runner.run(command)
        guard result.succeeded else {
            throw ProcessRunnerError.failed(
                command: ([command.executable.lastPathComponent] + command.arguments.prefix(2)).joined(separator: " "),
                exitCode: result.exitCode,
                output: result.output
            )
        }
        return result
    }

    /// Initialises a new prefix and applies the bottle's Windows version and display options.
    public func prepare(_ bottle: Bottle) async throws {
        try await runChecked(factory.initializePrefix(bottle))
        try await runChecked(factory.setWindowsVersion(bottle.settings.windowsVersion, in: bottle))
        if bottle.settings.retinaMode {
            for command in try factory.setRetinaMode(true, in: bottle) {
                try await runChecked(command)
            }
        }
    }

    /// Applies options that live in the prefix's registry after the user changes them.
    public func apply(changesFrom old: BottleSettings, to bottle: Bottle) async throws {
        if old.windowsVersion != bottle.settings.windowsVersion {
            try await runChecked(factory.setWindowsVersion(bottle.settings.windowsVersion, in: bottle))
        }
        if old.retinaMode != bottle.settings.retinaMode {
            for command in try factory.setRetinaMode(bottle.settings.retinaMode, in: bottle) {
                try await runChecked(command)
            }
        }
    }

    /// Launches a program and returns the bottle with its launch timestamps updated.
    public func launch(_ program: Program, in bottle: Bottle, at date: Date = Date()) async throws -> Bottle {
        _ = try await runner.run(factory.launch(program, in: bottle))
        var updated = bottle
        updated.settings.lastLaunchedAt = date
        var programSettings = updated.settings.programSettings[program.relativePath] ?? ProgramSettings()
        programSettings.lastLaunchedAt = date
        updated.settings.programSettings[program.relativePath] = programSettings
        return updated
    }

    /// Runs an arbitrary executable or installer that may live outside the bottle.
    public func run(fileAt url: URL, in bottle: Bottle) async throws -> ProcessResult {
        try await runner.run(factory.install(packageAt: url, in: bottle))
    }

    public func open(_ tool: WineTool, in bottle: Bottle) async throws {
        _ = try await runner.run(factory.open(tool, in: bottle))
    }

    public func killAll(in bottle: Bottle) async throws {
        _ = try await runner.run(factory.killAll(in: bottle))
    }

    /// Queries the runtime's version.
    public func detectVersion() async -> SemanticVersion? {
        guard let result = try? await runner.run(factory.version()), result.succeeded else { return nil }
        return WineRuntime.parseVersion(result.output)
    }
}
