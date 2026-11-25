import SwiftUI

/// Settings → Export your diary: pick a format, prepare the file, share or save it.
struct ExportDiaryView: View {
    @Environment(\.marqueeTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Phase: Equatable {
        case idle
        case preparing
        case ready(URL, bytes: Int)
        case failed(String)
    }

    @State private var format: DiaryExportFormat = .csv
    @State private var phase: Phase = .idle

    private var motion: Animation? { reduceMotion ? nil : MarqueeMotion.standard }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Take your diary with you")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(theme.ink)
                    Text("Every film and episode you've logged, with the dates, ratings and notes you gave them.")
                        .font(.subheadline)
                        .foregroundStyle(theme.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 12) {
                    ForEach(DiaryExportFormat.allCases) { option in
                        formatCard(option)
                    }
                }

                Text("The file is made fresh each time and stays on your phone until you share or save it.")
                    .font(.caption)
                    .foregroundStyle(theme.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
        }
        .safeAreaInset(edge: .bottom) { actionBar }
        .marqueeCanvas()
        .navigationTitle("Export")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: format) { _, _ in reset() }
        .onDisappear { reset() }
        .animation(motion, value: phase)
    }

    private func formatCard(_ option: DiaryExportFormat) -> some View {
        let selected = option == format
        return Button {
            Haptics.light()
            format = option
        } label: {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: option.systemImage)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(theme.olive)
                    .frame(width: 40, height: 40)
                    .background(theme.oliveSoft, in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text(option.title)
                        .font(.headline)
                        .foregroundStyle(theme.ink)
                    Text(option.detail)
                        .font(.subheadline)
                        .foregroundStyle(theme.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 8)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected ? theme.olive : theme.border)
                    .contentTransition(.symbolEffect(.replace))
            }
            .padding(16)
            .background(theme.surfaceElevated, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(selected ? theme.olive.opacity(0.55) : theme.border, lineWidth: selected ? 1.5 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PressablePosterStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder
    private var actionBar: some View {
        VStack(spacing: 10) {
            switch phase {
            case .ready(let url, let bytes):
                ShareLink(item: url) {
                    Label("Share \(url.lastPathComponent)", systemImage: "square.and.arrow.up")
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
                Text(DiaryExportFormat.sizeText(bytes: bytes))
                    .font(.caption.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(theme.inkMuted)
            case .failed(let message):
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(theme.accentInk)
                    .multilineTextAlignment(.center)
                prepareButton(title: "Try again")
            case .idle, .preparing:
                prepareButton(title: "Prepare export")
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private func prepareButton(title: String) -> some View {
        Button {
            Task { await prepare() }
        } label: {
            Group {
                if phase == .preparing {
                    ProgressView().tint(theme.onAccent)
                } else {
                    Text(title)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(phase == .preparing)
    }

    private func prepare() async {
        phase = .preparing
        do {
            let file = try await DiaryService.exportDiary(format)
            phase = .ready(file.url, bytes: file.bytes)
            Haptics.success()
        } catch {
            phase = .failed("Couldn't prepare your export. \(error.localizedDescription)")
        }
    }

    private func reset() {
        if case .ready(let url, _) = phase { try? FileManager.default.removeItem(at: url) }
        phase = .idle
    }
}
