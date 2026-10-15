//
//  Services.swift
//  Bourbon
//

import BourbonKit
import Foundation

/// Wine's x86 builds need Rosetta 2 on Apple silicon.
enum RosettaSupport {
    static var isAppleSilicon: Bool {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        return sysctlbyname("hw.optional.arm64", &value, &size, nil, 0) == 0 && value == 1
    }

    static func isInstalled() async -> Bool {
        guard isAppleSilicon else { return true }
        let probe = WineCommand(executable: URL(fileURLWithPath: "/usr/bin/arch"),
                                arguments: ["-x86_64", "/usr/bin/true"])
        let result = try? await SystemProcessRunner().run(probe)
        return result?.succeeded ?? false
    }

    /// Installs Rosetta, asking for an administrator password through the standard macOS prompt.
    static func install() async throws {
        let script = #"do shell script "/usr/sbin/softwareupdate --install-rosetta --agree-to-license" "#
            + "with administrator privileges"
        let command = WineCommand(executable: URL(fileURLWithPath: "/usr/bin/osascript"), arguments: ["-e", script])
        let result = try await SystemProcessRunner().run(command)
        guard result.succeeded else {
            throw ProcessRunnerError.failed(command: "softwareupdate --install-rosetta",
                                            exitCode: result.exitCode, output: result.output)
        }
    }
}

enum RuntimeInstallError: LocalizedError {
    case noAsset(RuntimeRelease.Flavor)
    case extractionFailed(String)
    case runtimeNotFound

    var errorDescription: String? {
        switch self {
        case .noAsset(let flavor):
            return String(localized: "The latest release has no \(flavor.displayName) build for macOS.")
        case .extractionFailed(let output):
            return String(localized: "Couldn't unpack Wine. \(output)")
        case .runtimeNotFound:
            return String(localized: "The download didn't contain a Wine runtime.")
        }
    }
}

/// Downloads a community Wine build and unpacks it into Bourbon's runtimes folder.
struct RuntimeInstaller {
    let runtimesRoot: URL
    var feed: URL = RuntimeRelease.defaultFeed

    func latestRelease() async throws -> RuntimeRelease {
        var request = URLRequest(url: feed)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(RuntimeRelease.self, from: data)
    }

    func installLatest(flavor: RuntimeRelease.Flavor,
                       progress: @escaping @Sendable (Double) -> Void) async throws -> WineRuntime {
        let release = try await latestRelease()
        guard let asset = release.asset(for: flavor) else { throw RuntimeInstallError.noAsset(flavor) }

        let archive = try await Downloader.download(asset.downloadURL, progress: progress)
        defer { try? FileManager.default.removeItem(at: archive) }

        let destination = runtimesRoot.appendingPathComponent(RuntimeArchive.folderName(for: asset.name))
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

        let result = try await SystemProcessRunner().run(
            RuntimeArchive().extractCommand(archive: archive, destination: destination)
        )
        guard result.succeeded else { throw RuntimeInstallError.extractionFailed(result.output) }

        let locator = RuntimeLocator(managedRoot: runtimesRoot)
        let installed = locator.locateAll().first { $0.binDirectory.path.hasPrefix(destination.path) }
        guard var runtime = installed else { throw RuntimeInstallError.runtimeNotFound }
        runtime.version = release.version
        return runtime
    }
}

/// A download with progress reporting.
enum Downloader {
    static func download(_ url: URL, progress: @escaping @Sendable (Double) -> Void) async throws -> URL {
        let holder = ObservationHolder()
        return try await withCheckedThrowingContinuation { continuation in
            let task = URLSession.shared.downloadTask(with: url) { location, _, error in
                holder.observation = nil
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let location else {
                    continuation.resume(throwing: URLError(.badServerResponse))
                    return
                }
                // The temporary file is deleted when this handler returns, so move it first.
                let kept = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString + "-" + url.lastPathComponent)
                do {
                    try FileManager.default.moveItem(at: location, to: kept)
                    continuation.resume(returning: kept)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            holder.observation = task.progress.observe(\.fractionCompleted) { value, _ in
                progress(value.fractionCompleted)
            }
            task.resume()
        }
    }

    private final class ObservationHolder: @unchecked Sendable {
        var observation: NSKeyValueObservation?
    }
}

/// Fetches the winetricks script on first use.
enum WinetricksScript {
    static func ensure(at url: URL, simulated: Bool) async throws -> URL {
        if simulated { return URL(fileURLWithPath: "/usr/bin/true") }
        if FileManager.default.isExecutableFile(atPath: url.path) { return url }

        let (data, _) = try await URLSession.shared.data(from: Winetricks.scriptURL)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        return url
    }

    /// Lists every verb winetricks knows about.
    static func listAll(script: URL) async -> [WinetricksVerb] {
        let command = WineCommand(executable: script, arguments: ["list-all"])
        guard let result = try? await SystemProcessRunner().run(command), result.succeeded else { return [] }
        return Winetricks.parse(result.output)
    }
}
