import PhotosUI
import SwiftUI

struct AppearanceSettings: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var theme: Theme
    @State private var pickedWallpaper: PhotosPickerItem?
    @State private var wallpaperError = ""

    var body: some View {
        NavigationStack {
            Form {
                wallpaperSection
                glassSection
                colorSection
                fontSection
                readabilitySection
                Section {
                    Button("恢复默认") { theme.reset() }
                        .foregroundStyle(theme.warning)
                }
            }
            .navigationTitle("外观")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .onChange(of: pickedWallpaper) { item in
                guard let item else { return }
                Task { await importWallpaper(item) }
            }
        }
    }

    private var wallpaperSection: some View {
        Section("壁纸") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Metric.standard) {
                    ForEach([Theme.Wallpaper.light, .harbor, .plain]) { wallpaper in
                        wallpaperButton(wallpaper)
                    }
                    PhotosPicker(selection: $pickedWallpaper, matching: .images) {
                        wallpaperPreview(.custom)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("从相册选择壁纸")
                }
                .padding(.vertical, Theme.Metric.small)
            }
            Picker("遮纱", selection: $theme.veilTone) {
                ForEach(Theme.VeilTone.allCases) { tone in Text(tone.label).tag(tone) }
            }
            .pickerStyle(.segmented)
            settingSlider("遮纱浓度", value: $theme.veilAlpha, range: 0...0.60, format: percent)
            if !wallpaperError.isEmpty {
                Text(wallpaperError).font(theme.font(.metadata)).foregroundStyle(theme.warning)
            }
        }
    }

    private var glassSection: some View {
        Section("玻璃") {
            Toggle("玻璃效果", isOn: $theme.glassEnabled)
            settingSlider("模糊", value: $theme.glassBlur, range: 0...40) { "\(Int($0)) pt" }
                .disabled(!theme.glassEnabled)
            settingSlider("不透明度", value: $theme.glassAlpha, range: 0.60...1, format: percent)
            settingSlider("主题色掺入", value: $theme.glassTint, range: 0...0.40, format: percent)
        }
    }

    private var colorSection: some View {
        Section("颜色") {
            colorPicker("主题色", path: \Theme.accentHex)
            colorPicker("她的气泡", path: \Theme.mineSolidHex)
            colorPicker("他的气泡", path: \Theme.cardSolidHex)
            colorPicker("正文字色", path: \Theme.bubbleTextHex)
            colorPicker("思考链字色", path: \Theme.thinkTextHex)
        }
    }

    private var fontSection: some View {
        Section("字体") {
            Picker("字体", selection: $theme.fontChoice) {
                ForEach(Theme.ChatFont.allCases) { choice in
                    Text(choice.label).tag(choice)
                }
            }
            Text("霞鹜文楷已随 App 打包；其余非系统字体会在后续补入。")
                .font(theme.font(.metadata))
                .foregroundStyle(theme.metaText)
        }
    }

    private var readabilitySection: some View {
        Section("可读性") {
            Picker("字重", selection: $theme.textWeight) {
                ForEach(Theme.TextWeight.allCases) { weight in Text(weight.label).tag(weight) }
            }
            .pickerStyle(.segmented)
            Picker("字号", selection: $theme.bodySize) {
                ForEach([14.0, 15.0, 16.0], id: \.self) { size in Text("\(Int(size))").tag(size) }
            }
            .pickerStyle(.segmented)
        }
    }

    private func wallpaperButton(_ wallpaper: Theme.Wallpaper) -> some View {
        Button { theme.wallpaper = wallpaper } label: { wallpaperPreview(wallpaper) }
            .buttonStyle(.plain)
    }

    private func wallpaperPreview(_ wallpaper: Theme.Wallpaper) -> some View {
        VStack(spacing: Theme.Metric.small) {
            Group {
                if let name = wallpaper.assetName {
                    Image(name).resizable().scaledToFill()
                } else if wallpaper == .custom, let image = theme.customWallpaperImage {
                    Image(uiImage: image).resizable().scaledToFill()
                } else if wallpaper == .custom {
                    theme.panelFill().overlay(Image(systemName: "photo.badge.plus"))
                } else {
                    theme.backgroundLight
                }
            }
            .frame(width: Theme.Metric.appearancePreviewHeight, height: Theme.Metric.appearancePreviewHeight)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Metric.thumbnailRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Metric.thumbnailRadius, style: .continuous)
                    .stroke(theme.wallpaper == wallpaper ? theme.accent : theme.rim(for: .light),
                            lineWidth: theme.wallpaper == wallpaper ? Theme.Metric.highlightLine : Theme.Metric.thinLine)
            }
            Text(wallpaper.label).font(theme.font(.metadata)).foregroundStyle(theme.metaText)
        }
    }

    private func settingSlider(
        _ title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        format: @escaping (Double) -> String
    ) -> some View {
        VStack(spacing: Theme.Metric.compact) {
            HStack {
                Text(title)
                Spacer()
                Text(format(value.wrappedValue)).foregroundStyle(theme.metaText)
            }
            Slider(value: value, in: range)
        }
    }

    private func colorPicker(_ title: String, path: ReferenceWritableKeyPath<Theme, String>) -> some View {
        ColorPicker(title, selection: Binding(
            get: { Theme.color(theme[keyPath: path]) },
            set: { theme[keyPath: path] = Theme.hexString(from: $0) }
        ), supportsOpacity: false)
    }

    private func percent(_ value: Double) -> String { "\(Int((value * 100).rounded()))%" }

    private func importWallpaper(_ item: PhotosPickerItem) async {
        defer { pickedWallpaper = nil }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw Theme.WallpaperError.unreadable
            }
            try theme.installCustomWallpaper(data)
            wallpaperError = ""
        } catch {
            wallpaperError = error.localizedDescription
        }
    }
}
