//
//  Color+AccentColor.swift
//  boringNotch
//
//  Created by Alexander on 2025-10-24.
//

import AppKit
import Defaults
import Foundation
import SwiftUI

enum EffectiveAccentColor {
    static func color(
        useCustomAccentColor: Bool = Defaults[.useCustomAccentColor],
        customAccentColorData: Data? = Defaults[.customAccentColorData]
    ) -> Color {
        Color(nsColor: nsColor(
            useCustomAccentColor: useCustomAccentColor,
            customAccentColorData: customAccentColorData
        ))
    }

    static func backgroundColor(
        useCustomAccentColor: Bool = Defaults[.useCustomAccentColor],
        customAccentColorData: Data? = Defaults[.customAccentColorData]
    ) -> Color {
        color(
            useCustomAccentColor: useCustomAccentColor,
            customAccentColorData: customAccentColorData
        )
        .opacity(0.22)
    }

    static func foregroundColor(
        useCustomAccentColor: Bool = Defaults[.useCustomAccentColor],
        customAccentColorData: Data? = Defaults[.customAccentColorData]
    ) -> Color {
        let nsColor = nsColor(
            useCustomAccentColor: useCustomAccentColor,
            customAccentColorData: customAccentColorData
        )
        let color = nsColor.usingColorSpace(.sRGB) ?? nsColor
        let luminance = (0.2126 * color.redComponent) + (0.7152 * color.greenComponent) + (0.0722 * color.blueComponent)

        return luminance > 0.64 ? Color.black.opacity(0.82) : Color.white
    }

    static func nsColor(
        useCustomAccentColor: Bool = Defaults[.useCustomAccentColor],
        customAccentColorData: Data? = Defaults[.customAccentColorData]
    ) -> NSColor {
        guard useCustomAccentColor,
              let nsColor = customNSColor(from: customAccentColorData) else {
            return MinitapBrand.Colors.nsAccent
        }

        return nsColor
    }

    static func nsBackgroundColor(
        useCustomAccentColor: Bool = Defaults[.useCustomAccentColor],
        customAccentColorData: Data? = Defaults[.customAccentColorData]
    ) -> NSColor {
        nsColor(
            useCustomAccentColor: useCustomAccentColor,
            customAccentColorData: customAccentColorData
        )
        .withAlphaComponent(0.25)
    }

    static func customNSColor(from colorData: Data?) -> NSColor? {
        guard let colorData,
              let nsColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: colorData) else {
            return nil
        }

        return nsColor.usingColorSpace(.sRGB) ?? nsColor
    }

    static func archivedData(for color: Color) -> Data? {
        let nsColor = NSColor(color).usingColorSpace(.sRGB) ?? NSColor(color)
        return try? NSKeyedArchiver.archivedData(
            withRootObject: nsColor,
            requiringSecureCoding: false
        )
    }
}

private struct EffectiveAccentColorModifier: ViewModifier {
    let useCustomAccentColor: Bool
    let customAccentColorData: Data?

    private var accentColor: Color {
        EffectiveAccentColor.color(
            useCustomAccentColor: useCustomAccentColor,
            customAccentColorData: customAccentColorData
        )
    }

    func body(content: Content) -> some View {
        content
            .tint(accentColor)
            .accentColor(accentColor)
    }
}

extension View {
    func effectiveAccentColor(
        useCustomAccentColor: Bool = Defaults[.useCustomAccentColor],
        customAccentColorData: Data? = Defaults[.customAccentColorData]
    ) -> some View {
        modifier(EffectiveAccentColorModifier(
            useCustomAccentColor: useCustomAccentColor,
            customAccentColorData: customAccentColorData
        ))
    }
}

extension Color {
    static var effectiveAccent: Color {
        EffectiveAccentColor.color()
    }
    
    static var effectiveAccentBackground: Color {
        EffectiveAccentColor.backgroundColor()
    }

    static var effectiveAccentForeground: Color {
        EffectiveAccentColor.foregroundColor()
    }
}

extension NSColor {
    static var effectiveAccent: NSColor {
        EffectiveAccentColor.nsColor()
    }
    
    static var effectiveAccentBackground: NSColor {
        EffectiveAccentColor.nsBackgroundColor()
    }
}
