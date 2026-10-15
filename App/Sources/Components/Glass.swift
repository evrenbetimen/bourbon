//
//  Glass.swift
//  Bourbon
//
//  On macOS 26 Bourbon uses the system's Liquid Glass. Older systems get a
//  frosted-material look that keeps the same shapes and hierarchy.
//

import SwiftUI

struct GlassSurface: ViewModifier {
    var cornerRadius: CGFloat
    var tint: Color?
    var interactive: Bool

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            content.glassEffect(Glass.regular.tint(tint?.opacity(0.22)).interactive(interactive), in: shape)
        } else {
            fallback(content)
        }
        #else
        fallback(content)
        #endif
    }

    private func fallback(_ content: Content) -> some View {
        content
            .background {
                ZStack {
                    shape.fill(.regularMaterial)
                    if let tint { shape.fill(tint.opacity(0.10)) }
                }
            }
            .overlay { shape.strokeBorder(.white.opacity(0.14), lineWidth: 1) }
            .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
    }
}

struct ProminentGlassButton: ViewModifier {
    var tint: Color

    @ViewBuilder
    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            content.buttonStyle(.glassProminent).tint(tint)
        } else {
            content.buttonStyle(.borderedProminent).tint(tint)
        }
        #else
        content.buttonStyle(.borderedProminent).tint(tint)
        #endif
    }
}

struct SecondaryGlassButton: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            content.buttonStyle(.glass)
        } else {
            content.buttonStyle(.bordered)
        }
        #else
        content.buttonStyle(.bordered)
        #endif
    }
}

extension View {
    func glassSurface(cornerRadius: CGFloat = 22, tint: Color? = nil, interactive: Bool = false) -> some View {
        modifier(GlassSurface(cornerRadius: cornerRadius, tint: tint, interactive: interactive))
    }

    func prominentGlassButton(tint: Color = .accentColor) -> some View {
        modifier(ProminentGlassButton(tint: tint))
    }

    func secondaryGlassButton() -> some View {
        modifier(SecondaryGlassButton())
    }
}
