import SwiftUI

/// The neutral workspace behind every screen.
///
/// A soft accent bloom at the top of the canvas gives the page a sense of depth and warmth
/// without fighting the content layer. The gradient fades to nothing within the top third of the
/// screen, so it is invisible once cards start and never shows under the tab bar.
struct LuckyBackdrop: View {
    /// Kept for source compatibility with the login screen.
    var animated: Bool = false

    var body: some View {
        ZStack(alignment: .top) {
            LuckyTheme.canvasTop
                .ignoresSafeArea()
            // Accent bloom — opacity is deliberately subconscious: visible when you look for it,
            // absent when you don't. 0.052 in light / the same value resolves well because the
            // accent is already high-chroma and the canvas is near-white / near-black.
            LinearGradient(
                colors: [LuckyTheme.accent.opacity(0.052), .clear],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.36)
            )
            .ignoresSafeArea()
        }
    }
}
