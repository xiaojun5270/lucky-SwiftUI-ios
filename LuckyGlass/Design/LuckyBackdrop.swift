import SwiftUI

/// A neutral grouped background shared by content and system navigation.
struct LuckyBackdrop: View {
    /// Kept for source compatibility with the login screen.
    var animated: Bool = false

    var body: some View {
        LuckyTheme.canvasTop.ignoresSafeArea()
    }
}
