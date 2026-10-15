//
//  Program.swift
//  BourbonKit
//

import Foundation

/// A Windows executable found inside a bottle.
public struct Program: Identifiable, Hashable, Sendable {
    public let url: URL
    /// Path relative to the bottle folder; stable across bottle moves.
    public let relativePath: String

    public var id: String { relativePath }

    public init(url: URL, relativePath: String) {
        self.url = url
        self.relativePath = relativePath
    }

    /// The file name without its `.exe` extension.
    public var name: String {
        url.deletingPathExtension().lastPathComponent
    }

    /// The folder that contains the program, used as its working directory.
    public var directory: URL {
        url.deletingLastPathComponent()
    }
}

/// The Windows files Bourbon can open: programs, installers and batch scripts.
public enum RunnableFile {
    /// Lowercase extensions, in the order the file picker lists them.
    public static let extensions = ["exe", "msi", "bat"]

    /// Whether `url` names a file Bourbon can hand to Wine. The check ignores case, so `SETUP.EXE` counts.
    public static func isRunnable(_ url: URL) -> Bool {
        url.isFileURL && extensions.contains(url.pathExtension.lowercased())
    }
}
