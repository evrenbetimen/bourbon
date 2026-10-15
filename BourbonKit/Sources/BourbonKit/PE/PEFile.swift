//
//  PEFile.swift
//  BourbonKit
//

import Foundation

public enum PEError: Error, Equatable {
    case notAnExecutable
    case truncated
    case invalidSignature
}

/// The handful of facts Bourbon needs from a Windows Portable Executable header.
///
/// Reference: https://learn.microsoft.com/windows/win32/debug/pe-format
public struct PEFile: Equatable, Sendable {
    public enum Machine: Equatable, Sendable {
        case i386
        case amd64
        case arm64
        case unknown(UInt16)

        init(rawValue: UInt16) {
            switch rawValue {
            case 0x014C: self = .i386
            case 0x8664: self = .amd64
            case 0xAA64: self = .arm64
            default: self = .unknown(rawValue)
            }
        }

        public var displayName: String {
            switch self {
            case .i386: return "32-bit (x86)"
            case .amd64: return "64-bit (x64)"
            case .arm64: return "ARM64"
            case .unknown(let value): return String(format: "Unknown (0x%04X)", value)
            }
        }
    }

    public enum Subsystem: Equatable, Sendable {
        case gui
        case console
        case other(UInt16)

        init(rawValue: UInt16) {
            switch rawValue {
            case 2: self = .gui
            case 3: self = .console
            default: self = .other(rawValue)
            }
        }
    }

    public let machine: Machine
    public let subsystem: Subsystem?
    public let is64Bit: Bool
    public let isDLL: Bool
    public let timestamp: Date

    /// Parses the headers at the start of `data`.
    public init(data: Data) throws {
        guard data.count >= 64 else { throw PEError.truncated }
        guard try Self.uint16(data, 0) == 0x5A4D else { throw PEError.notAnExecutable } // "MZ"

        let peOffset = Int(try Self.uint32(data, 0x3C))
        guard try Self.uint32(data, peOffset) == 0x0000_4550 else { throw PEError.invalidSignature } // "PE\0\0"

        let coff = peOffset + 4
        machine = Machine(rawValue: try Self.uint16(data, coff))
        timestamp = Date(timeIntervalSince1970: TimeInterval(try Self.uint32(data, coff + 4)))
        let optionalHeaderSize = Int(try Self.uint16(data, coff + 16))
        let characteristics = try Self.uint16(data, coff + 18)
        isDLL = characteristics & 0x2000 != 0

        let optional = coff + 20
        if optionalHeaderSize >= 2 {
            is64Bit = try Self.uint16(data, optional) == 0x020B
        } else {
            is64Bit = machine == .amd64 || machine == .arm64
        }
        // The subsystem lives at the same offset in PE32 and PE32+ optional headers.
        if optionalHeaderSize >= 70 {
            subsystem = Subsystem(rawValue: try Self.uint16(data, optional + 68))
        } else {
            subsystem = nil
        }
    }

    /// Reads just enough of the file at `url` to parse its headers.
    public init(url: URL) throws {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: 64 * 1024) ?? Data()
        try self.init(data: data)
    }

    static func uint16(_ data: Data, _ offset: Int) throws -> UInt16 {
        guard offset >= 0, offset + 2 <= data.count else { throw PEError.truncated }
        let index = data.startIndex + offset
        return UInt16(data[index]) | UInt16(data[index + 1]) << 8
    }

    static func uint32(_ data: Data, _ offset: Int) throws -> UInt32 {
        guard offset >= 0, offset + 4 <= data.count else { throw PEError.truncated }
        let index = data.startIndex + offset
        return UInt32(data[index])
            | UInt32(data[index + 1]) << 8
            | UInt32(data[index + 2]) << 16
            | UInt32(data[index + 3]) << 24
    }
}
