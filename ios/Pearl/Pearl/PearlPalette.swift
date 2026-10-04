import SwiftUI
import UIKit

/// 首页/日子两页用的静态色板和底衬(10.5 从 9.13 的原生首页找回;聊天页走 Theme,这两页先沿用这套)。
/// 首页底色改成米白——她定的口径(10.4):首页米白,不要方块不要卡通。
extension Color {
    static let pearlBackground = adaptive(
        light: UIColor(red: 0.965, green: 0.953, blue: 0.945, alpha: 1),
        dark: UIColor(red: 0.067, green: 0.094, blue: 0.125, alpha: 1)
    )
    static let pearlInk = adaptive(
        light: UIColor(red: 0.17, green: 0.15, blue: 0.14, alpha: 1),
        dark: UIColor(red: 0.91, green: 0.93, blue: 0.95, alpha: 1)
    )
    static let pearlSoft = adaptive(
        light: UIColor(red: 0.45, green: 0.42, blue: 0.40, alpha: 1),
        dark: UIColor(red: 0.68, green: 0.73, blue: 0.77, alpha: 1)
    )
    static let pearlLine = adaptive(
        light: UIColor(red: 0.30, green: 0.25, blue: 0.22, alpha: 0.18),
        dark: UIColor(white: 0.92, alpha: 0.16)
    )
    static let pearlAI = adaptive(
        light: UIColor(red: 0.99, green: 0.98, blue: 0.97, alpha: 0.90),
        dark: UIColor(red: 0.15, green: 0.19, blue: 0.24, alpha: 0.91)
    )
    static let pearlAccent = adaptive(
        light: UIColor(red: 0.42, green: 0.36, blue: 0.33, alpha: 1),
        dark: UIColor(red: 0.61, green: 0.70, blue: 0.77, alpha: 1)
    )
    static let pearlRose = adaptive(
        light: UIColor(red: 0.66, green: 0.40, blue: 0.49, alpha: 1),
        dark: UIColor(red: 0.82, green: 0.59, blue: 0.66, alpha: 1)
    )
    static let pearlGold = adaptive(
        light: UIColor(red: 0.67, green: 0.52, blue: 0.30, alpha: 1),
        dark: UIColor(red: 0.79, green: 0.67, blue: 0.46, alpha: 1)
    )
    static let pearlTeal = adaptive(
        light: UIColor(red: 0.31, green: 0.51, blue: 0.51, alpha: 1),
        dark: UIColor(red: 0.49, green: 0.69, blue: 0.67, alpha: 1)
    )

    private static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { traits in traits.userInterfaceStyle == .dark ? dark : light })
    }
}

struct PearlBackdrop: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            Color.pearlBackground
            LinearGradient(colors: scheme == .dark
                ? [Color.black.opacity(0.30), Color.black.opacity(0.55)]
                : [Color.white.opacity(0.35), Color.pearlBackground.opacity(0.1)],
                startPoint: .top, endPoint: .bottom)
        }
        .ignoresSafeArea()
    }
}

extension View {
    func pearlSurface(radius: CGFloat = 20) -> some View {
        background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .background(Color.pearlAI.opacity(0.56), in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(Color.pearlLine.opacity(0.85), lineWidth: 0.7) }
            .shadow(color: Color.black.opacity(0.055), radius: 20, y: 9)
    }
}
