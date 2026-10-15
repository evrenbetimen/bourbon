//
//  SemanticVersion.swift
//  BourbonKit
//

import Foundation

/// A `major.minor.patch` version that tolerates the loose formats Wine uses,
/// such as `wine-9.0`, `v10.2` or `9.0-rc3 (Staging)`.
public struct SemanticVersion: Comparable, Hashable, Codable, CustomStringConvertible, Sendable {
    public var major: Int
    public var minor: Int
    public var patch: Int

    public init(_ major: Int, _ minor: Int = 0, _ patch: Int = 0) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    /// Parses the first run of dot-separated numbers in `string`.
    public init?(_ string: String) {
        var numbers: [Int] = []
        var current = ""
        var started = false

        for character in string {
            if character.isASCII, character.isNumber {
                current.append(character)
                started = true
            } else if character == ".", started, !current.isEmpty {
                numbers.append(Int(current) ?? 0)
                current = ""
            } else if started {
                break
            }
        }
        if !current.isEmpty { numbers.append(Int(current) ?? 0) }

        guard let major = numbers.first else { return nil }
        self.init(
            major,
            numbers.count > 1 ? numbers[1] : 0,
            numbers.count > 2 ? numbers[2] : 0
        )
    }

    public var description: String {
        patch == 0 ? "\(major).\(minor)" : "\(major).\(minor).\(patch)"
    }

    public static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
    }
}
