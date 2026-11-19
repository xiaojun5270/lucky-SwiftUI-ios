import Foundation
import Observation

/// Immutable request context; generation separates even A → B → A switches.
struct LuckyCredentials: Sendable, Equatable {
    var baseUrl: String = ""
    var account: String = ""
    var password: String = ""
    var token: String = ""
    var generation: UInt64 = 0
}

/// All saved secrets live in Keychain, never UserDefaults. Logout clears only the
/// active token, deliberately retaining saved passwords for the existing refresh flow.
@MainActor
@Observable
final class LuckySession {
    static let shared = LuckySession()
    private static let storageKey = "lucky_app_session"
    private static let accountsKey = "lucky_app_accounts"

    private(set) var baseUrl = ""
    private(set) var account = ""
    private(set) var password = ""
    private(set) var token = ""
    private(set) var remark = ""
    private(set) var hydrated = false
    private(set) var profiles: [LuckyAccountProfile] = []
    private(set) var activeProfileID: String?
    private(set) var sessionGeneration: UInt64 = 0

    private init() {}
    var isAuthenticated: Bool { !baseUrl.isEmpty && !token.isEmpty }
    var credentials: LuckyCredentials {
        LuckyCredentials(baseUrl: baseUrl, account: account, password: password, token: token, generation: sessionGeneration)
    }

    func hydrate() async {
        if let raw = Keychain.read(Self.accountsKey),
           let archive = try? JSONDecoder().decode(LuckyAccountArchive.self, from: Data(raw.utf8)) {
            profiles = archive.profiles
            activeProfileID = archive.activeProfileID
            if let profile = profiles.first(where: { $0.id == activeProfileID }) { load(profile) }
        } else if let raw = Keychain.read(Self.storageKey), let saved = JSONParser.tryParse(raw) {
            let base = (saved["baseUrl"]?.stringValue ?? "").jsTrimmed.withoutTrailingSlashes
            if !base.isEmpty {
                let profile = LuckyAccountProfile(id: UUID().uuidString, baseUrl: base,
                    account: saved["account"]?.stringValue ?? "",
                    password: saved["password"]?.stringValue ?? "",
                    token: saved["token"]?.stringValue ?? "", remark: "")
                profiles = [profile]
                load(profile)
                persistProfiles()
            }
        }
        hydrated = true
        await syncClient()
    }

    func save(baseUrl: String, account: String, password: String, token: String, remark: String = "") async {
        let base = baseUrl.jsTrimmed.withoutTrailingSlashes
        let existing = profiles.firstIndex { $0.baseUrl == base && $0.account == account }
        let profile = LuckyAccountProfile(id: existing.map { profiles[$0].id } ?? UUID().uuidString,
            baseUrl: base, account: account, password: password, token: token, remark: remark.jsTrimmed)
        if let existing { profiles[existing] = profile } else { profiles.append(profile) }
        load(profile)
        sessionGeneration += 1
        LuckyStatusStore.shared.resetForSessionChange()
        persistProfiles()
        await syncClient()
    }

    func switchTo(profileID: String) async {
        guard profileID != activeProfileID, let profile = profiles.first(where: { $0.id == profileID }) else { return }
        load(profile)
        sessionGeneration += 1
        LuckyStatusStore.shared.resetForSessionChange()
        persistProfiles()
        await syncClient()
    }

    func saveToken(_ token: String, ifGeneration: UInt64? = nil) async {
        guard ifGeneration == nil || ifGeneration == sessionGeneration else { return }
        self.token = token
        updateActiveToken()
        await syncClient()
    }

    func end(ifGeneration: UInt64? = nil) async {
        guard ifGeneration == nil || ifGeneration == sessionGeneration else { return }
        token = ""
        updateActiveToken()
        await syncClient()
    }

    private func load(_ profile: LuckyAccountProfile) {
        activeProfileID = profile.id
        baseUrl = profile.baseUrl
        account = profile.account
        password = profile.password
        token = profile.token
        remark = profile.remark
    }

    private func updateActiveToken() {
        if let index = profiles.firstIndex(where: { $0.id == activeProfileID }) { profiles[index].token = token }
        persistProfiles()
    }

    private func persistProfiles() {
        guard let data = try? JSONEncoder().encode(LuckyAccountArchive(profiles: profiles, activeProfileID: activeProfileID)),
              let raw = String(data: data, encoding: .utf8) else { return }
        Keychain.write(Self.accountsKey, value: raw)
    }

    private func syncClient() async { await LuckyClient.shared.apply(credentials) }
}
