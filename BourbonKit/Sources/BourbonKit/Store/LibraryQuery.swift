//
//  LibraryQuery.swift
//  BourbonKit
//

import Foundation

/// Search and ordering for a bottle's program library.
public struct LibraryQuery: Equatable, Sendable {
    public enum Sort: String, CaseIterable, Identifiable, Sendable {
        case name
        case recent

        public var id: String { rawValue }
    }

    public var text: String
    public var sort: Sort

    public init(text: String = "", sort: Sort = .name) {
        self.text = text
        self.sort = sort
    }

    /// Filters by name or path, then orders. Recently launched programs come first in `.recent`,
    /// with never-launched programs after them alphabetically.
    public func apply(to programs: [Program], settings: BottleSettings) -> [Program] {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        let filtered = trimmed.isEmpty ? programs : programs.filter {
            $0.name.localizedCaseInsensitiveContains(trimmed)
                || $0.relativePath.localizedCaseInsensitiveContains(trimmed)
        }

        let byName: (Program, Program) -> Bool = {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
        switch sort {
        case .name:
            return filtered.sorted(by: byName)
        case .recent:
            return filtered.sorted { lhs, rhs in
                let left = settings.programSettings[lhs.relativePath]?.lastLaunchedAt
                let right = settings.programSettings[rhs.relativePath]?.lastLaunchedAt
                switch (left, right) {
                case let (left?, right?): return left == right ? byName(lhs, rhs) : left > right
                case (.some, .none): return true
                case (.none, .some): return false
                case (.none, .none): return byName(lhs, rhs)
                }
            }
        }
    }

    /// Filters bottles by name.
    public static func filter(_ bottles: [Bottle], text: String) -> [Bottle] {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return bottles }
        return bottles.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
    }
}
