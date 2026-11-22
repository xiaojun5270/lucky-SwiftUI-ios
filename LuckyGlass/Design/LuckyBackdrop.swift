import SwiftUI

/// A refined atmospheric canvas with soft ambient illumination for spatial depth.
struct LuckyBackdrop: View {
    /// Kept for source compatibility with the login screen.
    var animated: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            LuckyTheme.canvasTop.ignoresSafeArea()

            // Ambient illumination glow at the top for spatial hierarchy and glass refraction depth
            GeometryReader { proxy in
                let width = proxy.size.width
                let isDark = colorScheme == .dark

                // Top-leading subtle accent glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                (isDark ? LuckyTheme.accent.opacity(0.12) : LuckyTheme.accent.opacity(0.06)),
                                .clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: width * 0.65
                        )
                    )
                    .frame(width: width * 1.3, height: width * 1.3)
                    .position(x: width * 0.2, y: -width * 0.2)
                    .blur(radius: 60)

                // Top-trailing subtle secondary glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                (isDark ? LuckyTheme.info.opacity(0.08) : LuckyTheme.info.opacity(0.04)),
                                .clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: width * 0.55
                        )
                    )
                    .frame(width: width * 1.1, height: width * 1.1)
                    .position(x: width * 0.85, y: width * 0.1)
                    .blur(radius: 50)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }
}
