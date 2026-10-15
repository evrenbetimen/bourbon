//
//  RuntimeRelease.swift
//  BourbonKit
//

import Foundation

/// A GitHub release of a Wine build, as returned by the releases API.
public struct RuntimeRelease: Decodable, Equatable, Sendable {
    public struct Asset: Decodable, Equatable, Sendable {
        public let name: String
        public let downloadURL: URL
        public let size: Int

        enum CodingKeys: String, CodingKey {
            case name
            case downloadURL = "browser_download_url"
            case size
        }

        public init(name: String, downloadURL: URL, size: Int) {
            self.name = name
            self.downloadURL = downloadURL
            self.size = size
        }
    }

    public enum Flavor: String, CaseIterable, Identifiable, Codable, Sendable {
        case stable, devel, staging

        public var id: String { rawValue }
        public var displayName: String { rawValue.capitalized }
    }

    /// Community macOS builds of upstream Wine.
    public static let defaultFeed = URL(string: "https://api.github.com/repos/Gcenx/macOS_Wine_builds/releases/latest")!

    public let tagName: String
    public let assets: [Asset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case assets
    }

    public init(tagName: String, assets: [Asset]) {
        self.tagName = tagName
        self.assets = assets
    }

    public var version: SemanticVersion? { SemanticVersion(tagName) }

    /// The macOS archive for `flavor`, e.g. `wine-stable-10.0-osx64.tar.xz`.
    public func asset(for flavor: Flavor) -> Asset? {
        let prefix = "wine-\(flavor.rawValue)-"
        let archiveExtensions = [".tar.xz", ".tar.gz", ".tar.bz2"]
        return assets
            .filter { asset in
                let name = asset.name.lowercased()
                return name.hasPrefix(prefix)
                    && name.contains("osx")
                    && archiveExtensions.contains { name.hasSuffix($0) }
            }
            // Prefer the 64-bit build when both exist.
            .sorted { ($0.name.contains("osx64") ? 0 : 1, $0.name) < ($1.name.contains("osx64") ? 0 : 1, $1.name) }
            .first
    }
}

/// Extracts a downloaded runtime archive with the system `tar`.
public struct RuntimeArchive: Sendable {
    public static let tar = URL(fileURLWithPath: "/usr/bin/tar")

    public init() {}

    /// The command that extracts `archive` into `destination`.
    public func extractCommand(archive: URL, destination: URL) -> WineCommand {
        WineCommand(executable: Self.tar, arguments: ["-xf", archive.path, "-C", destination.path])
    }

    /// A folder name for the extracted runtime, derived from the archive name.
    public static func folderName(for archiveName: String) -> String {
        var name = archiveName
        for suffix in [".tar.xz", ".tar.gz", ".tar.bz2", ".tgz", ".zip"] where name.lowercased().hasSuffix(suffix) {
            name = String(name.dropLast(suffix.count))
            break
        }
        return name.isEmpty ? "wine" : name
    }
}
