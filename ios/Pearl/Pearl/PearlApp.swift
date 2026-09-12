import SwiftUI
import UIKit

@main
struct PearlApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(Color.pearlAccent)
        }
    }
}

private struct RootView: View {
    var body: some View {
        AppShellView()
    }
}

private struct AppShellView: View {
    @State private var tab = 1

    var body: some View {
        TabView(selection: $tab) {
            HomeView { tab = 1 }
                .tabItem { Label("家", systemImage: "house") }
                .tag(0)

            ChatView()
                .tabItem { Label("说话", systemImage: "bubble.left.and.bubble.right") }
                .tag(1)

            DaysView()
                .tabItem { Label("日子", systemImage: "calendar") }
                .tag(2)
        }
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
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
    static let pearlLavender = adaptive(
        light: UIColor(red: 0.49, green: 0.44, blue: 0.63, alpha: 1),
        dark: UIColor(red: 0.68, green: 0.62, blue: 0.79, alpha: 1)
    )

    private static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { traits in traits.userInterfaceStyle == .dark ? dark : light })
    }
}

struct PearlBackdrop: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.pearlBackground
                AsyncImage(url: URL(string: scheme == .dark ? "/assets/tidal-echo/chat-harbor.webp" : "/assets/tidal-echo/chat-light.webp",
                                    relativeTo: ChatAPI.baseURL)?.absoluteURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: { Color.clear }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
                .opacity(scheme == .dark ? 0.25 : 0.46)
                LinearGradient(colors: scheme == .dark
                    ? [Color.black.opacity(0.44), Color.black.opacity(0.66)]
                    : [Color.white.opacity(0.12), Color.pearlBackground.opacity(0.18)],
                    startPoint: .top, endPoint: .bottom)
            }
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
