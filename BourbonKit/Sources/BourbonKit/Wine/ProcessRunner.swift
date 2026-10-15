//
//  ProcessRunner.swift
//  BourbonKit
//

import Foundation

public struct ProcessResult: Equatable, Sendable {
    public let exitCode: Int32
    public let output: String

    public init(exitCode: Int32, output: String) {
        self.exitCode = exitCode
        self.output = output
    }

    public var succeeded: Bool { exitCode == 0 }
}

public enum ProcessRunnerError: LocalizedError, Equatable {
    case failed(command: String, exitCode: Int32, output: String)

    public var errorDescription: String? {
        switch self {
        case .failed(let command, let code, let output):
            let tail = output.split(whereSeparator: \.isNewline).suffix(3).joined(separator: "\n")
            return "\(command) exited with code \(code).\(tail.isEmpty ? "" : "\n" + tail)"
        }
    }
}

/// Runs commands. Abstracted so the launcher can be tested without spawning processes.
public protocol ProcessRunning: Sendable {
    func run(_ command: WineCommand) async throws -> ProcessResult
}

/// Collects process output from a background queue, optionally teeing it to a log file.
final class OutputBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()
    private var log: FileHandle?

    init(log: FileHandle?) {
        self.log = log
    }

    func append(_ chunk: Data) {
        lock.lock()
        defer { lock.unlock() }
        data.append(chunk)
        try? log?.write(contentsOf: chunk)
    }

    /// Stops logging. Chunks that arrive afterwards are still kept in memory.
    func finish() -> String {
        lock.lock()
        defer { lock.unlock() }
        try? log?.close()
        log = nil
        return String(decoding: data, as: UTF8.self)
    }
}

/// Spawns real processes with `Foundation.Process`, optionally teeing output to a log file.
public struct SystemProcessRunner: ProcessRunning {
    public let logDirectory: URL?

    public init(logDirectory: URL? = nil) {
        self.logDirectory = logDirectory
    }

    public func run(_ command: WineCommand) async throws -> ProcessResult {
        let buffer = OutputBuffer(log: makeLog(for: command))

        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = command.executable
            process.arguments = command.arguments
            process.environment = ProcessInfo.processInfo.environment.merging(command.environment) { $1 }
            if let directory = command.workingDirectory {
                process.currentDirectoryURL = directory
            }

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            pipe.fileHandleForReading.readabilityHandler = { handle in
                let chunk = handle.availableData
                if !chunk.isEmpty { buffer.append(chunk) }
            }
            process.terminationHandler = { finished in
                pipe.fileHandleForReading.readabilityHandler = nil
                // Wine's helper processes can inherit the pipe and keep it open long after the
                // command exits, so drain what's there without waiting for end-of-file.
                let rest = Self.drainWithoutBlocking(pipe.fileHandleForReading)
                if !rest.isEmpty { buffer.append(rest) }
                continuation.resume(returning: ProcessResult(exitCode: finished.terminationStatus,
                                                             output: buffer.finish()))
            }

            do {
                try process.run()
            } catch {
                pipe.fileHandleForReading.readabilityHandler = nil
                _ = buffer.finish()
                continuation.resume(throwing: error)
            }
        }
    }

    static func drainWithoutBlocking(_ handle: FileHandle) -> Data {
        let descriptor = handle.fileDescriptor
        let flags = fcntl(descriptor, F_GETFL)
        _ = fcntl(descriptor, F_SETFL, flags | O_NONBLOCK)

        var result = Data()
        var chunk = [UInt8](repeating: 0, count: 64 * 1024)
        while true {
            let count = chunk.withUnsafeMutableBytes { read(descriptor, $0.baseAddress, $0.count) }
            guard count > 0 else { break }
            result.append(contentsOf: chunk[0..<count])
        }
        return result
    }

    private func makeLog(for command: WineCommand) -> FileHandle? {
        guard let logDirectory else { return nil }
        try? FileManager.default.createDirectory(at: logDirectory, withIntermediateDirectories: true)
        let url = logDirectory.appendingPathComponent(LogFiles.name(for: command, at: Date()))
        guard FileManager.default.createFile(atPath: url.path, contents: Data((command.shellLine + "\n\n").utf8))
        else { return nil }
        let handle = try? FileHandle(forWritingTo: url)
        _ = try? handle?.seekToEnd()
        return handle
    }
}

public enum LogFiles {
    /// A sortable, filesystem-safe log name such as `2026-10-15T18-52-48-steam.log`.
    public static func name(for command: WineCommand, at date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime, .withDashSeparatorInDate]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        let stamp = formatter.string(from: date).replacingOccurrences(of: ":", with: "-")

        // `start /unix C:/…/Game.exe` → "game"; otherwise the first argument or the executable.
        let subject: String
        if let unix = command.arguments.firstIndex(of: "/unix"), unix + 1 < command.arguments.count {
            subject = URL(fileURLWithPath: command.arguments[unix + 1]).deletingPathExtension().lastPathComponent
        } else {
            subject = command.arguments.first ?? command.executable.lastPathComponent
        }
        return "\(stamp)-\(BottleStore.slug(for: subject).lowercased()).log"
    }
}
