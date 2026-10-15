//
//  Bottle.swift
//  BourbonKit
//

import Foundation

/// A self-contained Windows environment (a Wine prefix) plus Bourbon's metadata about it.
public struct Bottle: Identifiable, Hashable, Sendable {
    public static let metadataFileName = "Metadata.plist"

    public let url: URL
    public var settings: BottleSettings

    public var id: URL { url }
    public var name: String { settings.name }

    public init(url: URL, settings: BottleSettings) {
        self.url = url.standardizedFileURL
        self.settings = settings
    }

    public var metadataURL: URL { url.appendingPathComponent(Self.metadataFileName) }
    public var driveC: URL { url.appendingPathComponent("drive_c", isDirectory: true) }

    /// Whether Wine has initialised this prefix yet.
    public var isInitialized: Bool {
        FileManager.default.fileExists(atPath: url.appendingPathComponent("system.reg").path)
    }

    /// The path of `fileURL` relative to the bottle folder, or `nil` if it lives elsewhere.
    public func relativePath(of fileURL: URL) -> String? {
        if let direct = Self.relativePath(of: fileURL.standardizedFileURL.path, in: url.standardizedFileURL.path) {
            return direct
        }
        // `/var` vs `/private/var` and similar: compare the fully resolved paths.
        return Self.relativePath(
            of: fileURL.resolvingSymlinksInPath().path,
            in: url.resolvingSymlinksInPath().path
        )
    }

    static func relativePath(of path: String, in base: String) -> String? {
        let prefix = base.hasSuffix("/") ? base : base + "/"
        guard path.hasPrefix(prefix), path.count > prefix.count else { return nil }
        return String(path.dropFirst(prefix.count))
    }

    /// Resolves a path stored relative to the bottle folder.
    public func resolve(relativePath: String) -> URL {
        url.appendingPathComponent(relativePath)
    }

    public static func == (lhs: Bottle, rhs: Bottle) -> Bool {
        lhs.url == rhs.url && lhs.settings == rhs.settings
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }
}
