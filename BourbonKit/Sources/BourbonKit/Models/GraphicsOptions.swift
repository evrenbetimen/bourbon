//
//  GraphicsOptions.swift
//  BourbonKit
//

import Foundation

/// How Wine synchronises threads. MSync is the fastest option on macOS.
public enum SyncMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case none
    case esync
    case msync

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .none: return "Off"
        case .esync: return "ESync"
        case .msync: return "MSync"
        }
    }
}

/// What the DXVK overlay shows on top of a running game.
public enum DXVKHUD: String, Codable, CaseIterable, Identifiable, Sendable {
    case off
    case fps
    case partial
    case full

    public var id: String { rawValue }

    /// The value for the `DXVK_HUD` environment variable, or `nil` when the HUD is off.
    public var environmentValue: String? {
        switch self {
        case .off: return nil
        case .fps: return "fps"
        case .partial: return "devinfo,fps,frametimes"
        case .full: return "full"
        }
    }
}

/// How much Wine writes to the log.
public enum LogLevel: String, Codable, CaseIterable, Identifiable, Sendable {
    case quiet
    case standard
    case verbose

    public var id: String { rawValue }

    /// The value for the `WINEDEBUG` environment variable.
    public var wineDebugValue: String {
        switch self {
        case .quiet: return "-all"
        case .standard: return "fixme-all"
        case .verbose: return "+err,+warn,+loaddll"
        }
    }
}

/// The accent a bottle uses throughout the interface.
public enum BottleTint: String, Codable, CaseIterable, Identifiable, Sendable {
    case amber
    case copper
    case rose
    case violet
    case ocean
    case mint
    case graphite

    public var id: String { rawValue }
}
