//
//  ProgramScanner.swift
//  BourbonKit
//

import Foundation

/// Finds the Windows programs installed in a bottle.
public struct ProgramScanner: Sendable {
    /// Folders inside `drive_c` that never contain user-facing programs.
    public static let skippedFolders: Set<String> = ["windows", "programdata/microsoft"]

    /// Executable name fragments that are almost always helpers, not apps.
    public static let noisePatterns = [
        "unins", "uninstall", "crashhandler", "crashreport", "crashpad", "vc_redist", "vcredist",
        "dxsetup", "dotnetfx", "ndp4", "updater", "helper", "redist", "setup_helper", "errorreporter",
        "wineboot", "iexplore"
    ]

    public var maxDepth: Int

    public init(maxDepth: Int = 7) {
        self.maxDepth = maxDepth
    }

    /// Whether an executable name looks like a helper rather than an app.
    public static func isNoise(_ fileName: String) -> Bool {
        let lowered = fileName.lowercased()
        return noisePatterns.contains { lowered.contains($0) }
    }

    /// Every `.exe` in the bottle that isn't hidden or noise, sorted by name.
    public func scan(_ bottle: Bottle) -> [Program] {
        let drive = bottle.driveC
        guard let enumerator = FileManager.default.enumerator(
            at: drive,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        let hidden = Set(bottle.settings.hiddenPrograms)
        var programs: [Program] = []
        var seen = Set<String>()

        for case let url as URL in enumerator {
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            if values?.isDirectory == true {
                let relativeToDrive = Bottle.relativePath(
                    of: url.resolvingSymlinksInPath().path, in: drive.resolvingSymlinksInPath().path
                )?.lowercased() ?? ""
                // Skip Windows itself, symlinked folders (e.g. the user's macOS home), and very deep trees.
                if Self.skippedFolders.contains(relativeToDrive)
                    || values?.isSymbolicLink == true
                    || enumerator.level >= maxDepth {
                    enumerator.skipDescendants()
                }
                continue
            }
            guard url.pathExtension.lowercased() == "exe",
                  !Self.isNoise(url.lastPathComponent),
                  let relative = bottle.relativePath(of: url),
                  !hidden.contains(relative),
                  seen.insert(relative).inserted else { continue }
            programs.append(Program(url: url, relativePath: relative))
        }

        return programs.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }
}
