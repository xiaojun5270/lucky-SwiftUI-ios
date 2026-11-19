import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
struct Gzip { static func inflate(_ data: Data) throws -> Data { data } }
@MainActor final class LuckySession {
    static let shared = LuckySession()
    var credentials = (baseUrl: "", token: "")
    var token: String { credentials.token }
    func end() async {}
}
actor LuckyClient {
    static let shared = LuckyClient()
    func refreshToken() async throws -> String { "" }
    func fetch(_ request: LuckyRequest) async throws -> JSONValue { fatalError("network not used") }
}
@main struct Checks {
    @MainActor static func main() async throws {
        let store = LuckyStatusStore.shared
        let status = try LuckyLiveStatus.decode(protobuf: Data([8,1]))
        store.apply(.success(status), generation: store.generation)
        precondition(store.data != nil && store.connected)
        let oldGeneration = store.generation
        store.resetForSessionChange()
        precondition(store.data == nil && !store.connected && store.error.isEmpty)
        store.apply(.success(status), generation: oldGeneration)
        precondition(store.data == nil, "late decode must not repopulate old-account status")
        print("PASS real status store clears previous account data and rejects late decode")
    }
}
