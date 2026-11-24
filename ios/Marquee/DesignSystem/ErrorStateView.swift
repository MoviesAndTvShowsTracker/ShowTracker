import SwiftUI

struct ErrorStateView: View {
    @Environment(\.marqueeTheme) private var theme
    var title: String = "Something went wrong"
    var message: String
    var retryTitle: String = "Try again"
    var retry: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .font(.title2.weight(.semibold))
                .foregroundStyle(theme.olive)
            Text(title)
                .font(.headline)
                .foregroundStyle(theme.ink)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(theme.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
            if let retry {
                Button(retryTitle, action: retry)
                    .buttonStyle(SecondaryButtonStyle())
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(theme.surfaceElevated)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(theme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 20)
        .accessibilityElement(children: .combine)
    }
}

struct InlineErrorBanner: View {
    @Environment(\.marqueeTheme) private var theme
    var message: String
    var retry: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(theme.accentInk)
            Text(message)
                .font(.footnote.weight(.medium))
                .foregroundStyle(theme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let retry {
                Button("Retry", action: retry)
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(theme.olive)
            }
        }
        .padding(12)
        .background(theme.accent.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 20)
    }
}
