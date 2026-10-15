//
//  Winetricks.swift
//  BourbonKit
//

import Foundation

/// A single winetricks verb such as `vcrun2022` or `corefonts`.
public struct WinetricksVerb: Identifiable, Hashable, Sendable {
    public let name: String
    public let summary: String
    public let category: String

    public var id: String { "\(category)/\(name)" }

    public init(name: String, summary: String, category: String) {
        self.name = name
        self.summary = summary
        self.category = category
    }
}

public enum Winetricks {
    /// Where the winetricks script is downloaded from.
    public static let scriptURL = URL(string: "https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks")!

    /// Parses `winetricks list-all` output:
    ///
    ///     ===== dlls =====
    ///     vcrun2022   Visual C++ 2015-2022 libraries (Microsoft, 2022) [downloadable]
    public static func parse(_ output: String) -> [WinetricksVerb] {
        var verbs: [WinetricksVerb] = []
        // Anything before the first section header is banner text, not a verb.
        var category: String?

        for rawLine in output.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }

            if line.hasPrefix("=====") {
                category = line.trimmingCharacters(in: CharacterSet(charactersIn: "= "))
                continue
            }
            guard let category else { continue }
            guard let space = line.firstIndex(where: { $0 == " " || $0 == "\t" }) else {
                verbs.append(WinetricksVerb(name: line, summary: "", category: category))
                continue
            }
            let name = String(line[..<space])
            var summary = line[space...].trimmingCharacters(in: .whitespaces)
            for marker in ["[downloadable]", "[cached]"] where summary.hasSuffix(marker) {
                summary = String(summary.dropLast(marker.count)).trimmingCharacters(in: .whitespaces)
            }
            verbs.append(WinetricksVerb(name: name, summary: summary, category: category))
        }
        return verbs
    }

    /// Popular verbs shown before the full list has been fetched.
    public static let essentials: [WinetricksVerb] = [
        WinetricksVerb(name: "vcrun2022", summary: "Visual C++ 2015–2022 libraries", category: "dlls"),
        WinetricksVerb(name: "dotnet48", summary: ".NET Framework 4.8", category: "dlls"),
        WinetricksVerb(name: "d3dx9", summary: "DirectX 9 helper libraries", category: "dlls"),
        WinetricksVerb(name: "d3dcompiler_47", summary: "Direct3D shader compiler", category: "dlls"),
        WinetricksVerb(name: "xact", summary: "XACT audio engine", category: "dlls"),
        WinetricksVerb(name: "physx", summary: "NVIDIA PhysX", category: "dlls"),
        WinetricksVerb(name: "corefonts", summary: "Microsoft core fonts", category: "fonts"),
        WinetricksVerb(name: "cjkfonts", summary: "Chinese, Japanese and Korean fonts", category: "fonts"),
        WinetricksVerb(name: "fontsmooth=rgb", summary: "Subpixel font smoothing", category: "settings"),
        WinetricksVerb(name: "win10", summary: "Report Windows 10", category: "settings")
    ]

    /// Filters verbs by a search string across name, summary and category.
    public static func filter(_ verbs: [WinetricksVerb], query: String) -> [WinetricksVerb] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return verbs }
        return verbs.filter {
            $0.name.localizedCaseInsensitiveContains(trimmed)
                || $0.summary.localizedCaseInsensitiveContains(trimmed)
                || $0.category.localizedCaseInsensitiveContains(trimmed)
        }
    }
}
