import Foundation

/// Persisted only in Keychain. Identity is the exact account and normalized service URL;
/// passwords and account case are never normalized.
struct LuckyAccountProfile: Codable, Identifiable, Sendable, Equatable {
    let id: String
    var baseUrl: String
    var account: String
    var password: String
    var token: String
    var remark: String

    var displayName: String {
        if !remark.jsTrimmed.isEmpty { return remark.jsTrimmed }
        if !account.isEmpty { return account }
        return baseUrl
    }
}

struct LuckyAccountArchive: Codable {
    var profiles: [LuckyAccountProfile]
    var activeProfileID: String?
}
