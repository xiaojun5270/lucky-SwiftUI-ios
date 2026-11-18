import Foundation

/// Display the installed bundle's version so the UI also reflects CI's build number.
enum LuckyAppVersion {
    static var version: String { value(for: "CFBundleShortVersionString") }
    static var build: String { value(for: "CFBundleVersion") }
    static var displayString: String { "版本 \(version)（构建 \(build)）" }

    private static func value(for key: String) -> String {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: key) as? String else { return "—" }
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? "—" : text
    }
}
