//
//  WineRuntime.swift
//  BourbonKit
//

import Foundation

/// A Wine installation Bourbon can run bottles with.
public struct WineRuntime: Identifiable, Hashable, Sendable {
    public enum Source: String, Codable, Sendable {
        /// Downloaded and managed by Bourbon.
        case managed
        /// A Wine app bundle in /Applications (e.g. Gcenx's "Wine Stable.app").
        case application
        /// Installed through Homebrew.
        case homebrew
        /// Shared with an existing Whisky installation.
        case whisky
        /// A folder the user picked by hand.
        case custom
    }

    /// The folder containing `wine`/`wine64` and `wineserver`.
    public let binDirectory: URL
    public let wineBinary: URL
    public let wineserverBinary: URL
    public let source: Source
    public var version: SemanticVersion?

    public var id: URL { wineBinary }

    public init(binDirectory: URL, wineBinary: URL, wineserverBinary: URL,
                source: Source, version: SemanticVersion? = nil) {
        self.binDirectory = binDirectory
        self.wineBinary = wineBinary
        self.wineserverBinary = wineserverBinary
        self.source = source
        self.version = version
    }

    /// Parses the output of `wine --version`, e.g. `wine-9.0 (Staging)`.
    public static func parseVersion(_ output: String) -> SemanticVersion? {
        let line = output.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        guard line.lowercased().contains("wine") else { return nil }
        return SemanticVersion(line)
    }

    /// A display name such as "Wine 9.0 · Homebrew".
    public var displayName: String {
        let versionText = version.map { "Wine \($0)" } ?? "Wine"
        switch source {
        case .managed: return versionText
        case .application: return "\(versionText) · App"
        case .homebrew: return "\(versionText) · Homebrew"
        case .whisky: return "\(versionText) · Whisky"
        case .custom: return "\(versionText) · Custom"
        }
    }
}

/// The minimal file system surface the locator needs, so it can be tested without real installs.
public protocol FileProbing: Sendable {
    func isExecutableFile(atPath path: String) -> Bool
    func contentsOfDirectory(atPath path: String) -> [String]
}

public struct LocalFileProbe: FileProbing {
    public init() {}

    public func isExecutableFile(atPath path: String) -> Bool {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
              !isDirectory.boolValue else { return false }
        return FileManager.default.isExecutableFile(atPath: path)
    }

    public func contentsOfDirectory(atPath path: String) -> [String] {
        (try? FileManager.default.contentsOfDirectory(atPath: path)) ?? []
    }
}

/// Finds Wine installations on this Mac.
public struct RuntimeLocator: Sendable {
    /// Layouts, relative to an install root, where Wine keeps its binaries.
    public static let binLayouts = [
        "bin",
        "Wine/bin",
        "wine/bin",
        "Contents/Resources/wine/bin",
        "Contents/SharedSupport/wine/bin"
    ]

    /// Wine app bundles published by the community (Gcenx) and CrossOver-based builds.
    public static let applicationNames = [
        "Wine Stable.app", "Wine Devel.app", "Wine Staging.app", "Wine Crossover.app"
    ]

    public let probe: FileProbing
    /// Where Bourbon extracts runtimes it downloads.
    public let managedRoot: URL
    public let homeDirectory: URL

    public init(probe: FileProbing = LocalFileProbe(), managedRoot: URL,
                homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.probe = probe
        self.managedRoot = managedRoot
        self.homeDirectory = homeDirectory
    }

    /// Builds a runtime from a `bin` folder, preferring `wine64` (classic builds) over `wine` (WoW64 builds).
    public func runtime(inBinDirectory bin: URL, source: WineRuntime.Source) -> WineRuntime? {
        let wineserver = bin.appendingPathComponent("wineserver")
        guard probe.isExecutableFile(atPath: wineserver.path) else { return nil }
        for name in ["wine64", "wine"] {
            let candidate = bin.appendingPathComponent(name)
            if probe.isExecutableFile(atPath: candidate.path) {
                return WineRuntime(binDirectory: bin, wineBinary: candidate,
                                   wineserverBinary: wineserver, source: source)
            }
        }
        return nil
    }

    /// Searches an install root (or an app bundle) for any known bin layout.
    public func runtime(inRoot root: URL, source: WineRuntime.Source) -> WineRuntime? {
        for layout in Self.binLayouts {
            if let runtime = runtime(inBinDirectory: root.appendingPathComponent(layout), source: source) {
                return runtime
            }
        }
        return nil
    }

    /// Every candidate install location, in order of preference.
    public func candidates() -> [(URL, WineRuntime.Source)] {
        var result: [(URL, WineRuntime.Source)] = []

        // Runtimes Bourbon manages, newest version first: each child folder and any app bundle inside it.
        let managedChildren = probe.contentsOfDirectory(atPath: managedRoot.path).sorted { lhs, rhs in
            let left = SemanticVersion(lhs) ?? SemanticVersion(0)
            let right = SemanticVersion(rhs) ?? SemanticVersion(0)
            return left == right ? lhs < rhs : left > right
        }
        for child in managedChildren {
            let folder = managedRoot.appendingPathComponent(child)
            result.append((folder, .managed))
            for nested in probe.contentsOfDirectory(atPath: folder.path) where nested.hasSuffix(".app") {
                result.append((folder.appendingPathComponent(nested), .managed))
            }
        }

        for app in Self.applicationNames {
            result.append((URL(fileURLWithPath: "/Applications").appendingPathComponent(app), .application))
            result.append((homeDirectory.appendingPathComponent("Applications").appendingPathComponent(app),
                           .application))
        }

        result.append((URL(fileURLWithPath: "/opt/homebrew"), .homebrew))
        result.append((URL(fileURLWithPath: "/usr/local"), .homebrew))

        result.append((homeDirectory
            .appendingPathComponent("Library/Application Support/com.isaacmarovitz.Whisky/Libraries"), .whisky))
        return result
    }

    /// All runtimes found, without duplicates.
    public func locateAll() -> [WineRuntime] {
        var seen = Set<URL>()
        var found: [WineRuntime] = []
        for (root, source) in candidates() {
            guard let runtime = runtime(inRoot: root, source: source),
                  seen.insert(runtime.wineBinary).inserted else { continue }
            found.append(runtime)
        }
        return found
    }
}
