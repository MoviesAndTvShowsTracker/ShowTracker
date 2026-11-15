import SwiftUI

struct SkeletonBlock: View {
    @Environment(\.marqueeTheme) private var theme
    var height: CGFloat = 16
    var width: CGFloat? = nil
    var radius: CGFloat = 10

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(theme.oliveSoft)
            .frame(width: width, height: height)
            .shimmering()
    }
}

struct DetailPageSkeleton: View {
    @Environment(\.marqueeTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SkeletonBlock(height: 220, radius: 0)
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 14) {
                    SkeletonBlock(height: 132, width: 88, radius: 12)
                    VStack(alignment: .leading, spacing: 8) {
                        SkeletonBlock(height: 22, width: 180)
                        SkeletonBlock(height: 14, width: 120)
                        SkeletonBlock(height: 12, width: 80)
                    }
                    .padding(.top, 8)
                }
                HStack(spacing: 10) {
                    ForEach(0..<3, id: \.self) { _ in
                        SkeletonBlock(height: 52, radius: 14)
                    }
                }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(0..<6, id: \.self) { _ in
                        SkeletonBlock(height: 56, radius: 12)
                    }
                }
            }
            .padding(20)
        }
        .background(theme.surface)
    }
}

struct RailSkeleton: View {
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(0..<5, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: 8) {
                        SkeletonBlock(height: 165, width: 110, radius: 12)
                        SkeletonBlock(height: 12, width: 90)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

struct ProfileSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 14) {
                SkeletonBlock(height: 56, width: 56, radius: 16)
                VStack(alignment: .leading, spacing: 8) {
                    SkeletonBlock(height: 10, width: 72)
                    SkeletonBlock(height: 22, width: 140)
                    SkeletonBlock(height: 12, width: 180)
                }
                Spacer()
            }
            SkeletonBlock(height: 148, radius: 20)
            HStack(spacing: 10) {
                SkeletonBlock(height: 72, radius: 14)
                SkeletonBlock(height: 72, radius: 14)
                SkeletonBlock(height: 72, radius: 14)
            }
            rail
            rail
        }
    }

    private var rail: some View {
        VStack(alignment: .leading, spacing: 12) {
            SkeletonBlock(height: 18, width: 120)
            RailSkeleton()
                .padding(.horizontal, -20)
        }
    }
}

struct LandingSkeleton: View {
    var showLibrary: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            SkeletonBlock(height: 210, radius: 22)
                .padding(.horizontal, 20)
            if showLibrary {
                VStack(alignment: .leading, spacing: 12) {
                    SkeletonBlock(height: 18, width: 110)
                    SkeletonBlock(height: 132, radius: 20)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(0..<3, id: \.self) { _ in
                            SkeletonBlock(height: 150, radius: 12)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            VStack(alignment: .leading, spacing: 12) {
                SkeletonBlock(height: 18, width: 140)
                    .padding(.horizontal, 20)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(0..<6, id: \.self) { _ in
                        SkeletonBlock(height: 150, radius: 12)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.vertical, 16)
    }
}

private struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay {
                if !reduceMotion {
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.35), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .offset(x: phase * 200)
                    .onAppear {
                        withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                            phase = 1.2
                        }
                    }
                }
            }
            .mask(content)
    }
}

extension View {
    func shimmering() -> some View {
        modifier(ShimmerModifier())
    }
}
