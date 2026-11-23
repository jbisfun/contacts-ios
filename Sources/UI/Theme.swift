import SwiftUI
import UIKit

enum ThemeKind: Int, CaseIterable, Identifiable {
    case system = 0, light, dark, darkRed, blackWhite, white, custom

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .system: return "System default"
        case .light: return "Light"
        case .dark: return "Dark"
        case .darkRed: return "Dark red"
        case .blackWhite: return "Black & White"
        case .white: return "White"
        case .custom: return "Custom"
        }
    }

    /// (text, background, primary) ARGB, from Fossify Commons colors.xml.
    func colors(dark: Bool) -> (UInt32, UInt32, UInt32) {
        switch self {
        case .system: return dark ? ThemeKind.dark.colors(dark: true) : ThemeKind.light.colors(dark: false)
        case .light: return (0xFF2D2D2D, 0xFFFFFFFF, 0xFF106D1F)
        case .dark: return (0xFFEEEEEE, 0xFF161616, 0xFF106D1F)
        case .darkRed: return (0xFFEEEEEE, 0xFF161616, 0xFFD32F2F)
        case .blackWhite: return (0xFFFFFFFF, 0xFF000000, 0xFFFFFFFF)
        case .white: return (0xFF2D2D2D, 0xFFFFFFFF, 0xFFFFFFFF)
        case .custom:
            let c = Config.shared
            return (c.customTextColor, c.customBackgroundColor, c.customPrimaryColor)
        }
    }
}

extension Color {
    init(argb: UInt32) {
        self.init(
            .sRGB,
            red: Double((argb >> 16) & 0xFF) / 255,
            green: Double((argb >> 8) & 0xFF) / 255,
            blue: Double(argb & 0xFF) / 255,
            opacity: Double((argb >> 24) & 0xFF) / 255
        )
    }

    var argb: UInt32 {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        func c(_ v: CGFloat) -> UInt32 { UInt32(max(0, min(255, (v * 255).rounded()))) }
        return c(a) << 24 | c(r) << 16 | c(g) << 8 | c(b)
    }
}

extension UInt32 {
    /// Fossify's getContrastColor(): white on dark colors, dark text on light ones.
    var contrastColor: Color {
        let r = Double((self >> 16) & 0xFF), g = Double((self >> 8) & 0xFF), b = Double(self & 0xFF)
        let y = (r * 299 + g * 587 + b * 114) / 1000
        return y >= 149 && self != 0xFF000000 ? Color(argb: 0xFF2D2D2D) : .white
    }

    var isWhite: Bool { self & 0xFFFFFF == 0xFFFFFF }
    var isBlack: Bool { self & 0xFFFFFF == 0 }
}

/// Resolved palette injected into the view tree.
struct Palette: Equatable {
    var text: UInt32
    var background: UInt32
    var primary: UInt32
    var fontSize: CGFloat
    var dark: Bool

    var textColor: Color { Color(argb: text) }
    var backgroundColor: Color { Color(argb: background) }
    /// getProperPrimaryColor(): white/black primaries fall back to the text color.
    var primaryColor: Color {
        if primary.isWhite && background.isWhite { return Color(argb: 0xFF2D2D2D) }
        if primary.isBlack && background.isBlack { return .white }
        return Color(argb: primary)
    }
    var onPrimary: Color { primary.contrastColor }
    /// Slightly lighter/darker surface used for the search bar, dialogs and cards.
    var surface: Color {
        dark ? Color(argb: background).mix(with: .white, by: 0.08) : Color(argb: background).mix(with: .black, by: 0.05)
    }
    var secondaryText: Color { textColor.opacity(0.65) }
    var divider: Color { textColor.opacity(0.15) }

    static func resolve(_ config: Config, scheme: ColorScheme) -> Palette {
        let dark: Bool
        let (t, b, p) = config.theme.colors(dark: scheme == .dark)
        switch config.theme {
        case .system: dark = scheme == .dark
        default:
            let r = Double((b >> 16) & 0xFF), g = Double((b >> 8) & 0xFF), bl = Double(b & 0xFF)
            dark = (r * 299 + g * 587 + bl * 114) / 1000 < 128
        }
        return Palette(text: t, background: b, primary: p, fontSize: config.fontSize.points, dark: dark)
    }
}

private struct PaletteKey: EnvironmentKey {
    static let defaultValue = Palette(text: 0xFF2D2D2D, background: 0xFFFFFFFF, primary: 0xFF106D1F, fontSize: 18, dark: false)
}

extension EnvironmentValues {
    var palette: Palette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}

extension Color {
    func mix(with other: Color, by amount: Double) -> Color {
        let a = UIColor(self), b = UIColor(other)
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        a.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        b.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let t = CGFloat(amount)
        return Color(.sRGB, red: r1 + (r2 - r1) * t, green: g1 + (g2 - g1) * t, blue: b1 + (b2 - b1) * t, opacity: a1 + (a2 - a1) * t)
    }
}
