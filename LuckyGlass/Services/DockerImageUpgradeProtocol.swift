import Foundation

struct DockerImageUpgradeProgress: Sendable, Equatable {
    var percent: Double
    var message: String
}

struct DockerImageUpgradeCheck: Sendable {
    var hasUpdate: Bool
    var imagePulled: Bool

    init(_ payload: JSONValue) throws {
        let data = DockerImageUpgradeProtocol.unwrap(payload, keys: ["data", "result"])
        let message = data["error"]?.stringValue?.jsTrimmed ?? ""
        if data["check_method"]?.stringValue == "error" || !message.isEmpty {
            throw LuckyError(message.isEmpty ? "镜像版本检查失败" : message)
        }
        guard let hasUpdate = data["has_update"]?.boolValue else {
            throw LuckyError("服务端未返回有效的镜像更新检查结果")
        }
        self.hasUpdate = hasUpdate
        imagePulled = data["image_pulled"]?.boolValue ?? false
    }
}

struct DockerContainerUpgradeTarget: Sendable {
    var id: String
    var name: String
    var imageReference: String

    init(key: String, name: String, inspect: JSONValue) throws {
        let data = DockerImageUpgradeProtocol.unwrap(inspect, keys: ["container", "data", "result"])
        let config = data["Config"] ?? data["config"]
        let reference = (config?["Image"]?.stringValue ?? config?["image"]?.stringValue
                         ?? data["image"]?.stringValue ?? data["Image"]?.stringValue ?? "").jsTrimmed
        guard !reference.isEmpty else { throw LuckyError("容器没有关联镜像，无法检查更新") }
        guard !reference.hasPrefix("sha256:"),
              !(reference.count == 64 && reference.allSatisfy(\.isHexDigit)) else {
            throw LuckyError("容器镜像没有可检查的名称或标签，请先在镜像页面选择目标版本")
        }
        let identifier = (data["Id"]?.stringValue ?? data["ID"]?.stringValue
                          ?? data["id"]?.stringValue ?? key).jsTrimmed
        guard !identifier.isEmpty else { throw LuckyError("缺少容器标识，无法更新") }
        id = identifier
        self.name = name
        imageReference = reference
    }

    /// A container action must never inherit the image API's default of updating all containers.
    var containerIDs: JSONValue { .array([.string(id)]) }
}

enum DockerImageUpgradeProtocol {
    enum Event {
        case heartbeat
        case progress(DockerImageUpgradeProgress)
        case complete(JSONValue)
    }

    static func socketURL(baseURL: String, token: String, image: String, millis: Int64? = nil,
                          credentialParameter: String = "Lucky-Admin-Token") -> URL? {
        guard var components = URLComponents(string: baseURL.jsTrimmed.withoutTrailingSlashes) else { return nil }
        switch components.scheme?.lowercased() {
        case "http": components.scheme = "ws"
        case "https": components.scheme = "wss"
        default: return nil
        }
        components.path = components.path.withoutTrailingSlashes + "/api/docker/images/upgrade-check-ws"
        let stamp = millis ?? Int64(Date().timeIntervalSince1970 * 1000)
        components.percentEncodedQuery = "image_ref=\(JSCompat.encodeURIComponent(image))"
            + "&\(JSCompat.encodeURIComponent(credentialParameter))=\(JSCompat.encodeURIComponent(token))&_=\(stamp)"
        components.fragment = nil
        return components.url
    }

    static func event(_ payload: JSONValue) throws -> Event {
        if payload["ret"]?.asInt == -1 {
            throw LuckyAuthError(payload["msg"]?.stringValue)
        }
        switch payload["type"]?.stringValue {
        case "ping", "pong": return .heartbeat
        case "progress":
            let number = payload["progress"]?.asNumber ?? 0
            let message = payload["message"]?.stringValue?.jsTrimmed ?? ""
            return .progress(DockerImageUpgradeProgress(
                percent: number.isFinite ? min(100, max(0, number)) : 0,
                message: message.isEmpty ? "正在检查镜像版本" : message
            ))
        case "complete":
            guard let data = payload["data"], data.isRecord else {
                throw LuckyError("服务端未返回镜像检查结果")
            }
            _ = try DockerImageUpgradeCheck(data)
            return .complete(data)
        case "cancelled": throw CancellationError()
        case "error":
            let message = payload["msg"]?.stringValue ?? payload["message"]?.stringValue ?? "镜像检查失败"
            if JSRegex.containsAny(message, ["token", "unauthorized", "登录已失效"]) {
                throw LuckyAuthError(message)
            }
            throw LuckyError(message)
        default: throw LuckyError("无法识别镜像更新检查响应")
        }
    }

    static func unwrap(_ payload: JSONValue, keys: [String]) -> JSONValue {
        var data = payload
        for _ in 0..<5 {
            guard let nested = keys.compactMap({ data[$0] }).first(where: \.isRecord) else { break }
            data = nested
        }
        return data
    }

    static func verifyUpgrade(_ payload: JSONValue) throws {
        let result = unwrap(payload, keys: ["data", "result"])
        let failed = result["failed"]?.asInt ?? 0
        guard failed == 0 else {
            let detail = result["results"]?.list.compactMap { $0["error"]?.stringValue }.first
            throw LuckyError(detail ?? "容器更新失败，请检查服务端日志后重试")
        }
        guard (result["upgraded"]?.asInt ?? 0) == 1 else {
            throw LuckyError("服务端未确认此容器已更新，请刷新列表后核对状态")
        }
    }
}
