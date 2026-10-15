//
//  CommandLine.swift
//  BourbonKit
//

import Foundation

/// Helpers for turning user-typed text into process arguments and back.
public enum CommandLineText {
    /// Splits an argument string the way a POSIX shell would, honouring single quotes,
    /// double quotes and backslash escapes. No expansion is performed.
    ///
    ///     split(#"-w 1280 --title "My Game""#) == ["-w", "1280", "--title", "My Game"]
    public static func split(_ text: String) -> [String] {
        var result: [String] = []
        var current = ""
        var hasToken = false
        var quote: Character?
        var escaping = false

        for character in text {
            if escaping {
                current.append(character)
                escaping = false
                hasToken = true
                continue
            }
            switch character {
            case "\\" where quote != "'":
                escaping = true
            case "\"", "'":
                if quote == nil {
                    quote = character
                    hasToken = true
                } else if quote == character {
                    quote = nil
                } else {
                    current.append(character)
                }
            case " ", "\t", "\n":
                if quote != nil {
                    current.append(character)
                } else if hasToken {
                    result.append(current)
                    current = ""
                    hasToken = false
                }
            default:
                current.append(character)
                hasToken = true
            }
        }
        if escaping { current.append("\\") }
        if hasToken { result.append(current) }
        return result
    }

    /// Quotes `argument` so a POSIX shell reads it back as a single word.
    public static func shellQuote(_ argument: String) -> String {
        guard !argument.isEmpty else { return "''" }
        let safe = CharacterSet(charactersIn:
            "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_./=:,+@%")
        if argument.unicodeScalars.allSatisfy({ safe.contains($0) }) {
            return argument
        }
        return "'" + argument.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /// Whether `name` is a valid environment variable name.
    public static func isValidEnvironmentName(_ name: String) -> Bool {
        guard let first = name.unicodeScalars.first else { return false }
        let letters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_")
        let rest = letters.union(CharacterSet(charactersIn: "0123456789"))
        return letters.contains(first) && name.unicodeScalars.allSatisfy { rest.contains($0) }
    }
}
