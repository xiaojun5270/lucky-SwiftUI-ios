import SwiftUI

/// A refined atmospheric canvas with soft ambient illumination for spatial depth.
struct LuckyBackdrop: View {
    /// Kept for source compatibility with the login screen.
    var animated: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            LuckyTheme.canvasTop.ignoresSafeArea()

            // Smooth multi-stop radial glows provide spatial depth without offscreen Gaussian blur passes.
            GeometryReader { proxy in
                let width = proxy.size.width
                let isDark = colorScheme == .dark

                // Top-leading subtle accent glow
                Circle()
                    .fill(
                        RadialGradient(
                            stops: [
                                .init(color: LuckyTheme.accent.opacity(isDark ? 0.13 : 0.065), location: 0.0),
                                .init(color: LuckyTheme.accent.opacity(isDark ? 0.05 : 0.025), location: 0.45),
                                .init(color: .clear, location: 1.0),
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: width * 0.72
                        )
                    )
                    .frame(width: width * 1.44, height: width * 1.44)
                    .position(x: width * 0.2, y: -width * 0.18)

                // Top-trailing subtle secondary glow
                Circle()
                    .fill(
                        RadialGradient(
                            stops: [
                                .init(color: LuckyTheme.info.opacity(isDark ? 0.09 : 0.045), location: 0.0),
                                .init(color: LuckyTheme.info.opacity(isDark ? 0.035 : 0.015), location: 0.48),
                                .init(color: .clear, location: 1.0),
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: width * 0.62
                        )
                    )
                    .frame(width: width * 1.24, height: width * 1.24)
                    .position(x: width * 0.85, y: width * 0.1)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }
}
