import SwiftUI

/// All colors and text styles in one place, so the look can be changed easily.
enum Theme {
    static let background = Color(hex: 0xF8F5F0)
    static let surface = Color.white
    static let ink = Color(hex: 0x211D19)
    static let inkSoft = Color(hex: 0x4A423B)
    static let muted = Color(hex: 0x6E655C)
    static let line = Color(hex: 0xE7E0D6)
    static let fieldBorder = Color(hex: 0xDCD3C6)
    static let softFill = Color(hex: 0xF1EBE2)
    static let deckShadow = Color(hex: 0xEFE7DC)

    /// Orange from the Nyam logo. Used as a fill with dark text on top.
    static let orange = Color(hex: 0xE0954A)
    static let orangeSoft = Color(hex: 0xFBEBD9)
    /// Darker orange that is readable as text on light backgrounds.
    static let orangeText = Color(hex: 0xA35A14)
    /// "Craving" color.
    static let teal = Color(hex: 0x1E6B66)
    static let danger = Color(hex: 0xA33A2A)

    /// Soft colors used behind dishes that have no photo yet.
    static let placeholderTints: [Color] = [
        Color(hex: 0xF6D9B8), Color(hex: 0xEFE2C9), Color(hex: 0xDCE5D3),
        Color(hex: 0xD3E4E1), Color(hex: 0xF2D3C2), Color(hex: 0xE6DDCF)
    ]

    /// Always gives the same tint for the same dish.
    static func tint(for id: String) -> Color {
        let sum = id.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return placeholderTints[sum % placeholderTints.count]
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

extension Font {
    /// Rounded headline font that matches the round Nyam logo.
    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func ui(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.ui(17, weight: .heavy))
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(Theme.orange, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.ui(17, weight: .heavy))
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Theme.fieldBorder, lineWidth: 1.5)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}
