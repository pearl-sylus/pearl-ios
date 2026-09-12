import SwiftUI
import UIKit

@main
struct PearlApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(.pearlAccent)
        }
    }
}

private struct RootView: View {
    var body: some View {
        ChatView()
    }
}

extension Color {
    static let pearlBackground = adaptive(
        light: UIColor(red: 0.93, green: 0.96, blue: 0.97, alpha: 1),
        dark: UIColor(red: 0.067, green: 0.094, blue: 0.125, alpha: 1)
    )
    static let pearlInk = adaptive(
        light: UIColor(red: 0.15, green: 0.22, blue: 0.29, alpha: 1),
        dark: UIColor(red: 0.91, green: 0.93, blue: 0.95, alpha: 1)
    )
    static let pearlSoft = adaptive(
        light: UIColor(red: 0.38, green: 0.46, blue: 0.53, alpha: 1),
        dark: UIColor(red: 0.68, green: 0.73, blue: 0.77, alpha: 1)
    )
    static let pearlLine = adaptive(
        light: UIColor(red: 0.29, green: 0.40, blue: 0.49, alpha: 0.20),
        dark: UIColor(white: 0.92, alpha: 0.16)
    )
    static let pearlAI = adaptive(
        light: UIColor(red: 0.96, green: 0.97, blue: 0.98, alpha: 0.90),
        dark: UIColor(red: 0.15, green: 0.19, blue: 0.24, alpha: 0.91)
    )
    static let pearlMine = adaptive(
        light: UIColor(red: 0.87, green: 0.91, blue: 0.94, alpha: 0.94),
        dark: UIColor(red: 0.21, green: 0.27, blue: 0.34, alpha: 0.94)
    )
    static let pearlField = adaptive(
        light: UIColor(red: 0.97, green: 0.985, blue: 0.99, alpha: 0.92),
        dark: UIColor(red: 0.12, green: 0.16, blue: 0.21, alpha: 0.90)
    )
    static let pearlAccent = adaptive(
        light: UIColor(red: 0.32, green: 0.42, blue: 0.51, alpha: 1),
        dark: UIColor(red: 0.61, green: 0.70, blue: 0.77, alpha: 1)
    )

    private static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { traits in traits.userInterfaceStyle == .dark ? dark : light })
    }
}
