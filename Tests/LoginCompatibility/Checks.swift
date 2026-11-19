import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#if canImport(Security)
import Security
#endif

final class LoginProtocol: URLProtocol {
    static var requests: [URLRequest] = []
    static var handler: (URLRequest) throws -> (Int, String, [String: String]) = { _ in (500, "", [:]) }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            var captured = request
            // Darwin URLSession exposes uploaded bodies as streams to URLProtocol.
            if captured.httpBody == nil, let stream = captured.httpBodyStream {
                stream.open()
                defer { stream.close() }
                var data = Data()
                var buffer = [UInt8](repeating: 0, count: 4096)
                while stream.hasBytesAvailable {
                    let count = stream.read(&buffer, maxLength: buffer.count)
                    if count <= 0 { break }
                    data.append(contentsOf: buffer.prefix(count))
                }
                captured.httpBody = data
            }
            Self.requests.append(captured)
            let (status, body, headers) = try Self.handler(captured)
            client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: headers)!, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(body.utf8))
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw LuckyError("TEST FAILURE: " + message) }
}

@main struct Checks {
    static func main() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [LoginProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        LoginProtocol.handler = { request in
            if request.url!.path.hasSuffix("/api/login/challenge") { return (503, "{\"ret\":1,\"msg\":\"unavailable\"}", [:]) }
            return (200, "{\"ret\":0,\"token\":\"unsafe\"}", [:])
        }
        do {
            _ = try await LuckyClient.login(baseUrl: "https://example.test/proxy", account: " user ", password: " secret ", twoFACode: "123456", session: session, asRefresh: false)
            throw LuckyError("TEST FAILURE: challenge failure silently downgraded to plaintext")
        } catch {
            try require(!LoginProtocol.requests.contains { $0.httpMethod == "POST" }, "challenge failure must never post credentials")
        }
        print("PASS challenge failures fail closed")

        for status in [200, 400, 401, 403, 429, 500] {
            LoginProtocol.requests = []
            LoginProtocol.handler = { _ in (status, "{\"ret\":-1,\"msg\":\"denied\"}", [:]) }
            do {
                _ = try await LuckyClient.login(baseUrl: "https://example.test/proxy", account: "user", password: "secret", twoFACode: "", session: session, asRefresh: true)
                throw LuckyError("TEST FAILURE: refresh accepted challenge denial")
            } catch {
                try require(error is LuckyAuthError, "refresh failures must be auth errors")
                try require(LoginProtocol.requests.count == 1, "challenge denial must not retry or downgrade")
            }
        }
        print("PASS challenge HTTP and auth errors fail closed on refresh")

        LoginProtocol.requests = []
        LoginProtocol.handler = { request in
            switch request.url!.path {
            case "/proxy/api/login/challenge": return (404, "not found", [:])
            case "/proxy/version": return (200, "{\"ret\":0,\"version\":\"2.27.2\"}", [:])
            default: return (200, "{\"ret\":0}", ["Lucky-Admin-Token": "legacy-token"])
            }
        }
        let token = try await LuckyClient.login(baseUrl: "https://example.test/proxy/", account: " user ", password: " secret ", twoFACode: " 123456 ", session: session, asRefresh: false)
        try require(token == "legacy-token", "header token must be accepted")
        try require(LoginProtocol.requests.map { $0.url!.path } == ["/proxy/api/login/challenge", "/proxy/version", "/proxy/api/login"], "base path must be preserved")
        let posted = LoginProtocol.requests.last!
        let body = JSONParser.tryParse(posted.httpBody!)!
        try require(body["Account"]?.stringValue == "user", "legacy account trim")
        try require(body["Password"]?.stringValue == " secret ", "password whitespace preserved")
        try require(body["TwoFA"]?.stringValue == "", "V2 TwoFA field unchanged")
        try require(body["TwoFACode"]?.stringValue == "123456", "V2 TwoFACode unchanged")
        print("PASS confirmed V2 fallback, base path, token header and exact legacy fields")

        for version in ["3.8.1", "garbage", "20.0.0"] {
            LoginProtocol.requests = []
            LoginProtocol.handler = { request in
                request.url!.path.hasSuffix("/version") ? (200, "{\"ret\":0,\"version\":\"\(version)\"}", [:]) : (404, "not found", [:])
            }
            do { _ = try await LuckyClient.login(baseUrl: "https://example.test", account: "user", password: "secret", twoFACode: "", session: session, asRefresh: false) } catch {}
            try require(!LoginProtocol.requests.contains { $0.httpMethod == "POST" }, "unconfirmed V2 must not receive plaintext")
        }
        print("PASS missing challenge does not permit plaintext on unknown or V3 servers")

        let challenge: JSONValue = .object([("challengeId", .string("id")), ("nonce", .string("nonce")), ("publicKey", .string("test-key"))])
        var blocks: [Data] = []
        let encrypted = try LuckyLoginEncryption.body(challenge: challenge, account: "你好😀", password: String(repeating: "密码", count: 80), twoFA: "123456") { key, bytes in
            try require(key == "test-key", "challenge public key used")
            blocks.append(bytes)
            return bytes.base64EncodedString()
        }
        try require(blocks.count > 1 && blocks.allSatisfy { $0.count <= 120 && String(data: $0, encoding: .utf8) != nil }, "chunk on UTF8 scalar boundaries at 120 bytes")
        let plaintext = String(decoding: blocks.reduce(Data(), +), as: UTF8.self)
        try require(plaintext.contains("\\ud83d\\ude00"), "astral unicode uses JS surrogate escaping")
        let decoded = JSONParser.tryParse(Data(plaintext.utf8))!
        try require(decoded["twoFA"]?.stringValue == "123456" && decoded["TwoFACode"] == nil, "V3 uses lower-case twoFA, not V2 fields")
        let envelope = JSONParser.tryParse(encrypted)!
        try require(envelope["cipherText"]?.stringValue?.split(separator: ".").count == blocks.count, "period separated encrypted blocks")
        try require(envelope["account"] == nil && envelope["password"] == nil, "outer envelope has no credentials")
        print("PASS V3 credential schema, UTF8 chunking, unicode escaping and ciphertext envelope")
        do {
            _ = try LuckyLoginEncryption.body(challenge: .object([]), account: "u", password: "p", twoFA: "") { _, _ in throw LuckyError("must not run") }
            throw LuckyError("TEST FAILURE: malformed challenge accepted")
        } catch { try require(error.luckyMessage() == "加密登录挑战无效", "reject malformed challenge before encrypting") }
        do {
            _ = try LuckyLoginEncryption.rsaKeyData(Data([0x30, 0x80]), isSPKI: true)
            throw LuckyError("TEST FAILURE: invalid key accepted")
        } catch { try require(error.luckyMessage() == "登录公钥无效", "reject malformed DER") }
        print("PASS malformed challenge and key rejection")
        LoginProtocol.requests = []
        LoginProtocol.handler = { _ in (200, "{\"ret\":0,\"challengeId\":\"id\",\"nonce\":\"nonce\",\"publicKey\":\"invalid key\"}", [:]) }
        do { _ = try await LuckyClient.login(baseUrl: "https://example.test", account: "user", password: "secret", twoFACode: "", session: session, asRefresh: false) } catch {}
        try require(LoginProtocol.requests.count == 1, "encryption failure must not downgrade or post")
        print("PASS encryption failure never downgrades")

        // On Apple platforms this exercises the production Security implementation,
        // including SPKI conversion, PKCS1 padding, and multi-block decryption.
        #if canImport(Security)
        let attributes: [CFString: Any] = [kSecAttrKeyType: kSecAttrKeyTypeRSA, kSecAttrKeySizeInBits: 2048]
        var keyError: Unmanaged<CFError>?
        let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &keyError)!
        let publicKey = SecKeyCopyPublicKey(privateKey)!
        let pkcs1 = SecKeyCopyExternalRepresentation(publicKey, &keyError)! as Data
        func der(_ tag: UInt8, _ value: Data) -> Data {
            let length = value.count
            return Data([tag] + (length < 128 ? [UInt8(length)] : [0x82, UInt8(length >> 8), UInt8(length & 255)])) + value
        }
        let algorithm = Data([0x30,0x0d,0x06,0x09,0x2a,0x86,0x48,0x86,0xf7,0x0d,0x01,0x01,0x01,0x05,0x00])
        let spki = der(0x30, algorithm + der(0x03, Data([0]) + pkcs1))
        let pem = "-----BEGIN PUBLIC KEY-----\n" + spki.base64EncodedString() + "\n-----END PUBLIC KEY-----"
        let rsaChallenge: JSONValue = .object([("challengeId", .string("id")), ("nonce", .string("nonce")), ("publicKey", .string(pem))])
        let unwrapped = try LuckyLoginEncryption.rsaKeyData(spki, isSPKI: true)
        try require(unwrapped == pkcs1, "SPKI unwrap")
        let actual = try LuckyLoginEncryption.body(challenge: rsaChallenge, account: "你好😀", password: String(repeating: "密码", count: 80), twoFA: "123456")
        let actualEnvelope = JSONParser.tryParse(actual)!
        var recovered = Data()
        for block in actualEnvelope["cipherText"]!.stringValue!.split(separator: ".") {
            let ciphertext = Data(base64Encoded: String(block))!
            let decrypted = SecKeyCreateDecryptedData(privateKey, .rsaEncryptionPKCS1, ciphertext as CFData, &keyError)!
            recovered.append(decrypted as Data)
        }
        try require(recovered == Data(plaintext.utf8), "production RSA encrypt/decrypt matches frontend credential bytes")
        LoginProtocol.requests = []
        LoginProtocol.handler = { request in
            if request.url!.path.hasSuffix("/challenge") { return (200, JSONSerializer.stringify(.object([("ret", .number(0)), ("challengeId", .string("id")), ("nonce", .string("nonce")), ("publicKey", .string(pem))])), [:]) }
            return (200, "{\"ret\":0,\"token\":\"encrypted-token\"}", [:])
        }
        let v3Token = try await LuckyClient.login(baseUrl: "https://example.test/proxy", account: "user", password: "secret", twoFACode: "123456", session: session, asRefresh: false)
        try require(v3Token == "encrypted-token", "encrypted V3 login succeeds")
        try require(LoginProtocol.requests.count == 2, "V3 does not probe version")
        let sessionHeader = LoginProtocol.requests[0].value(forHTTPHeaderField: "Lucky-Login-Session")!
        try require(sessionHeader.count == 64 && sessionHeader.allSatisfy { "0123456789abcdef".contains($0) }, "32 random bytes hex encoded")
        try require(LoginProtocol.requests[1].value(forHTTPHeaderField: "Lucky-Login-Session") == sessionHeader, "challenge and login share exact session header")
        print("PASS native RSA PKCS1 round-trip and encrypted V3 login")
        #else
        print("SKIP native Security RSA round-trip (requires Apple platform)")
        #endif
    }
}
