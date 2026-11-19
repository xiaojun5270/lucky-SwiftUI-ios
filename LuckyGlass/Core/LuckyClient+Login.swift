import Foundation
#if canImport(Security)
import Security
#endif

extension LuckyClient {
    /// `POST /api/login`, shared by the login screen (`loginToLucky`) and the silent
    /// refresh (`refreshLuckyToken`). The request is identical in both paths — only the
    /// error copy and the error type differ — so they must not drift apart.
    ///
    /// `asRefresh` selects the refresh behaviour: every failure becomes a
    /// `LuckyAuthError`, which is the signal the caller uses to end the session.
    static func login(
        baseUrl: String,
        account: String,
        password: String,
        twoFACode: String,
        session: URLSession,
        asRefresh: Bool
    ) async throws -> String {
        // The refresh path has no UI to validate against, so it checks the stored
        // credentials itself before spending a request.
        if asRefresh, baseUrl.isEmpty || account.isEmpty || password.isEmpty {
            throw LuckyAuthError()
        }

        do {
            return try await withDeadline(LuckyClientConstants.defaultTimeout) {
                try await performLogin(
                    baseUrl: baseUrl,
                    account: account,
                    password: password,
                    twoFACode: twoFACode,
                    session: session,
                    asRefresh: asRefresh
                )
            }
        } catch let error as LuckyAuthError {
            throw error
        } catch {
            if asRefresh {
                if error is DeadlineExceeded { throw LuckyAuthError("重新登录超时，请检查服务器连接") }
                if error.isCancellation { throw LuckyAuthError("重新登录请求已取消") }
                throw LuckyAuthError("重新登录失败，请检查服务器连接")
            }
            if error is DeadlineExceeded { throw LuckyError("登录超时，请检查服务器地址") }
            // A transport failure surfaces verbatim, as it does in the original.
            throw error
        }
    }

    private static func performLogin(
        baseUrl: String,
        account: String,
        password: String,
        twoFACode: String,
        session: URLSession,
        asRefresh: Bool
    ) async throws -> String {
        // A fresh, random 32-byte session binds the challenge to this login attempt.
        // This is a header, not an HTTP cookie (Lucky V3 frontend's Fo()).
        var random = SystemRandomNumberGenerator()
        let loginSession = (0..<32).map { _ in String(format: "%02x", UInt8.random(in: .min ... .max, using: &random)) }.joined()
        var challengeRequest = URLRequest(url: try url(base: baseUrl, path: withNonce("/api/login/challenge")))
        challengeRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        challengeRequest.setValue(loginSession, forHTTPHeaderField: "Lucky-Login-Session")
        let (challengeData, challengeResponse) = try await session.data(for: challengeRequest)
        let challengeStatus = (challengeResponse as? HTTPURLResponse)?.statusCode ?? 0
        let challenge = JSONParser.tryParse(challengeData)
        // Only an absent endpoint *and* a confirmed V2 server permit plaintext.
        // A proxy 404, expired challenge, rate limit or authentication error never does.
        var useLegacy = false
        if challengeStatus == 404 || challengeStatus == 405 {
            let versionRequest = URLRequest(url: try url(base: baseUrl, path: withNonce("/version")))
            let (versionData, versionResponse) = try await session.data(for: versionRequest)
            if let status = (versionResponse as? HTTPURLResponse)?.statusCode,
               (200..<300).contains(status),
               let version = JSONParser.tryParse(versionData), version.retValue == 0,
               let text = version["version"]?.stringValue,
               text.split(separator: ".").first == "2" {
                useLegacy = true
            }
        }
        if !useLegacy {
            guard (200..<300).contains(challengeStatus), let challenge, challenge.retValue == 0 else {
                throw failure(challenge?.msg ?? "无法获取加密登录挑战（HTTP \(challengeStatus)）", asRefresh: asRefresh)
            }
        }

        var request = URLRequest(url: try url(base: baseUrl, path: withNonce("/api/login")))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if useLegacy {
            request.httpBody = JSONSerializer.data(.object([
                ("Account", .string(account.jsTrimmed)),
                ("Password", .string(password)),
                ("TwoFA", .string("")),
                ("TwoFACode", .string(twoFACode.jsTrimmed)),
            ]))
        } else {
            guard let challenge else { throw failure("加密登录挑战无效", asRefresh: asRefresh) }
            request.setValue(loginSession, forHTTPHeaderField: "Lucky-Login-Session")
            request.httpBody = try LuckyLoginEncryption.body(challenge: challenge, account: account.jsTrimmed,
                                                            password: password, twoFA: twoFACode.jsTrimmed)
        }

        let (data, rawResponse) = try await session.data(for: request)
        let response = rawResponse as? HTTPURLResponse
        let status = response?.statusCode ?? 0
        let ok = (200..<300).contains(status)

        // Only an unparseable body takes this branch: a well-formed body that happens not
        // to be an object falls through and fails the `ret` check below, as it does in JS.
        guard let payload = JSONParser.tryParse(data) else {
            throw failure(
                ok ? (asRefresh ? "重新登录失败：服务器返回了无法识别的数据" : "登录失败：服务器返回了无法识别的数据")
                   : (asRefresh ? "重新登录失败（HTTP \(status)）" : "登录失败（HTTP \(status)）"),
                asRefresh: asRefresh
            )
        }

        if !ok || payload.retValue != 0 {
            if asRefresh { throw LuckyAuthError(payload.msg) }
            throw LuckyError(payload.msg ?? "登录失败")
        }

        guard let token = token(in: payload, header: response?.value(forHTTPHeaderField: "Lucky-Admin-Token")) else {
            throw failure(
                asRefresh ? "重新登录成功但未返回 Token" : "登录成功但响应中没有 Token，请在联调环境确认登录响应字段",
                asRefresh: asRefresh
            )
        }
        return token
    }

    /// Lucky has shipped the admin token under several names across versions, and some
    /// builds only return it as a response header. The candidate order is the original's.
    private static func token(in payload: JSONValue, header: String?) -> String? {
        // `record(payload.data)` — a non-object `data` yields `{}`, whose fields are all
        // absent, so the nested lookups below simply miss.
        let nested = payload["data"] ?? .null
        var candidates: [JSONValue?] = [
            payload["token"], payload["Token"], payload["AdminToken"], payload["LuckyAdminToken"],
        ]
        if let data = payload["data"], data.isString { candidates.append(data) }
        candidates.append(contentsOf: [
            nested["token"], nested["Token"], nested["AdminToken"], nested["LuckyAdminToken"],
        ])
        for candidate in candidates {
            if let text = candidate?.stringValue, !text.jsTrimmed.isEmpty { return text }
        }
        if let header, !header.jsTrimmed.isEmpty { return header }
        return nil
    }

    private static func failure(_ message: String, asRefresh: Bool) -> Error {
        asRefresh ? LuckyAuthError(message) : LuckyError(message)
    }

    /// `loginToLucky(input)` — the interactive path. An instance method so the login screen
    /// reuses the actor's `URLSession` (ephemeral, no cookies, no cache) instead of the
    /// shared one, exactly as every other request does.
    func signIn(_ input: LuckyLoginInput) async throws -> String {
        try await Self.login(
            baseUrl: input.baseUrl.jsTrimmed.withoutTrailingSlashes,
            account: input.account.jsTrimmed,
            password: input.password,
            twoFACode: input.twoFACode.jsTrimmed,
            session: session,
            asRefresh: false
        )
    }
}

/// Lucky V3 uses JSEncrypt's RSAES-PKCS1-v1_5, 120 UTF-8 byte chunks,
/// and period-separated base64 blocks (not OAEP and not one giant RSA operation).
enum LuckyLoginEncryption {
    static func body(challenge: JSONValue, account: String, password: String, twoFA: String,
                     encrypt: (String, Data) throws -> String = rsaEncrypt) throws -> Data {
        guard let id = challenge["challengeId"]?.stringValue, !id.isEmpty,
              let nonce = challenge["nonce"]?.stringValue, !nonce.isEmpty,
              let key = challenge["publicKey"]?.stringValue, !key.isEmpty else {
            throw LuckyError("加密登录挑战无效")
        }
        let json = JSONSerializer.stringify(.object([
            ("account", .string(account)), ("password", .string(password)),
            ("twoFA", .string(twoFA)), ("challengeId", .string(id)), ("nonce", .string(nonce)),
        ]))
        // The web client escapes every UTF-16 surrogate before JSEncrypt; this also
        // avoids its historical non-BMP UTF-8 encoder bug.
        var escaped = ""
        for scalar in json.unicodeScalars {
            if scalar.value > 0xffff {
                for unit in String(scalar).utf16 { escaped += String(format: "\\u%04x", unit) }
            } else { escaped.unicodeScalars.append(scalar) }
        }
        var chunks: [Data] = []
        var chunk = Data()
        for scalar in escaped.unicodeScalars {
            let bytes = Data(String(scalar).utf8)
            if chunk.count + bytes.count > 120 { chunks.append(chunk); chunk = Data() }
            chunk.append(bytes)
        }
        if !chunk.isEmpty { chunks.append(chunk) }
        let ciphertext = try chunks.map { bytes -> String in
            let result = try encrypt(key, bytes)
            guard !result.isEmpty else { throw LuckyError("加密登录失败") }
            return result
        }.joined(separator: ".")
        return JSONSerializer.data(.object([("challengeId", .string(id)), ("cipherText", .string(ciphertext))]))
    }

    static func rsaEncrypt(_ pem: String, _ plaintext: Data) throws -> String {
        #if canImport(Security)
        let base64 = pem.components(separatedBy: .newlines).filter { !$0.hasPrefix("-----") }.joined()
        guard let der = Data(base64Encoded: base64) else { throw LuckyError("登录公钥无效") }
        let keyData = try rsaKeyData(der, isSPKI: pem.contains("BEGIN PUBLIC KEY"))
        let attributes: [CFString: Any] = [kSecAttrKeyType: kSecAttrKeyTypeRSA, kSecAttrKeyClass: kSecAttrKeyClassPublic]
        var error: Unmanaged<CFError>?
        guard let key = SecKeyCreateWithData(keyData as CFData, attributes as CFDictionary, &error),
              SecKeyIsAlgorithmSupported(key, .encrypt, .rsaEncryptionPKCS1),
              let encrypted = SecKeyCreateEncryptedData(key, .rsaEncryptionPKCS1, plaintext as CFData, &error) else {
            throw LuckyError("加密登录失败，请检查服务器公钥")
        }
        return (encrypted as Data).base64EncodedString()
        #else
        throw LuckyError("当前平台不支持 RSA 加密登录")
        #endif
    }

    /// Security imports PKCS#1 RSA keys; Lucky returns SubjectPublicKeyInfo.
    static func rsaKeyData(_ der: Data, isSPKI: Bool) throws -> Data {
        if !isSPKI { return der }
        let bytes = Array(der)
        var offset = 0
        func read(_ tag: UInt8) throws -> [UInt8] {
            guard offset + 2 <= bytes.count, bytes[offset] == tag else { throw LuckyError("登录公钥无效") }
            offset += 1
            var length = Int(bytes[offset]); offset += 1
            if length & 0x80 != 0 {
                let count = length & 0x7f
                guard count > 0, count <= 4, offset + count <= bytes.count else { throw LuckyError("登录公钥无效") }
                length = 0
                for _ in 0..<count { length = length * 256 + Int(bytes[offset]); offset += 1 }
            }
            guard length <= bytes.count - offset else { throw LuckyError("登录公钥无效") }
            let value = Array(bytes[offset..<offset + length]); offset += length
            return value
        }
        let outer = try read(0x30)
        guard offset == bytes.count else { throw LuckyError("登录公钥无效") }
        // Re-read the outer contents so length parsing has one implementation.
        let prefixLength = bytes.count - outer.count
        offset = prefixLength
        let algorithm = try read(0x30)
        guard algorithm == [0x06,0x09,0x2a,0x86,0x48,0x86,0xf7,0x0d,0x01,0x01,0x01,0x05,0x00] else {
            throw LuckyError("登录公钥不是 RSA 公钥")
        }
        let bits = try read(0x03)
        guard offset == bytes.count, bits.first == 0, bits.count > 1 else { throw LuckyError("登录公钥无效") }
        return Data(bits.dropFirst())
    }
}
