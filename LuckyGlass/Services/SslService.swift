import Foundation

/// Port of `src/services/ssl.ts`.
///
/// The SSL module is inconsistent about where the key goes: some endpoints take it in the
/// path, some as a query parameter, and `enable` combines both. The split is reproduced
/// exactly, because sending it the other way silently affects the wrong certificate.
enum SslService {
    private static var client: LuckyClient { .shared }

    /// `certificateScore(item)` — the fields that make a record look like a certificate.
    private static let certificateKeys = [
        "Key", "key", "Remark", "remark", "AddFrom", "CertsInfo", "ExtParams", "SyncInfo",
    ]

    /// `getSslCertificates()`. Unlike the DDNS search this one never treats an object's values
    /// as the list, so a certificate map would not be found — that matches the original.
    static func certificates() async throws -> LuckyItemList {
        let raw = try await client.fetch("/api/ssl")
        return LuckyItemList(items: JSONUnwrap.bestScoredRecords(raw, keys: certificateKeys), raw: raw)
    }

    static func certificate(_ key: String) async throws -> JSONValue {
        try await client.fetch("/api/ssl/\(LuckyQuery.escape(key))")
    }

    @discardableResult
    static func create(_ value: JSONValue) async throws -> JSONValue {
        try await run {
            try await client.fetch("/api/ssl", method: "POST", body: .value(value))
        }
    }

    /// The update endpoint carries the key inside the body, so there is no path or query key.
    @discardableResult
    static func update(_ value: JSONValue) async throws -> JSONValue {
        try await run {
            try await client.fetch("/api/ssl", method: "PUT", body: .value(value))
        }
    }

    @discardableResult
    static func delete(_ key: String) async throws -> JSONValue {
        try await run {
            try await client.fetch("/api/ssl" + LuckyQuery.compact([("key", .string(key))]), method: "DELETE")
        }
    }

    /// Key in the path *and* the flag in the query — `PUT /api/ssl/<key>?enable=<bool>`.
    @discardableResult
    static func setCertificateEnabled(_ key: String, _ enable: Bool) async throws -> JSONValue {
        try await run {
            try await client.fetch(
                "/api/ssl/\(LuckyQuery.escape(key))" + LuckyQuery.compact([("enable", .bool(enable))]),
                method: "PUT"
            )
        }
    }

    /// `flushSslCertificate(key)` — forces a renewal check.
    @discardableResult
    static func flushCertificate(_ key: String) async throws -> JSONValue {
        try await run {
            try await client.fetch("/api/ssl/flush" + LuckyQuery.compact([("key", .string(key))]), method: "PUT")
        }
    }

    /// `syncSslCertificate(key)` — pushes the certificate to the sync clients.
    @discardableResult
    static func syncCertificate(_ key: String) async throws -> JSONValue {
        try await run {
            try await client.fetch("/api/ssl/manualsync/\(LuckyQuery.escape(key))")
        }
    }

    @discardableResult
    static func reorderCertificates(_ keys: JSONValue) async throws -> JSONValue {
        try await client.fetch("/api/ssl/sslorderadjustment", method: "PUT", body: .value(keys))
    }

    // MARK: - Sync clients

    static func syncClients() async throws -> JSONValue {
        try await client.fetch("/api/ssl/syncclients")
    }

    /// `getSslSyncClientOptions()` — the same scoring search as the certificate list, with the
    /// client identity fields. Used to populate the distribution picker.
    static func syncClientOptions() async throws -> [LuckyListItem] {
        JSONUnwrap.bestScoredRecords(
            try await syncClients(),
            keys: ["Key", "ClientKey", "Name", "ClientName", "DeviceName"]
        )
    }

    // MARK: - Module settings and logs

    static func setting() async throws -> JSONValue {
        try await client.fetch("/api/ssl/setting")
    }

    @discardableResult
    static func updateSetting(_ value: JSONValue) async throws -> JSONValue {
        try await run {
            try await client.fetch("/api/ssl/setting", method: "PUT", body: .value(value))
        }
    }

    /// `cancelSslAcme(key)` — aborts an in-flight ACME order.
    @discardableResult
    static func cancelAcme(_ key: String) async throws -> JSONValue {
        try await run {
            try await client.fetch("/api/ssl/\(LuckyQuery.escape(key))/acmecancel", method: "DELETE")
        }
    }

    /// An empty `key` asks for the module-wide log instead of one certificate's, and the
    /// compact builder drops it, so the same call serves both screens.
    static func logs(key: String = "", pageSize: Int = 100, page: Int = 1) async throws -> JSONValue {
        try await client.fetch(
            "/api/ssl/logs" + LuckyQuery.compact([
                ("key", .string(key)), ("pageSize", .int(pageSize)), ("page", .int(page)),
            ])
        )
    }

    static func lastLogs(key: String = "") async throws -> JSONValue {
        try await client.fetch("/api/ssl/lastlogs" + LuckyQuery.compact([("key", .string(key))]))
    }

    // MARK: - Error translation

    private static let errorSentinels: [(token: String, message: String)] = [
        ("PermissionDeniedCannotUseSyncFunction", "当前账号没有证书分发同步权限"),
        ("NotMeetCertificateRenewalAdvanceDays", "当前未满足证书续签的提前天数条件"),
        ("RequestInProgressDoNotResubmit", "正在申请证书，请勿重复提交"),
        ("UnsupportedRefreshType", "当前证书类型不支持手动刷新"),
        ("InconsistentDomainInformationBetweenCertificates", "前后证书域名信息不一致"),
        ("DomainRegistrarCredentialsMissing", "域名托管商认证凭证缺失"),
        ("CertificateItemDeletedIgnoreSave", "该证书项已删除，忽略保存"),
        ("ACMECertificateRequestFailed", "ACME 证书申请失败"),
        ("ACMECertificateDataInvalid", "ACME 证书数据有误"),
        ("CertificateFileNotFoundAtPath", "该路径下证书文件不存在"),
        ("KeyFileNotFoundAtPath", "该路径下私钥文件不存在"),
        ("ErrorReadingCertificateFileData", "读取证书文件数据出错"),
        ("ErrorReadingKeyFileData", "读取私钥文件数据出错"),
        ("ErrorSavingConfiguration", "保存证书配置出错"),
        ("RemarkNameMustBeUniqueAndNotDuplicate", "备注名必须唯一，不能重复"),
        ("RemarkNameCannotBeEmpty", "备注名不能为空"),
        ("DomainListCannotBeEmpty", "域名/IP 列表不能为空"),
        ("DomainConflict", "证书域名冲突"),
        ("TargetAddressMustStartWithHttps", "同步目标地址必须以 https 开头"),
        ("TargetFormatError", "同步目标地址格式有误"),
        ("TokenCannotBeEmpty", "同步令牌不能为空"),
        ("FileCannotBeLargerThan1MB", "证书文件不能大于 1MB"),
        ("applyingACMEcertificatenoedit", "正在申请 ACME 证书，无法编辑"),
        ("cancelingApplicationnoedit", "正在取消申请证书，无法编辑"),
        ("CertificateError", "证书内容有误"),
    ]

    private static func run(_ work: () async throws -> JSONValue) async throws -> JSONValue {
        do {
            return try await work()
        } catch {
            throw translateError(error)
        }
    }

    static func translateError(_ error: Error) -> Error {
        if error is LuckyAuthError || error.isCancellation { return error }
        guard let luckyError = error as? LuckyError else { return error }
        let localized = localizedServerMessage(luckyError.message)
        if localized == luckyError.message { return error }
        return LuckyError(localized, statusCode: luckyError.statusCode)
    }

    /// Translates Lucky SSL backend sentinel codes and Go `time.Duration` values into readable Chinese.
    static func localizedServerMessage(_ raw: String) -> String {
        let trimmed = raw.jsTrimmed
        guard !trimmed.isEmpty else { return raw }

        if let formatted = formatRenewalAdvanceTime(trimmed) {
            return formatted
        }
        for entry in errorSentinels {
            if trimmed.range(of: entry.token, options: .caseInsensitive) != nil {
                return entry.message
            }
        }
        return raw
    }

    /// Matches `NotMeetCertificateRenewalAdvanceTime <remaining> > <threshold>` (space or newline separated).
    private static func formatRenewalAdvanceTime(_ text: String) -> String? {
        let prefix = "NotMeetCertificateRenewalAdvanceTime"
        guard let range = text.range(of: prefix, options: .caseInsensitive) else { return nil }
        let tail = text[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = tail.components(separatedBy: ">").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else {
            return "当前证书还未到续期时间，暂不需要手动续期"
        }
        let remaining = formatGoDuration(parts[0]) ?? parts[0]
        let threshold = formatGoDuration(parts[1]) ?? parts[1]
        return "当前证书还未到续期时间：剩余有效期 \(remaining)，需要小于续期提前时间 \(threshold) 后才能手动续期"
    }

    /// Parses Go `time.Duration` strings such as `835h37m49.961571076s` or `720h0m0s` into `34天19小时37分钟` / `30天`.
    static func formatGoDuration(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        var index = trimmed.startIndex
        var hours: Double = 0
        var minutes: Double = 0
        var seconds: Double = 0
        var matchedAny = false

        while index < trimmed.endIndex {
            let numStart = index
            var sawDot = false
            while index < trimmed.endIndex {
                let ch = trimmed[index]
                if ch.isNumber {
                    index = trimmed.index(after: index)
                } else if ch == ".", !sawDot {
                    sawDot = true
                    index = trimmed.index(after: index)
                } else {
                    break
                }
            }
            guard index > numStart, index < trimmed.endIndex,
                  let value = Double(trimmed[numStart..<index]) else {
                return nil
            }
            let unit = trimmed[index]
            index = trimmed.index(after: index)
            switch unit {
            case "h":
                hours += value
                matchedAny = true
            case "m":
                minutes += value
                matchedAny = true
            case "s":
                seconds += value
                matchedAny = true
            default:
                return nil
            }
        }
        guard matchedAny else { return nil }
        let totalSeconds = hours * 3600 + minutes * 60 + seconds
        guard totalSeconds.isFinite else { return nil }
        let totalMinutes = max(0, Int(floor(totalSeconds / 60)))
        let d = totalMinutes / 1440
        let h = (totalMinutes % 1440) / 60
        let m = totalMinutes % 60
        var chunks: [String] = []
        if d > 0 { chunks.append("\(d)天") }
        if h > 0 { chunks.append("\(h)小时") }
        if m > 0 || chunks.isEmpty { chunks.append("\(m)分钟") }
        return chunks.joined()
    }
}
