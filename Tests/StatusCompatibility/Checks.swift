import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// Platform shells only: production stream, protobuf, JSON and request code are compiled unchanged.
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
        var calls = 0
        let request = try await LuckyStatusStore.socketRequest(baseUrl: "https://example.test/lucky", token: "secret", millis: 123) { request in
            calls += 1
            precondition(request.path == "/api/temp-access-tickets")
            precondition(request.method == "POST")
            precondition(request.baseUrl == "https://example.test/lucky" && request.token == "secret")
            let body = try JSONParser.parse(request.body!.data)
            precondition(body["method"]?.stringValue == "GET" && body["path"]?.stringValue == "/api/status/ws")
            precondition(body["query"]?.isRecord == true)
            return .object([("ticket", .string("ticket+/?&=")), ("ticketParam", .string("custom-ticket"))])
        }
        precondition(calls == 1)
        let parts = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
        precondition(parts.scheme == "wss" && parts.path == "/lucky/api/status/ws")
        precondition(parts.queryItems?.first(where: { $0.name == "custom-ticket" })?.value == "ticket+/?&=")
        precondition(parts.queryItems?.contains(where: { $0.name == "Lucky-Admin-Token" }) == false)
        precondition(request.value(forHTTPHeaderField: "Lucky-Admin-Token") == nil)
        let fallback = try await LuckyStatusStore.socketRequest(baseUrl: "http://example.test", token: "secret", millis: 123) { _ in
            throw LuckyError("404 page not found", statusCode: 404)
        }
        precondition(fallback.url!.scheme == "ws")
        precondition(fallback.value(forHTTPHeaderField: "Lucky-Admin-Token") == "secret")
        precondition(fallback.url!.query!.contains("Lucky-Admin-Token=secret"))
        for status in [401, 403, 500] {
            do {
                _ = try await LuckyStatusStore.socketRequest(baseUrl: "https://example.test", token: "secret") { _ in
                    throw LuckyError("denied", statusCode: status)
                }
                fatalError("Must not downgrade on HTTP \(status)")
            } catch let error as LuckyError { precondition(error.statusCode == status) }
        }
        do {
            _ = try await LuckyStatusStore.socketRequest(baseUrl: "https://example.test", token: "secret") { _ in .object([("ticket", .string(" "))]) }
            fatalError("Empty ticket must fail")
        } catch is LuckyError {}
        let status = try LuckyLiveStatus.decode(protobuf: Data([8, 1, 24, 128, 8, 146, 3, 2, 8, 7, 146, 1, 4, 115, 119, 97, 112]))
        precondition(status.totalMem == 1024 && status.history.first?.time == 7)
        print("PASS: V3 ticket request, opaque encoding, base path, V2 fallback, no auth downgrade, empty ticket rejection, compatible protobuf unknown fields")
    }
}
