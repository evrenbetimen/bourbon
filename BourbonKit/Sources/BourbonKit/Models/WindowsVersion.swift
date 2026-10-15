//
//  WindowsVersion.swift
//  BourbonKit
//
//  Bourbon is free software, distributed under the GNU GPL v3.
//  Inspired by Whisky (https://github.com/Whisky-App/Whisky).
//

import Foundation

/// The version of Windows a bottle reports to the programs running inside it.
public enum WindowsVersion: String, Codable, CaseIterable, Identifiable, Sendable {
    case winXP = "winxp64"
    case win7 = "win7"
    case win8 = "win8"
    case win81 = "win81"
    case win10 = "win10"
    case win11 = "win11"

    public var id: String { rawValue }

    /// The value understood by `winecfg -v`.
    public var winecfgValue: String { rawValue }

    public var displayName: String {
        switch self {
        case .winXP: return "Windows XP"
        case .win7: return "Windows 7"
        case .win8: return "Windows 8"
        case .win81: return "Windows 8.1"
        case .win10: return "Windows 10"
        case .win11: return "Windows 11"
        }
    }

    /// A short label used on compact chips.
    public var shortName: String {
        switch self {
        case .winXP: return "XP"
        case .win7: return "7"
        case .win8: return "8"
        case .win81: return "8.1"
        case .win10: return "10"
        case .win11: return "11"
        }
    }

    /// The `CurrentBuild` number Windows reports for this release.
    public var buildNumber: Int {
        switch self {
        case .winXP: return 3790
        case .win7: return 7601
        case .win8: return 9200
        case .win81: return 9600
        case .win10: return 19045
        case .win11: return 22631
        }
    }

    /// Versions are ordered from oldest to newest.
    public static var newest: WindowsVersion { .win11 }

    /// The version new bottles start with; the best supported choice for modern software.
    public static var recommended: WindowsVersion { .win10 }
}
