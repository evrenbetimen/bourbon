//
//  Theme.swift
//  Bourbon
//

import BourbonKit
import SwiftUI

extension BottleTint {
    var color: Color {
        switch self {
        case .amber: return Color(red: 0.95, green: 0.62, blue: 0.20)
        case .copper: return Color(red: 0.80, green: 0.42, blue: 0.24)
        case .rose: return Color(red: 0.93, green: 0.36, blue: 0.48)
        case .violet: return Color(red: 0.55, green: 0.42, blue: 0.95)
        case .ocean: return Color(red: 0.20, green: 0.55, blue: 0.95)
        case .mint: return Color(red: 0.22, green: 0.76, blue: 0.62)
        case .graphite: return Color(red: 0.45, green: 0.48, blue: 0.53)
        }
    }

    /// A second stop for gradients, shifted in hue so cards feel lit rather than flat.
    var companion: Color {
        switch self {
        case .amber: return Color(red: 0.86, green: 0.30, blue: 0.16)
        case .copper: return Color(red: 0.55, green: 0.22, blue: 0.20)
        case .rose: return Color(red: 0.62, green: 0.25, blue: 0.75)
        case .violet: return Color(red: 0.26, green: 0.36, blue: 0.90)
        case .ocean: return Color(red: 0.12, green: 0.78, blue: 0.86)
        case .mint: return Color(red: 0.12, green: 0.52, blue: 0.70)
        case .graphite: return Color(red: 0.22, green: 0.24, blue: 0.30)
        }
    }

    var gradient: LinearGradient {
        LinearGradient(colors: [color, companion], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var label: LocalizedStringKey {
        switch self {
        case .amber: return "Amber"
        case .copper: return "Copper"
        case .rose: return "Rose"
        case .violet: return "Violet"
        case .ocean: return "Ocean"
        case .mint: return "Mint"
        case .graphite: return "Graphite"
        }
    }
}

enum BottleSymbols {
    static let all = [
        "wineglass.fill", "gamecontroller.fill", "doc.richtext.fill", "paintbrush.pointed.fill",
        "music.note", "film.fill", "hammer.fill", "chart.xyaxis.line", "globe", "cube.fill",
        "sparkles", "bolt.fill"
    ]
}

/// The brand gradient used behind onboarding and empty states.
struct BourbonBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.16, green: 0.08, blue: 0.05), Color(red: 0.05, green: 0.04, blue: 0.08)],
                startPoint: .top, endPoint: .bottom
            )
            RadialGradient(colors: [BottleTint.amber.color.opacity(0.55), .clear],
                           center: .topLeading, startRadius: 20, endRadius: 520)
            RadialGradient(colors: [BottleTint.rose.color.opacity(0.35), .clear],
                           center: .bottomTrailing, startRadius: 20, endRadius: 480)
        }
        .ignoresSafeArea()
    }
}
