import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct LuckyCredentials: Sendable, Equatable {
    var baseUrl = ""; var account = ""; var password = ""; var token = ""; var generation: UInt64 = 0
}
@MainActor final class LuckySession {
    static let shared = LuckySession()
    var writes = 0
    func saveToken(_ token: String, ifGeneration: UInt64? = nil) async { writes += 1 }
    func end(ifGeneration: UInt64? = nil) async { writes += 1 }
}
actor Gate {
    static let shared = Gate()
    var continuation: CheckedContinuation<String, Error>?
    func login() async throws -> String { try await withCheckedThrowingContinuation { continuation = $0 } }
    var started: Bool { continuation != nil }
    func finish() { continuation!.resume(returning: "old-refresh"); continuation = nil }
}
extension LuckyClient {
    static func login(baseUrl: String, account: String, password: String, twoFACode: String, session: URLSession, asRefresh: Bool) async throws -> String { try await Gate.shared.login() }
}
final class Intercept: URLProtocol {
    static let lock = NSLock()
    static var pending: Intercept?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() { Self.lock.lock(); Self.pending = self; Self.lock.unlock() }
    override func stopLoading() {}
    static var started: Bool { lock.lock(); defer { lock.unlock() }; return pending != nil }
    static func finish(status: Int) {
        lock.lock(); let p = pending!; pending = nil; lock.unlock()
        p.client!.urlProtocol(p, didReceive: HTTPURLResponse(url: p.request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        p.client!.urlProtocol(p, didLoad: Data("{\"ret\":0}".utf8))
        p.client!.urlProtocolDidFinishLoading(p)
    }
}
@main struct Checks {
    static func main() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [Intercept.self]
        let client = LuckyClient(session: URLSession(configuration: config))
        let old = LuckyCredentials(baseUrl: "https://a.invalid", account: "A", password: "a", token: "ta", generation: 1)
        let new = LuckyCredentials(baseUrl: "https://b.invalid", account: "B", password: "b", token: "tb", generation: 2)
        await client.apply(old)
        let refresh = Task { try await client.refreshToken() }
        while !(await Gate.shared.started) { await Task.yield() }
        let joinedRefresh = Task { try await client.refreshToken() }
        // Let the second caller join the suspended single-flight login.
        try await Task.sleep(for: .milliseconds(30))
        await client.apply(new)
        await Gate.shared.finish()
        do { _ = try await refresh.value; fatalError("stale refresh must fail") } catch is CancellationError {}
        do { _ = try await joinedRefresh.value; fatalError("joined stale refresh must fail") } catch is CancellationError {}
        let writes = await MainActor.run { LuckySession.shared.writes }
        precondition(writes == 0)
        let snapshot = await client.snapshot
        precondition(snapshot == new)
        for status in [200, 401] {
            await client.apply(old)
            let fetch = Task { try await client.fetch("/api/read") }
            while !Intercept.started { await Task.yield() }
            await client.apply(new)
            Intercept.finish(status: status)
            do { _ = try await fetch.value; fatalError("stale response must fail") } catch is CancellationError {}
        }
        print("PASS real LuckyClient rejects stale refresh, success and 401 responses without mutating new session")
    }
}
