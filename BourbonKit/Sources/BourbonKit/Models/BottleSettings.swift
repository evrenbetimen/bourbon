//
//  BottleSettings.swift
//  BourbonKit
//

import Foundation

/// A program the user pinned to the top of a bottle.
public struct PinnedProgram: Codable, Hashable, Identifiable, Sendable {
    /// Path relative to the bottle folder, e.g. `drive_c/Program Files/Steam/steam.exe`.
    public var relativePath: String
    public var name: String

    public var id: String { relativePath }

    public init(name: String, relativePath: String) {
        self.name = name
        self.relativePath = relativePath
    }
}

/// Per-program launch options.
public struct ProgramSettings: Codable, Hashable, Sendable {
    public var arguments: String
    public var environment: [String: String]
    /// A POSIX locale such as `ja_JP.UTF-8`; `nil` keeps the system locale.
    public var locale: String?
    public var lastLaunchedAt: Date?

    public init(
        arguments: String = "",
        environment: [String: String] = [:],
        locale: String? = nil,
        lastLaunchedAt: Date? = nil
    ) {
        self.arguments = arguments
        self.environment = environment
        self.locale = locale
        self.lastLaunchedAt = lastLaunchedAt
    }

    private enum CodingKeys: String, CodingKey {
        case arguments, environment, locale, lastLaunchedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        arguments = try container.decodeIfPresent(String.self, forKey: .arguments) ?? ""
        environment = try container.decodeIfPresent([String: String].self, forKey: .environment) ?? [:]
        locale = try container.decodeIfPresent(String.self, forKey: .locale)
        lastLaunchedAt = try container.decodeIfPresent(Date.self, forKey: .lastLaunchedAt)
    }
}

/// Everything Bourbon stores about a bottle. Persisted as `Metadata.plist` inside the bottle.
///
/// Decoding is deliberately forgiving: any missing key falls back to its default so that
/// bottles written by older versions of Bourbon keep opening.
public struct BottleSettings: Codable, Equatable, Sendable {
    public static let currentFileVersion = 1

    public var fileVersion: Int
    public var name: String
    public var symbol: String
    public var tint: BottleTint
    public var windowsVersion: WindowsVersion
    public var syncMode: SyncMode
    public var dxvkEnabled: Bool
    public var dxvkAsync: Bool
    public var dxvkHUD: DXVKHUD
    public var metalHUD: Bool
    public var metalTrace: Bool
    public var retinaMode: Bool
    public var advertiseAVX: Bool
    public var logLevel: LogLevel
    public var environment: [String: String]
    public var pinnedPrograms: [PinnedProgram]
    /// Relative paths of executables hidden from the library.
    public var hiddenPrograms: [String]
    /// Launch options keyed by the program's relative path.
    public var programSettings: [String: ProgramSettings]
    public var createdAt: Date
    public var lastLaunchedAt: Date?

    public init(
        name: String,
        symbol: String = "wineglass.fill",
        tint: BottleTint = .amber,
        windowsVersion: WindowsVersion = .recommended,
        syncMode: SyncMode = .msync,
        dxvkEnabled: Bool = false,
        dxvkAsync: Bool = true,
        dxvkHUD: DXVKHUD = .off,
        metalHUD: Bool = false,
        metalTrace: Bool = false,
        retinaMode: Bool = false,
        advertiseAVX: Bool = false,
        logLevel: LogLevel = .standard,
        environment: [String: String] = [:],
        pinnedPrograms: [PinnedProgram] = [],
        hiddenPrograms: [String] = [],
        programSettings: [String: ProgramSettings] = [:],
        createdAt: Date = Date(),
        lastLaunchedAt: Date? = nil
    ) {
        self.fileVersion = Self.currentFileVersion
        self.name = name
        self.symbol = symbol
        self.tint = tint
        self.windowsVersion = windowsVersion
        self.syncMode = syncMode
        self.dxvkEnabled = dxvkEnabled
        self.dxvkAsync = dxvkAsync
        self.dxvkHUD = dxvkHUD
        self.metalHUD = metalHUD
        self.metalTrace = metalTrace
        self.retinaMode = retinaMode
        self.advertiseAVX = advertiseAVX
        self.logLevel = logLevel
        self.environment = environment
        self.pinnedPrograms = pinnedPrograms
        self.hiddenPrograms = hiddenPrograms
        self.programSettings = programSettings
        self.createdAt = createdAt
        self.lastLaunchedAt = lastLaunchedAt
    }

    private enum CodingKeys: String, CodingKey {
        case fileVersion, name, symbol, tint, windowsVersion, syncMode
        case dxvkEnabled, dxvkAsync, dxvkHUD, metalHUD, metalTrace, retinaMode, advertiseAVX
        case logLevel, environment, pinnedPrograms, hiddenPrograms, programSettings
        case createdAt, lastLaunchedAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = BottleSettings(name: "Bottle", createdAt: Date(timeIntervalSince1970: 0))

        fileVersion = try c.decodeIfPresent(Int.self, forKey: .fileVersion) ?? Self.currentFileVersion
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? defaults.name
        symbol = try c.decodeIfPresent(String.self, forKey: .symbol) ?? defaults.symbol
        tint = (try? c.decodeIfPresent(BottleTint.self, forKey: .tint)) ?? defaults.tint
        windowsVersion = (try? c.decodeIfPresent(WindowsVersion.self, forKey: .windowsVersion))
            ?? defaults.windowsVersion
        syncMode = (try? c.decodeIfPresent(SyncMode.self, forKey: .syncMode)) ?? defaults.syncMode
        dxvkEnabled = try c.decodeIfPresent(Bool.self, forKey: .dxvkEnabled) ?? defaults.dxvkEnabled
        dxvkAsync = try c.decodeIfPresent(Bool.self, forKey: .dxvkAsync) ?? defaults.dxvkAsync
        dxvkHUD = (try? c.decodeIfPresent(DXVKHUD.self, forKey: .dxvkHUD)) ?? defaults.dxvkHUD
        metalHUD = try c.decodeIfPresent(Bool.self, forKey: .metalHUD) ?? defaults.metalHUD
        metalTrace = try c.decodeIfPresent(Bool.self, forKey: .metalTrace) ?? defaults.metalTrace
        retinaMode = try c.decodeIfPresent(Bool.self, forKey: .retinaMode) ?? defaults.retinaMode
        advertiseAVX = try c.decodeIfPresent(Bool.self, forKey: .advertiseAVX) ?? defaults.advertiseAVX
        logLevel = (try? c.decodeIfPresent(LogLevel.self, forKey: .logLevel)) ?? defaults.logLevel
        environment = try c.decodeIfPresent([String: String].self, forKey: .environment) ?? [:]
        pinnedPrograms = try c.decodeIfPresent([PinnedProgram].self, forKey: .pinnedPrograms) ?? []
        hiddenPrograms = try c.decodeIfPresent([String].self, forKey: .hiddenPrograms) ?? []
        programSettings = try c.decodeIfPresent([String: ProgramSettings].self, forKey: .programSettings) ?? [:]
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? defaults.createdAt
        lastLaunchedAt = try c.decodeIfPresent(Date.self, forKey: .lastLaunchedAt)
    }

    // MARK: - Persistence

    public func encoded() throws -> Data {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        return try encoder.encode(self)
    }

    public static func decode(from data: Data) throws -> BottleSettings {
        try PropertyListDecoder().decode(BottleSettings.self, from: data)
    }

    // MARK: - Pinning

    public func isPinned(_ relativePath: String) -> Bool {
        pinnedPrograms.contains { $0.relativePath == relativePath }
    }

    /// Pins the program, or unpins it if it is already pinned.
    public mutating func togglePin(name: String, relativePath: String) {
        if let index = pinnedPrograms.firstIndex(where: { $0.relativePath == relativePath }) {
            pinnedPrograms.remove(at: index)
        } else {
            pinnedPrograms.append(PinnedProgram(name: name, relativePath: relativePath))
        }
    }

    /// A short summary of the bottle's most important options, used on chips.
    public var highlights: [String] {
        var result = [windowsVersion.displayName]
        if syncMode != .none { result.append(syncMode.displayName) }
        if dxvkEnabled { result.append("DXVK") }
        if retinaMode { result.append("Retina") }
        if metalHUD { result.append("Metal HUD") }
        return result
    }
}
