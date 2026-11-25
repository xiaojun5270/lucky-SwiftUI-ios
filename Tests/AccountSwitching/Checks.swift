import Foundation

// Only OS keychain and network/status boundaries are doubled. LuckySession is real.
enum Keychain {
    static var values: [String:String] = [:]
    static func read(_ key: String) -> String? { values[key] }
    @discardableResult static func write(_ key: String, value: String) -> Bool { values[key] = value; return true }
    @discardableResult static func delete(_ key: String) -> Bool { values.removeValue(forKey: key); return true }
}
actor LuckyClient {
    static let shared = LuckyClient()
    var snapshot = LuckyCredentials()
    func apply(_ credentials: LuckyCredentials) { snapshot = credentials }
}
@MainActor final class LuckyStatusStore {
    static let shared = LuckyStatusStore()
    var resets = 0
    func resetForSessionChange() { resets += 1 }
}
@main struct Checks {
    @MainActor static func main() async {
        Keychain.values["lucky_app_session"] = #"{"baseUrl":" https://Server/Path/// ","account":"Admin","password":" P aSs ","token":"legacy-token"}"#
        let session = LuckySession.shared
        await session.hydrate()
        precondition(session.profiles.count == 1, "legacy session must migrate into saved profiles")
        precondition(session.profiles[0].baseUrl == "https://Server/Path")
        precondition(session.profiles[0].account == "Admin")
        precondition(session.password == " P aSs ")
        precondition(session.activeProfileID == session.profiles[0].id)
        precondition(session.profiles[0].displayName == "Admin")
        print("PASS migration preserves exact account/password and normalized base URL")
        let original = session.activeProfileID!
        await session.save(baseUrl: "https://other/", account: "Admin", password: "other secret", token: "other token", remark: "  Office  ")
        precondition(session.profiles.count == 2)
        precondition(session.remark == "Office" && session.profiles.last!.displayName == "Office")
        let second = session.activeProfileID!
        let generation = session.sessionGeneration
        await session.switchTo(profileID: original)
        precondition(session.password == " P aSs " && session.token == "legacy-token")
        precondition(session.sessionGeneration != generation)
        await session.save(baseUrl: " https://Server/Path/ ", account: "Admin", password: "updated", token: "updated")
        precondition(session.profiles.count == 2 && session.activeProfileID == original)
        await session.save(baseUrl: "https://Server/Path", account: "admin", password: "case", token: "case")
        precondition(session.profiles.count == 3, "account case is part of identity")
        await session.switchTo(profileID: second)
        let savedGeneration = session.sessionGeneration
        await session.saveToken("fresh")
        precondition(session.sessionGeneration == savedGeneration)
        await session.end()
        precondition(session.profiles.count == 3 && session.password == "other secret" && session.token.isEmpty)
        await session.hydrate()
        precondition(session.profiles.count == 3 && session.activeProfileID == second && session.token.isEmpty)
        precondition(session.remark == "Office")
        let snapshot = session.credentials
        await session.switchTo(profileID: "nonexistent")
        precondition(session.credentials == snapshot)
        precondition(LuckyStatusStore.shared.resets > 0)
        print("PASS multiple profiles, exact identity, update, switching, logout, relaunch, lifecycle")
        let stale = session.sessionGeneration
        await session.switchTo(profileID: original)
        await session.saveToken("WRONG", ifGeneration: stale)
        await session.end(ifGeneration: stale)
        precondition(session.token == "updated", "stale completion must neither replace token nor log out new account")
        print("PASS guarded session mutations ignore stale account completions")
        let beforeReturn = session.sessionGeneration
        await session.switchTo(profileID: second)
        await session.switchTo(profileID: original)
        await session.saveToken("ABA-WRONG", ifGeneration: beforeReturn)
        precondition(session.token == "updated", "A → B → A must not revive stale A refresh")
        print("PASS returning to same profile does not revive old generation")
        let genBeforeRemark = session.sessionGeneration
        session.updateRemark("  Home NAS  ", for: original)
        precondition(session.remark == "Home NAS" && session.sessionGeneration == genBeforeRemark)
        session.updateRemark("Secondary", for: second)
        precondition(session.profiles.first(where: { $0.id == second })?.remark == "Secondary")
        let third = session.profiles.first(where: { $0.id != original && $0.id != second })!.id
        await session.removeProfile(id: third)
        precondition(session.profiles.count == 2 && session.activeProfileID == original)
        let genBeforeDeleteActive = session.sessionGeneration
        await session.removeProfile(id: original)
        precondition(session.profiles.count == 1 && session.activeProfileID == second)
        precondition(session.sessionGeneration != genBeforeDeleteActive)
        await session.removeProfile(id: second)
        precondition(session.profiles.isEmpty && session.activeProfileID == nil && !session.isAuthenticated)
        print("PASS profile remark editing and profile removal lifecycle")
    }
}
