//
//  Pieces.swift
//  Bourbon
//

import AppKit
import BourbonKit
import SwiftUI
import UniformTypeIdentifiers

/// The rounded, gradient icon that represents a bottle.
struct BottleIcon: View {
    let settings: BottleSettings
    var size: CGFloat = 28

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(settings.tint.gradient)
            .overlay {
                Image(systemName: settings.symbol)
                    .font(.system(size: size * 0.48, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
            }
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                    .strokeBorder(.white.opacity(0.25), lineWidth: 0.5)
            }
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// A small capsule label.
struct Chip: View {
    let text: String
    var symbol: String?

    var body: some View {
        HStack(spacing: 4) {
            if let symbol { Image(systemName: symbol) }
            Text(text)
        }
        .font(.caption.weight(.medium))
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .glassSurface(cornerRadius: 20)
    }
}

/// The program's icon as Finder shows it, falling back to a monogram.
struct ProgramIcon: View {
    let program: Program
    var size: CGFloat = 48
    var tint: BottleTint = .amber

    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
            } else {
                RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                    .fill(tint.gradient.opacity(0.85))
                    .overlay {
                        Text(String(program.name.prefix(1)).uppercased())
                            .font(.system(size: size * 0.46, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
            }
        }
        .frame(width: size, height: size)
        .task(id: program.url) {
            image = await ProgramIconCache.shared.icon(for: program.url)
        }
        .accessibilityHidden(true)
    }
}

/// Caches Finder icons. Generic executable icons are skipped so the monogram shows instead.
@MainActor
final class ProgramIconCache {
    static let shared = ProgramIconCache()
    private var cache: [URL: NSImage?] = [:]
    private lazy var genericIcon = NSWorkspace.shared.icon(for: .exe).tiffRepresentation

    func icon(for url: URL) async -> NSImage? {
        if let cached = cache[url] { return cached }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        let result: NSImage? = icon.tiffRepresentation == genericIcon ? nil : icon
        cache[url] = result
        return result
    }
}

/// A section heading used in the bottle detail view.
struct SectionHeader: View {
    let title: LocalizedStringKey
    var count: Int?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.title3.weight(.semibold))
            if let count {
                Text(count, format: .number)
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}
