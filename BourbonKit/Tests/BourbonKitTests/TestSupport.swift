//
//  TestSupport.swift
//  BourbonKitTests
//

import Foundation
import XCTest
@testable import BourbonKit

/// A temporary folder that removes itself.
final class TemporaryDirectory {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("BourbonKitTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: url)
    }

    /// Creates an empty file (and its parent folders) at `relativePath`.
    @discardableResult
    func touch(_ relativePath: String, contents: Data = Data(), executable: Bool = false) throws -> URL {
        let file = url.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: file.path, contents: contents)
        if executable {
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: file.path)
        }
        return file
    }
}

/// Records commands instead of running them.
final class RecordingRunner: ProcessRunning, @unchecked Sendable {
    private let lock = NSLock()
    private var _commands: [WineCommand] = []
    var results: [ProcessResult] = []

    var commands: [WineCommand] {
        lock.lock()
        defer { lock.unlock() }
        return _commands
    }

    func run(_ command: WineCommand) async throws -> ProcessResult {
        record(command)
    }

    private func record(_ command: WineCommand) -> ProcessResult {
        lock.lock()
        defer { lock.unlock() }
        _commands.append(command)
        return results.isEmpty ? ProcessResult(exitCode: 0, output: "") : results.removeFirst()
    }
}

/// A file probe backed by an in-memory set of paths.
struct FakeProbe: FileProbing {
    var executables: Set<String>
    var directories: [String: [String]] = [:]

    func isExecutableFile(atPath path: String) -> Bool { executables.contains(path) }
    func contentsOfDirectory(atPath path: String) -> [String] { directories[path] ?? [] }
}

enum Fixtures {
    static let runtime = WineRuntime(
        binDirectory: URL(fileURLWithPath: "/wine/bin"),
        wineBinary: URL(fileURLWithPath: "/wine/bin/wine64"),
        wineserverBinary: URL(fileURLWithPath: "/wine/bin/wineserver"),
        source: .managed
    )

    static func bottle(_ configure: (inout BottleSettings) -> Void = { _ in }) -> Bottle {
        var settings = BottleSettings(name: "Test", createdAt: Date(timeIntervalSince1970: 0))
        configure(&settings)
        return Bottle(url: URL(fileURLWithPath: "/bottles/test"), settings: settings)
    }

    /// Builds a minimal but well-formed PE image.
    static func peImage(
        machine: UInt16 = 0x8664,
        magic: UInt16 = 0x020B,
        subsystem: UInt16 = 2,
        characteristics: UInt16 = 0x0022,
        timestamp: UInt32 = 1_700_000_000,
        peOffset: Int = 0x80,
        optionalHeaderSize: UInt16 = 240
    ) -> Data {
        var bytes = [UInt8](repeating: 0, count: peOffset + 24 + Int(optionalHeaderSize))
        func put16(_ value: UInt16, at offset: Int) {
            bytes[offset] = UInt8(value & 0xFF)
            bytes[offset + 1] = UInt8(value >> 8)
        }
        func put32(_ value: UInt32, at offset: Int) {
            for index in 0..<4 { bytes[offset + index] = UInt8((value >> (8 * UInt32(index))) & 0xFF) }
        }
        put16(0x5A4D, at: 0)
        put32(UInt32(peOffset), at: 0x3C)
        put32(0x0000_4550, at: peOffset)
        let coff = peOffset + 4
        put16(machine, at: coff)
        put32(timestamp, at: coff + 4)
        put16(optionalHeaderSize, at: coff + 16)
        put16(characteristics, at: coff + 18)
        if optionalHeaderSize >= 2 { put16(magic, at: coff + 20) }
        if optionalHeaderSize >= 70 { put16(subsystem, at: coff + 20 + 68) }
        return Data(bytes)
    }
}
