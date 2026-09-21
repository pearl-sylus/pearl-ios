import Foundation
import SwiftUI
import UIKit

@MainActor
final class Theme: ObservableObject {
    enum Wallpaper: String, CaseIterable, Identifiable {
        case light
        case harbor
        case plain
        case custom

        var id: String { rawValue }
        var label: String {
            switch self {
            case .light: return "水光"
            case .harbor: return "港湾"
            case .plain: return "纯色"
            case .custom: return "相册"
            }
        }
        var assetName: String? {
            switch self {
            case .light: return "ChatLight"
            case .harbor: return "ChatHarbor"
            case .plain, .custom: return nil
            }
        }
    }

    enum VeilTone: String, CaseIterable, Identifiable {
        case light
        case dark

        var id: String { rawValue }
        var label: String { self == .light ? "白纱" : "黑纱" }
    }

    enum TextWeight: String, CaseIterable, Identifiable {
        case regular
        case medium

        var id: String { rawValue }
        var label: String { self == .regular ? "常规" : "中黑" }
        var fontWeight: Font.Weight { self == .regular ? .regular : .medium }
    }

    enum ChatFont: String, CaseIterable, Identifiable {
        case system
        case wenkai
        case serif
        case round
        case xiaolai
        case yozai
        case zhuque

        var id: String { rawValue }
        var label: String {
            switch self {
            case .system: return "苹方"
            case .wenkai: return "霞鹜文楷"
            case .serif: return "思源宋"
            case .round: return "寒蝉圆"
            case .xiaolai: return "小赖"
            case .yozai: return "悠哉"
            case .zhuque: return "朱雀仿宋"
            }
        }
        var familyName: String? {
            switch self {
            case .system: return nil
            case .wenkai: return "LXGW WenKai Screen"
            case .serif: return "Noto Serif SC"
            case .round: return "ChillRoundF"
            case .xiaolai: return "Xiaolai"
            case .yozai: return "Yozai"
            case .zhuque: return "Zhuque Fangsong (technical preview)"
            }
        }
    }

    enum FontRole {
        case navigationTitle
        case navigationSubtitle
        case gauge
        case bubble
        case metadata
        case thinkingLabel
        case thinkingBody
        case composer
        case control
        case cardTitle
        case cardBody
        case toolDetail
    }

    enum Metric {
        static let zero: CGFloat = 0
        static let hairline: CGFloat = 0.5
        static let thinLine: CGFloat = 1
        static let highlightLine: CGFloat = 1.5
        static let tiny: CGFloat = 2
        static let small: CGFloat = 4
        static let metadataInset: CGFloat = 5
        static let compact: CGFloat = 6
        static let standard: CGFloat = 8
        static let roomy: CGFloat = 10
        static let large: CGFloat = 12
        static let chatHorizontal: CGFloat = 14
        static let bubbleHorizontal: CGFloat = 15
        static let section: CGFloat = 16
        static let composerHorizontal: CGFloat = 10
        static let composerBottom: CGFloat = 7
        static let bubbleRadius: CGFloat = 22
        static let thinkRadius: CGFloat = 16
        static let toolRadius: CGFloat = 13
        static let cardRadius: CGFloat = 16
        static let imageRadius: CGFloat = 14
        static let thumbnailRadius: CGFloat = 10
        static let bubbleMaxWidth: CGFloat = 320
        static let thinkMaxWidth: CGFloat = 520
        static let cardMaxWidth: CGFloat = 560
        static let stepMaxWidth: CGFloat = 520
        static let cardIcon: CGFloat = 28
        static let voiceControl: CGFloat = 24
        static let voiceMinWidth: CGFloat = 126
        static let waveWidth: CGFloat = 3
        static let voiceBars: [CGFloat] = [8, 14, 20, 12, 17]
        static let musicCover: CGFloat = 48
        static let tarotWidth: CGFloat = 42
        static let tarotHeight: CGFloat = 58
        static let detailPadding: CGFloat = 24
        static let imagePlaceholderHeight: CGFloat = 150
        static let imageErrorHeight: CGFloat = 90
        static let attachmentSize: CGFloat = 58
        static let iconButtonSize: CGFloat = 34
        static let sendButtonSize: CGFloat = 42
        static let composerButton: CGFloat = 38
        static let gaugeSize: CGFloat = 27
        static let gaugeLine: CGFloat = 3
        static let topBarHeight: CGFloat = 52
        static let topButton: CGFloat = 32
        static let appearancePreviewHeight: CGFloat = 74
        static let appearanceSwatch: CGFloat = 28
        static let appearanceSheetCorner: CGFloat = 24
        static let shadowRadius: CGFloat = 28
        static let shadowY: CGFloat = 10
        static let smallShadowRadius: CGFloat = 2
        static let smallShadowY: CGFloat = 1
        static let shineMidpoint: CGFloat = 0.38
        static let shineEnd: CGFloat = 0.60
        static let customWallpaperMaxDimension: CGFloat = 1800
        static let customWallpaperQuality: CGFloat = 0.82
        static let disabledOpacity = 0.45
    }

    enum Defaults {
        static let accent = "#526b81"
        static let cardSolid = "#f5f7f9"
        static let mineSolid = "#dfe7ee"
        static let fieldSolid = "#f8fbfc"
        static let bubbleText = "#2b2a2a"
        static let metaText = "#3a3a3e"
        static let thinkLabel = "#8e8e93"
        static let thinkText = "#6a6a70"
        static let backgroundLight = "#eef4f7"
        static let backgroundDark = "#111820"
        static let warning = "#d0483a"
        static let success = "#5f7f69"
        static let white = "#ffffff"
        static let black = "#000000"
        static let glassAlpha = 0.92
        static let glassBlur = 18.0
        static let glassTint = 0.12
        static let veilAlpha = 0.18
        static let wallpaper = Wallpaper.light
        static let veilTone = VeilTone.light
        static let font = ChatFont.wenkai
        static let textWeight = TextWeight.medium
        static let bodySize = 15.0
        static let glassEnabled = true
    }

    private enum Key {
        static let prefix = "chatAppearance.v2."
        static let accent = prefix + "accent"
        static let cardSolid = prefix + "cardSolid"
        static let mineSolid = prefix + "mineSolid"
        static let fieldSolid = prefix + "fieldSolid"
        static let bubbleText = prefix + "bubbleText"
        static let metaText = prefix + "metaText"
        static let thinkLabel = prefix + "thinkLabel"
        static let thinkText = prefix + "thinkText"
        static let glassAlpha = prefix + "glassAlpha"
        static let glassBlur = prefix + "glassBlur"
        static let glassTint = prefix + "glassTint"
        static let glassEnabled = prefix + "glassEnabled"
        static let wallpaper = prefix + "wallpaper"
        static let wallpaperPath = prefix + "wallpaperPath"
        static let veilTone = prefix + "veilTone"
        static let veilAlpha = prefix + "veilAlpha"
        static let font = prefix + "font"
        static let textWeight = prefix + "textWeight"
        static let bodySize = prefix + "bodySize"
    }

    private let defaults: UserDefaults

    @Published var accentHex: String { didSet { defaults.set(accentHex, forKey: Key.accent) } }
    @Published var cardSolidHex: String { didSet { defaults.set(cardSolidHex, forKey: Key.cardSolid) } }
    @Published var mineSolidHex: String { didSet { defaults.set(mineSolidHex, forKey: Key.mineSolid) } }
    @Published var fieldSolidHex: String { didSet { defaults.set(fieldSolidHex, forKey: Key.fieldSolid) } }
    @Published var bubbleTextHex: String { didSet { defaults.set(bubbleTextHex, forKey: Key.bubbleText) } }
    @Published var metaTextHex: String { didSet { defaults.set(metaTextHex, forKey: Key.metaText) } }
    @Published var thinkLabelHex: String { didSet { defaults.set(thinkLabelHex, forKey: Key.thinkLabel) } }
    @Published var thinkTextHex: String { didSet { defaults.set(thinkTextHex, forKey: Key.thinkText) } }
    @Published var glassAlpha: Double { didSet { defaults.set(glassAlpha, forKey: Key.glassAlpha) } }
    @Published var glassBlur: Double { didSet { defaults.set(glassBlur, forKey: Key.glassBlur) } }
    @Published var glassTint: Double { didSet { defaults.set(glassTint, forKey: Key.glassTint) } }
    @Published var glassEnabled: Bool { didSet { defaults.set(glassEnabled, forKey: Key.glassEnabled) } }
    @Published var wallpaper: Wallpaper { didSet { defaults.set(wallpaper.rawValue, forKey: Key.wallpaper) } }
    @Published var customWallpaperPath: String { didSet { defaults.set(customWallpaperPath, forKey: Key.wallpaperPath) } }
    @Published var veilTone: VeilTone { didSet { defaults.set(veilTone.rawValue, forKey: Key.veilTone) } }
    @Published var veilAlpha: Double { didSet { defaults.set(veilAlpha, forKey: Key.veilAlpha) } }
    @Published var fontChoice: ChatFont { didSet { defaults.set(fontChoice.rawValue, forKey: Key.font) } }
    @Published var textWeight: TextWeight { didSet { defaults.set(textWeight.rawValue, forKey: Key.textWeight) } }
    @Published var bodySize: Double { didSet { defaults.set(bodySize, forKey: Key.bodySize) } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        accentHex = defaults.string(forKey: Key.accent) ?? Defaults.accent
        cardSolidHex = defaults.string(forKey: Key.cardSolid) ?? Defaults.cardSolid
        mineSolidHex = defaults.string(forKey: Key.mineSolid) ?? Defaults.mineSolid
        fieldSolidHex = defaults.string(forKey: Key.fieldSolid) ?? Defaults.fieldSolid
        bubbleTextHex = defaults.string(forKey: Key.bubbleText) ?? Defaults.bubbleText
        metaTextHex = defaults.string(forKey: Key.metaText) ?? Defaults.metaText
        thinkLabelHex = defaults.string(forKey: Key.thinkLabel) ?? Defaults.thinkLabel
        thinkTextHex = defaults.string(forKey: Key.thinkText) ?? Defaults.thinkText
        glassAlpha = Self.savedDouble(defaults, Key.glassAlpha, Defaults.glassAlpha)
        glassBlur = Self.savedDouble(defaults, Key.glassBlur, Defaults.glassBlur)
        glassTint = Self.savedDouble(defaults, Key.glassTint, Defaults.glassTint)
        glassEnabled = defaults.object(forKey: Key.glassEnabled) as? Bool ?? Defaults.glassEnabled
        wallpaper = Wallpaper(rawValue: defaults.string(forKey: Key.wallpaper) ?? "") ?? Defaults.wallpaper
        customWallpaperPath = defaults.string(forKey: Key.wallpaperPath) ?? ""
        veilTone = VeilTone(rawValue: defaults.string(forKey: Key.veilTone) ?? "") ?? Defaults.veilTone
        veilAlpha = Self.savedDouble(defaults, Key.veilAlpha, Defaults.veilAlpha)
        fontChoice = ChatFont(rawValue: defaults.string(forKey: Key.font) ?? "") ?? Defaults.font
        textWeight = TextWeight(rawValue: defaults.string(forKey: Key.textWeight) ?? "") ?? Defaults.textWeight
        bodySize = Self.savedDouble(defaults, Key.bodySize, Defaults.bodySize)
        if wallpaper == .custom && customWallpaperImage == nil { wallpaper = Defaults.wallpaper }
    }

    var accent: Color { Self.color(accentHex) }
    var cardSolid: Color { Self.color(cardSolidHex) }
    var mineSolid: Color { Self.color(mineSolidHex) }
    var fieldSolid: Color { Self.color(fieldSolidHex) }
    var bubbleText: Color { Self.color(bubbleTextHex) }
    var metaText: Color { Self.color(metaTextHex) }
    var thinkLabel: Color { Self.color(thinkLabelHex) }
    var thinkText: Color { Self.color(thinkTextHex) }
    var warning: Color { Self.color(Defaults.warning) }
    var success: Color { Self.color(Defaults.success) }
    var tarotBack: Color { accent.opacity(0.34) }
    var composerButtonFill: Color { cardSolid.opacity(0.72) }
    var composerShadow: Color { black.opacity(0.09) }
    var gaugeTrack: Color { metaText.opacity(0.20) }
    var timestampText: Color { metaText.opacity(0.72) }
    var white: Color { Self.color(Defaults.white) }
    var black: Color { Self.color(Defaults.black) }
    var clear: Color { white.opacity(0) }
    var backgroundLight: Color { Self.color(Defaults.backgroundLight) }
    var backgroundDark: Color { Self.color(Defaults.backgroundDark) }

    var customWallpaperImage: UIImage? {
        guard !customWallpaperPath.isEmpty else { return nil }
        return UIImage(contentsOfFile: customWallpaperPath)
    }

    func background(for scheme: ColorScheme) -> Color {
        scheme == .dark ? backgroundDark : backgroundLight
    }

    func veilColor() -> Color {
        (veilTone == .dark ? black : white).opacity(veilAlpha)
    }

    func rim(for scheme: ColorScheme) -> Color {
        white.opacity(scheme == .dark ? 0.14 : 0.62)
    }

    func primaryShadow(for scheme: ColorScheme) -> Color {
        black.opacity(scheme == .dark ? 0.35 : 0.10)
    }

    func secondaryShadow(for scheme: ColorScheme) -> Color {
        black.opacity(scheme == .dark ? 0.18 : 0.05)
    }

    var bubbleLineSpacing: CGFloat { CGFloat(bodySize * 0.60) }
    var thinkingLineSpacing: CGFloat { 13.5 * 0.70 }

    func shine(for scheme: ColorScheme) -> LinearGradient {
        let strength = scheme == .dark ? 0.12 : 0.42
        return LinearGradient(
            stops: [
                .init(color: white.opacity(strength), location: Metric.zero),
                .init(color: white.opacity(scheme == .dark ? 0 : 0.08), location: scheme == .dark ? 0.55 : Metric.shineMidpoint),
                .init(color: clear, location: scheme == .dark ? 0.55 : Metric.shineEnd)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    func bubbleFill(mine: Bool) -> Color {
        let base = mine ? mineSolidHex : cardSolidHex
        let accentPart = min(1, glassTint * (mine ? 2.2 : 1.0 / 3.0))
        return Self.mix(base, accentHex, accentPart,
                        over: fieldSolidHex,
                        opacity: glassEnabled ? glassAlpha : 1)
    }

    func panelFill() -> Color {
        Self.mix(fieldSolidHex, accentHex, glassTint / 2).opacity(glassEnabled ? max(glassAlpha, 0.60) : 1)
    }

    func thinkingFill() -> Color {
        cardSolid.opacity(glassEnabled ? max(glassAlpha * 0.70, 0.50) : 1)
    }

    func embeddedCardFill() -> Color { white.opacity(0.28) }

    func voiceFill(mine: Bool) -> Color {
        (mine ? cardSolid : accent).opacity(mine ? 0.76 : 0.88)
    }

    func voiceControlFill(mine: Bool) -> Color {
        (mine ? accent : white).opacity(0.18)
    }

    func voiceForeground(mine: Bool) -> Color { mine ? accent : white }

    func font(_ role: FontRole) -> Font {
        let spec: (CGFloat, Font.Weight) = {
            switch role {
            case .navigationTitle: return (18, .medium)
            case .navigationSubtitle: return (10.5, .regular)
            case .gauge: return (8, .bold)
            case .bubble: return (CGFloat(bodySize), textWeight.fontWeight)
            case .metadata: return (12, .regular)
            case .thinkingLabel: return (12.5, .regular)
            case .thinkingBody: return (13.5, .regular)
            case .composer: return (15.5, textWeight.fontWeight)
            case .control: return (13, .regular)
            case .cardTitle: return (15, .semibold)
            case .cardBody: return (13, .regular)
            case .toolDetail: return (12, .regular)
            }
        }()
        if let family = fontChoice.familyName {
            return .custom(family, fixedSize: spec.0).weight(spec.1)
        }
        return .system(size: spec.0, weight: spec.1)
    }

    func installCustomWallpaper(_ data: Data) throws {
        guard let original = UIImage(data: data) else { throw WallpaperError.unreadable }
        let longest = max(original.size.width, original.size.height)
        let scale = min(1, Metric.customWallpaperMaxDimension / longest)
        let target = CGSize(width: original.size.width * scale, height: original.size.height * scale)
        let image = UIGraphicsImageRenderer(size: target).image { _ in
            original.draw(in: CGRect(origin: .zero, size: target))
        }
        guard let jpeg = image.jpegData(compressionQuality: Metric.customWallpaperQuality) else {
            throw WallpaperError.unreadable
        }
        let support = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("PearlAppearance", isDirectory: true)
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        let destination = support.appendingPathComponent("custom-wallpaper.jpg")
        try jpeg.write(to: destination, options: .atomic)
        customWallpaperPath = destination.path
        wallpaper = .custom
    }

    func reset() {
        accentHex = Defaults.accent
        cardSolidHex = Defaults.cardSolid
        mineSolidHex = Defaults.mineSolid
        fieldSolidHex = Defaults.fieldSolid
        bubbleTextHex = Defaults.bubbleText
        metaTextHex = Defaults.metaText
        thinkLabelHex = Defaults.thinkLabel
        thinkTextHex = Defaults.thinkText
        glassAlpha = Defaults.glassAlpha
        glassBlur = Defaults.glassBlur
        glassTint = Defaults.glassTint
        glassEnabled = Defaults.glassEnabled
        wallpaper = Defaults.wallpaper
        veilTone = Defaults.veilTone
        veilAlpha = Defaults.veilAlpha
        fontChoice = Defaults.font
        textWeight = Defaults.textWeight
        bodySize = Defaults.bodySize
    }

    static func color(_ hex: String) -> Color {
        let value = UInt64(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0
        return Color(
            uiColor: UIColor(
                red: CGFloat((value >> 16) & 0xff) / 255,
                green: CGFloat((value >> 8) & 0xff) / 255,
                blue: CGFloat(value & 0xff) / 255,
                alpha: 1
            )
        )
    }

    static func hexString(from color: Color) -> String {
        let resolved = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return Defaults.black }
        return String(format: "#%02x%02x%02x", Int(red * 255), Int(green * 255), Int(blue * 255))
    }

    private static func mix(
        _ base: String,
        _ tint: String,
        _ amount: Double,
        over backdrop: String? = nil,
        opacity: Double = 1
    ) -> Color {
        let a = rgb(base)
        let b = rgb(tint)
        let part = min(1, max(0, amount))
        let partValue = CGFloat(part)
        var result = (
            a.0 + (b.0 - a.0) * partValue,
            a.1 + (b.1 - a.1) * partValue,
            a.2 + (b.2 - a.2) * partValue
        )
        if let backdrop {
            let background = rgb(backdrop)
            let alpha = CGFloat(min(1, max(0, opacity)))
            result = (
                background.0 + (result.0 - background.0) * alpha,
                background.1 + (result.1 - background.1) * alpha,
                background.2 + (result.2 - background.2) * alpha
            )
        }
        return Color(
            uiColor: UIColor(
                red: result.0,
                green: result.1,
                blue: result.2,
                alpha: 1
            )
        )
    }

    private static func rgb(_ hex: String) -> (CGFloat, CGFloat, CGFloat) {
        let value = UInt64(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0
        return (
            CGFloat((value >> 16) & 0xff) / 255,
            CGFloat((value >> 8) & 0xff) / 255,
            CGFloat(value & 0xff) / 255
        )
    }

    private static func savedDouble(_ defaults: UserDefaults, _ key: String, _ fallback: Double) -> Double {
        defaults.object(forKey: key) == nil ? fallback : defaults.double(forKey: key)
    }

    enum WallpaperError: LocalizedError {
        case unreadable
        var errorDescription: String? { "这张图片没读到" }
    }
}
