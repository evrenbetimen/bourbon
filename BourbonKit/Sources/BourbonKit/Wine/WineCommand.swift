//
//  WineCommand.swift
//  BourbonKit
//

import Foundation

/// A fully described process invocation: what to run, with which arguments and environment.
public struct WineCommand: Equatable, Sendable {
    public var executable: URL
    public var arguments: [String]
    public var environment: [String: String]
    public var workingDirectory: URL?

    public init(
        executable: URL,
        arguments: [String],
        environment: [String: String] = [:],
        workingDirectory: URL? = nil
    ) {
        self.executable = executable
        self.arguments = arguments
        self.environment = environment
        self.workingDirectory = workingDirectory
    }

    /// The command as a line that can be pasted into Terminal.
    public var shellLine: String {
        let env = environment.keys.sorted().map { "\($0)=\(CommandLineText.shellQuote(environment[$0] ?? ""))" }
        let words = [executable.path] + arguments
        var line = (env + words.map(CommandLineText.shellQuote)).joined(separator: " ")
        if let workingDirectory {
            line = "cd \(CommandLineText.shellQuote(workingDirectory.path)) && " + line
        }
        return line
    }
}

/// Built-in Windows utilities that ship with Wine.
public enum WineTool: String, CaseIterable, Identifiable, Sendable {
    case configuration = "winecfg"
    case registryEditor = "regedit"
    case taskManager = "taskmgr"
    case controlPanel = "control"
    case explorer = "explorer"
    case commandPrompt = "wineconsole"

    public var id: String { rawValue }

    public var arguments: [String] {
        switch self {
        case .commandPrompt: return ["wineconsole", "cmd"]
        default: return [rawValue]
        }
    }

    public var displayName: String {
        switch self {
        case .configuration: return "Wine Configuration"
        case .registryEditor: return "Registry Editor"
        case .taskManager: return "Task Manager"
        case .controlPanel: return "Control Panel"
        case .explorer: return "File Explorer"
        case .commandPrompt: return "Command Prompt"
        }
    }

    public var symbol: String {
        switch self {
        case .configuration: return "gearshape.2"
        case .registryEditor: return "list.bullet.rectangle"
        case .taskManager: return "chart.bar.xaxis"
        case .controlPanel: return "slider.horizontal.3"
        case .explorer: return "folder"
        case .commandPrompt: return "terminal"
        }
    }
}

/// Registry value types accepted by `reg add`.
public enum RegistryValueType: String, Sendable {
    case string = "REG_SZ"
    case dword = "REG_DWORD"
    case qword = "REG_QWORD"
    case binary = "REG_BINARY"
}

/// Builds the commands Bourbon runs against a bottle with a given runtime.
public struct WineCommandFactory: Sendable {
    public static let macDriverKey = #"HKCU\Software\Wine\Mac Driver"#
    public static let desktopKey = #"HKCU\Control Panel\Desktop"#

    public let runtime: WineRuntime

    public init(runtime: WineRuntime) {
        self.runtime = runtime
    }

    private func wine(_ arguments: [String], bottle: Bottle, program: ProgramSettings? = nil,
                      workingDirectory: URL? = nil) throws -> WineCommand {
        WineCommand(
            executable: runtime.wineBinary,
            arguments: arguments,
            environment: try WineEnvironment.make(for: bottle, program: program),
            workingDirectory: workingDirectory
        )
    }

    /// Initialises a fresh prefix.
    public func initializePrefix(_ bottle: Bottle) throws -> WineCommand {
        try wine(["wineboot", "--init"], bottle: bottle)
    }

    /// Launches a Windows program, splitting its saved argument string.
    public func launch(_ program: Program, in bottle: Bottle) throws -> WineCommand {
        let settings = bottle.settings.programSettings[program.relativePath] ?? ProgramSettings()
        return try launch(executableAt: program.url, in: bottle, settings: settings)
    }

    public func launch(executableAt url: URL, in bottle: Bottle,
                       settings: ProgramSettings = ProgramSettings()) throws -> WineCommand {
        let arguments = ["start", "/unix", url.path] + CommandLineText.split(settings.arguments)
        return try wine(arguments, bottle: bottle, program: settings,
                        workingDirectory: url.deletingLastPathComponent())
    }

    /// Installers such as `.msi` packages go through `msiexec`.
    public func install(packageAt url: URL, in bottle: Bottle) throws -> WineCommand {
        if url.pathExtension.lowercased() == "msi" {
            return try wine(["msiexec", "/i", url.path], bottle: bottle,
                            workingDirectory: url.deletingLastPathComponent())
        }
        return try launch(executableAt: url, in: bottle)
    }

    public func open(_ tool: WineTool, in bottle: Bottle) throws -> WineCommand {
        try wine(tool.arguments, bottle: bottle)
    }

    public func setWindowsVersion(_ version: WindowsVersion, in bottle: Bottle) throws -> WineCommand {
        try wine(["winecfg", "-v", version.winecfgValue], bottle: bottle)
    }

    public func addRegistryValue(key: String, name: String, type: RegistryValueType, data: String,
                                 in bottle: Bottle) throws -> WineCommand {
        try wine(["reg", "add", key, "/v", name, "/t", type.rawValue, "/d", data, "/f"], bottle: bottle)
    }

    /// Retina mode needs two registry values: the driver flag and a matching DPI.
    public func setRetinaMode(_ enabled: Bool, in bottle: Bottle) throws -> [WineCommand] {
        [
            try addRegistryValue(key: Self.macDriverKey, name: "RetinaMode", type: .string,
                                 data: enabled ? "y" : "n", in: bottle),
            try addRegistryValue(key: Self.desktopKey, name: "LogPixels", type: .dword,
                                 data: enabled ? "192" : "96", in: bottle)
        ]
    }

    /// Stops every process in the bottle.
    public func killAll(in bottle: Bottle) throws -> WineCommand {
        WineCommand(
            executable: runtime.wineserverBinary,
            arguments: ["-k"],
            environment: try WineEnvironment.make(for: bottle)
        )
    }

    /// Runs a winetricks verb with the bottle's runtime.
    public func winetricks(_ verb: String, script: URL, in bottle: Bottle) throws -> WineCommand {
        var environment = try WineEnvironment.make(for: bottle)
        environment["WINE"] = runtime.wineBinary.path
        environment["WINESERVER"] = runtime.wineserverBinary.path
        return WineCommand(executable: script, arguments: ["--unattended", verb], environment: environment)
    }

    /// Asks the runtime for its version.
    public func version() -> WineCommand {
        WineCommand(executable: runtime.wineBinary, arguments: ["--version"])
    }
}
