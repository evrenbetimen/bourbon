//
//  BottleStore.swift
//  BourbonKit
//

import Foundation

public enum BottleNameError: LocalizedError, Equatable {
    case empty
    case tooLong(limit: Int)
    case invalidCharacters

    public var errorDescription: String? {
        switch self {
        case .empty: return "Give your bottle a name."
        case .tooLong(let limit): return "Bottle names can be up to \(limit) characters."
        case .invalidCharacters: return "Bottle names can't contain “/” or “:”."
        }
    }
}

public enum BottleStoreError: LocalizedError, Equatable {
    case notABottle(URL)

    public var errorDescription: String? {
        switch self {
        case .notABottle(let url): return "\(url.lastPathComponent) isn't a Bourbon bottle."
        }
    }
}

/// Creates, lists and edits bottles in a root folder on disk.
///
/// Each bottle is a folder containing a Wine prefix plus `Metadata.plist`.
public final class BottleStore: @unchecked Sendable {
    public static let nameLimit = 48

    public let root: URL
    private let fileManager: FileManager

    public init(root: URL, fileManager: FileManager = .default) {
        self.root = root
        self.fileManager = fileManager
    }

    /// The default location: `~/Library/Containers/…` is avoided on purpose so Wine can see the files.
    public static var defaultRoot: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("Bourbon/Bottles", isDirectory: true)
    }

    // MARK: - Validation

    /// Trims and validates a user-typed bottle name.
    public static func validateName(_ name: String) -> Result<String, BottleNameError> {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure(.empty) }
        guard trimmed.count <= nameLimit else { return .failure(.tooLong(limit: nameLimit)) }
        guard !trimmed.contains("/"), !trimmed.contains(":") else { return .failure(.invalidCharacters) }
        return .success(trimmed)
    }

    /// A filesystem-friendly folder name derived from a bottle name.
    public static func slug(for name: String) -> String {
        // "Çılgın Café" → "Cilgin Cafe": transliterate to ASCII where ICU can, then drop what's left.
        let ascii = name.applyingTransform(StringTransform(rawValue: "Any-Latin; Latin-ASCII"), reverse: false)
        let folded = (ascii ?? name).folding(options: .diacriticInsensitive, locale: Locale(identifier: "en_US"))
        var slug = ""
        var lastWasDash = false
        for scalar in folded.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar), scalar.isASCII {
                slug.unicodeScalars.append(scalar)
                lastWasDash = false
            } else if !lastWasDash, !slug.isEmpty {
                slug.append("-")
                lastWasDash = true
            }
        }
        while slug.hasSuffix("-") { slug.removeLast() }
        return slug.isEmpty ? "bottle" : slug
    }

    // MARK: - Reading

    /// Every bottle in the root folder, sorted by name. Unreadable folders are skipped.
    public func loadAll() throws -> [Bottle] {
        guard fileManager.fileExists(atPath: root.path) else { return [] }
        let children = try fileManager.contentsOfDirectory(
            at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]
        )
        return children
            .compactMap { try? load(at: $0) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    public func load(at url: URL) throws -> Bottle {
        let metadata = url.appendingPathComponent(Bottle.metadataFileName)
        guard fileManager.fileExists(atPath: metadata.path) else { throw BottleStoreError.notABottle(url) }
        let settings = try BottleSettings.decode(from: Data(contentsOf: metadata))
        return Bottle(url: url, settings: settings)
    }

    // MARK: - Writing

    /// Creates the bottle folder and its metadata. Wine initialises the prefix separately.
    @discardableResult
    public func create(_ settings: BottleSettings) throws -> Bottle {
        var settings = settings
        settings.name = try Self.validateName(settings.name).get()

        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        let folder = uniqueFolder(for: settings.name)
        try fileManager.createDirectory(at: folder.appendingPathComponent("drive_c"), withIntermediateDirectories: true)

        let bottle = Bottle(url: folder, settings: settings)
        try save(bottle)
        return bottle
    }

    public func save(_ bottle: Bottle) throws {
        try bottle.settings.encoded().write(to: bottle.metadataURL, options: .atomic)
    }

    /// Renames the bottle. The folder keeps its name so running programs aren't disturbed.
    @discardableResult
    public func rename(_ bottle: Bottle, to name: String) throws -> Bottle {
        var renamed = bottle
        renamed.settings.name = try Self.validateName(name).get()
        try save(renamed)
        return renamed
    }

    /// Copies the whole bottle, prefix included.
    @discardableResult
    public func duplicate(_ bottle: Bottle) throws -> Bottle {
        let name = uniqueName(base: bottle.name + " Copy")
        let destination = uniqueFolder(for: name)
        try fileManager.copyItem(at: bottle.url, to: destination)

        var settings = bottle.settings
        settings.name = name
        settings.createdAt = Date()
        settings.lastLaunchedAt = nil
        let copy = Bottle(url: destination, settings: settings)
        try save(copy)
        return copy
    }

    /// Deletes the bottle. Uses the Trash where available so mistakes can be undone.
    public func delete(_ bottle: Bottle, useTrash: Bool = true) throws {
        #if os(macOS)
        if useTrash {
            try fileManager.trashItem(at: bottle.url, resultingItemURL: nil)
            return
        }
        #endif
        try fileManager.removeItem(at: bottle.url)
    }

    // MARK: - Helpers

    func uniqueFolder(for name: String) -> URL {
        let base = Self.slug(for: name)
        var candidate = root.appendingPathComponent(base, isDirectory: true)
        var counter = 2
        while fileManager.fileExists(atPath: candidate.path) {
            candidate = root.appendingPathComponent("\(base)-\(counter)", isDirectory: true)
            counter += 1
        }
        return candidate
    }

    /// `base`, or `base 2`, `base 3`… if another bottle already uses the name.
    public func uniqueName(base: String) -> String {
        let existing = Set(((try? loadAll()) ?? []).map { $0.name.lowercased() })
        guard existing.contains(base.lowercased()) else { return base }
        var counter = 2
        while existing.contains("\(base) \(counter)".lowercased()) { counter += 1 }
        return "\(base) \(counter)"
    }
}
