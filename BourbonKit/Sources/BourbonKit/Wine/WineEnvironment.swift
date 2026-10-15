//
//  WineEnvironment.swift
//  BourbonKit
//

import Foundation

public enum WineEnvironmentError: LocalizedError, Equatable {
    case invalidVariableName(String)
    case reservedVariable(String)

    public var errorDescription: String? {
        switch self {
        case .invalidVariableName(let name):
            return "\u{201C}\(name)\u{201D} is not a valid environment variable name."
        case .reservedVariable(let name):
            return "\u{201C}\(name)\u{201D} is managed by Bourbon and can't be overridden."
        }
    }
}

/// Builds the environment Wine runs with for a bottle.
///
/// Precedence, lowest to highest: Bourbon's defaults, the bottle's options,
/// the bottle's custom variables, then the program's own variables and locale.
public enum WineEnvironment {
    /// Variables Bourbon must control for a bottle to work.
    public static let reservedNames: Set<String> = ["WINEPREFIX"]

    /// The DLL overrides that route Direct3D 9–11 through DXVK.
    public static let dxvkOverrides = "dxgi,d3d9,d3d10core,d3d11=n,b"

    public static func make(
        for bottle: Bottle,
        program: ProgramSettings? = nil
    ) throws -> [String: String] {
        let settings = bottle.settings
        var env: [String: String] = [
            "WINEPREFIX": bottle.url.path,
            "WINEDEBUG": settings.logLevel.wineDebugValue
        ]

        switch settings.syncMode {
        case .none:
            break
        case .esync:
            env["WINEESYNC"] = "1"
        case .msync:
            env["WINEMSYNC"] = "1"
            // ESync stays on as a fallback for Wine builds without MSync.
            env["WINEESYNC"] = "1"
        }

        if settings.dxvkEnabled {
            env["WINEDLLOVERRIDES"] = dxvkOverrides
            if settings.dxvkAsync { env["DXVK_ASYNC"] = "1" }
            if let hud = settings.dxvkHUD.environmentValue { env["DXVK_HUD"] = hud }
        }
        if settings.metalHUD { env["MTL_HUD_ENABLED"] = "1" }
        if settings.metalTrace { env["METAL_CAPTURE_ENABLED"] = "1" }
        if settings.advertiseAVX { env["ROSETTA_ADVERTISE_AVX"] = "1" }

        try merge(settings.environment, into: &env)

        if let program {
            try merge(program.environment, into: &env)
            if let locale = program.locale, !locale.isEmpty {
                env["LC_ALL"] = locale
                env["LANG"] = locale
            }
        }
        return env
    }

    static func merge(_ custom: [String: String], into env: inout [String: String]) throws {
        for (name, value) in custom {
            guard CommandLineText.isValidEnvironmentName(name) else {
                throw WineEnvironmentError.invalidVariableName(name)
            }
            guard !reservedNames.contains(name) else {
                throw WineEnvironmentError.reservedVariable(name)
            }
            if name == "WINEDLLOVERRIDES", let existing = env[name], !existing.isEmpty, !value.isEmpty {
                // Keep DXVK working when the user adds overrides of their own.
                env[name] = existing + ";" + value
            } else {
                env[name] = value
            }
        }
    }
}
