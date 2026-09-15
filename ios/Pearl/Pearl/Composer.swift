import PhotosUI
import SwiftUI

struct Composer: View {
    @EnvironmentObject private var theme: Theme
    @ObservedObject var model: ChatViewModel
    let openControls: () -> Void
    @State private var pickedPhotos: [PhotosPickerItem] = []
    @FocusState private var focused: Bool

    private var canSend: Bool {
        model.isStreaming
            || !model.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !model.pendingImages.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Metric.compact) {
            attachments
            TextField(model.isRecording ? "正在录音…" : "把想说的放进来", text: $model.draft, axis: .vertical)
                .font(theme.font(.composer))
                .foregroundStyle(theme.bubbleText)
                .lineLimit(1...6)
                .focused($focused)
                .padding(.horizontal, Theme.Metric.small)
                .padding(.vertical, Theme.Metric.standard)
                .disabled(model.isRecording)
            HStack(spacing: Theme.Metric.standard) {
                PhotosPicker(selection: $pickedPhotos, maxSelectionCount: 3, matching: .images) {
                    roundLabel("plus", fill: theme.composerButtonFill)
                }
                .disabled(model.pendingImages.count >= 3 || model.isRecording)
                .accessibilityLabel("添加图片")

                Button(action: openControls) {
                    Text(model.modelLabel)
                        .font(theme.font(.control))
                        .foregroundStyle(theme.metaText)
                        .lineLimit(1)
                        .padding(.horizontal, Theme.Metric.roomy)
                        .frame(height: Theme.Metric.composerButton)
                        .background(theme.composerButtonFill, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("模型与思考设置，当前 \(model.modelLabel)")

                Spacer(minLength: Theme.Metric.zero)

                Button { model.toggleRecording() } label: {
                    roundLabel(model.isSendingVoice ? "ellipsis" : model.isRecording ? "waveform" : "mic",
                               fill: model.isRecording ? theme.warning : theme.composerButtonFill)
                }
                .buttonStyle(.plain)
                .disabled(model.isSendingVoice)
                .accessibilityLabel(model.isRecording ? "结束并发送录音" : "录音")

                Button {
                    if model.isRecording { model.cancelRecording() }
                    else { Task { await model.sendOrStop() } }
                } label: {
                    roundLabel(model.isRecording ? "xmark" : sendIcon,
                               fill: model.isRecording ? theme.composerButtonFill : theme.accent,
                               foreground: model.isRecording ? theme.metaText : theme.white)
                }
                .buttonStyle(.plain)
                .disabled(!model.isRecording && !canSend)
                .opacity(model.isRecording || canSend ? 1 : Theme.Metric.disabledOpacity)
                .accessibilityLabel(model.isRecording ? "取消录音" : model.isStreaming ? "停止生成" : "发送")
            }
        }
        .padding(.horizontal, Theme.Metric.composerHorizontal)
        .padding(.vertical, Theme.Metric.standard)
        .background(theme.panelFill(), in: RoundedRectangle(cornerRadius: Theme.Metric.bubbleRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Metric.bubbleRadius, style: .continuous)
                .stroke(theme.rim(for: .light), lineWidth: Theme.Metric.thinLine)
        }
        .shadow(color: theme.composerShadow, radius: Theme.Metric.shadowRadius, y: Theme.Metric.standard)
        .onChange(of: pickedPhotos) { items in
            Task {
                for item in items.prefix(max(0, 3 - model.pendingImages.count)) {
                    if let data = try? await item.loadTransferable(type: Data.self) { model.addImageData(data) }
                }
                pickedPhotos = []
            }
        }
    }

    @ViewBuilder private var attachments: some View {
        if !model.pendingImages.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Metric.standard) {
                    ForEach(model.pendingImages) { item in
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: item.image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: Theme.Metric.attachmentSize, height: Theme.Metric.attachmentSize)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.Metric.thumbnailRadius))
                            Button { model.removeImage(item.id) } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(theme.white, theme.black.opacity(0.70))
                            }
                            .offset(x: Theme.Metric.small, y: -Theme.Metric.small)
                            .accessibilityLabel("移除图片")
                        }
                    }
                }
                .padding(.top, Theme.Metric.small)
            }
        }
    }

    private var sendIcon: String {
        model.isStreaming && model.draft.isEmpty && model.pendingImages.isEmpty ? "stop.fill" : "arrow.up"
    }

    private func roundLabel(_ name: String, fill: Color, foreground: Color? = nil) -> some View {
        Image(systemName: name)
            .font(theme.font(.control).weight(.bold))
            .foregroundStyle(foreground ?? theme.metaText)
            .frame(width: Theme.Metric.composerButton, height: Theme.Metric.composerButton)
            .background(fill, in: Circle())
    }
}
