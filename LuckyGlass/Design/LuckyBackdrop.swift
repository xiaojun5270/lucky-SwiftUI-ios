import SwiftUI

/// The neutral workspace behind every screen.
///
/// Depth belongs to content hierarchy rather than decoration, so the workspace stays neutral.
struct LuckyBackdrop: View {
    /// Kept for source compatibility with the login screen.
    var animated: Bool = false

    var body: some View {
        LuckyTheme.canvasTop.ignoresSafeArea()
    }
}
