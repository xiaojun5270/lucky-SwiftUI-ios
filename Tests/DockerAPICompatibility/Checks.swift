import Foundation

@main
enum DockerCompatibilityChecks {
    static func main() {
        var total = 0
        var failures = 0
        func check(_ name: String, _ condition: @autoclosure () -> Bool) {
            total += 1
            if !condition() { failures += 1; print("FAIL: \(name)") }
        }
        func rejects(_ name: String, _ operation: () throws -> Void,
                     where matches: (Error) -> Bool = { _ in true }) {
            total += 1
            do { try operation(); failures += 1; print("FAIL: \(name) accepted invalid data") }
            catch { if !matches(error) { failures += 1; print("FAIL: \(name) returned the wrong failure") } }
        }
        func json(_ text: String) -> JSONValue {
            guard let value = JSONParser.tryParse(text) else { fatalError("Invalid test fixture") }
            return value
        }

        let path = "/api/docker/images/upgrade-check-ws"
        check("matching missing route", DockerAPICompatibility.isUnavailableRoute(
            LuckyError("Are you ok? Request URL [GET][\(path)] not found", statusCode: 404), method: "GET", path: path))
        check("generic missing route", DockerAPICompatibility.isUnavailableRoute(
            LuckyError("404 page not found", statusCode: 404), method: "GET", path: path))
        check("method unavailable", DockerAPICompatibility.isUnavailableRoute(
            LuckyError("Method Not Allowed", statusCode: 405), method: "GET", path: path))
        for (name, error) in [
            ("missing container", LuckyError("No such container: missing", statusCode: 404)),
            ("registry failure", LuckyError("manifest unknown", statusCode: 404)),
            ("permission error", LuckyError("Access denied", statusCode: 403)),
            ("server error", LuckyError("Request URL [GET][\(path)] not found", statusCode: 500)),
            ("other missing route", LuckyError("Request URL [GET][/api/docker/something-else] not found", statusCode: 404)),
        ] {
            check(name + " must not trigger fallback", !DockerAPICompatibility.isUnavailableRoute(error, method: "GET", path: path))
        }
        check("auth must not trigger fallback", !DockerAPICompatibility.isUnavailableRoute(LuckyAuthError(), method: "GET", path: path))
        check("cancel must not trigger fallback", !DockerAPICompatibility.isUnavailableRoute(CancellationError(), method: "GET", path: path))

        if let url = DockerImageUpgradeProtocol.socketURL(baseURL: "https://example.invalid/secure/",
            token: "example+token&", image: "registry.example:5000/team/app:latest", millis: 1234),
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            check("secure socket scheme", components.scheme == "wss")
            check("keep server path prefix", components.path == "/secure/api/docker/images/upgrade-check-ws")
            check("encode image reference", components.queryItems?.first(where: { $0.name == "image_ref" })?.value == "registry.example:5000/team/app:latest")
            check("encode authentication query", components.queryItems?.first(where: { $0.name == "Lucky-Admin-Token" })?.value == "example+token&")
            check("socket uses timestamp", components.queryItems?.first(where: { $0.name == "_" })?.value == "1234")
        } else { check("socket URL", false) }
        check("reject unsupported URL scheme", DockerImageUpgradeProtocol.socketURL(baseURL: "ftp://example.invalid", token: "x", image: "app") == nil)

        do {
            switch try DockerImageUpgradeProtocol.event(json(#"{"type":"progress","progress":150,"message":"检查远程镜像"}"#)) {
            case .progress(let value): check("progress bounded and readable", value.percent == 100 && value.message == "检查远程镜像")
            default: check("decode progress event", false)
            }
            switch try DockerImageUpgradeProtocol.event(json(#"{"type":"pong"}"#)) {
            case .heartbeat: check("ignore heartbeat", true)
            default: check("ignore heartbeat", false)
            }
            let event = try DockerImageUpgradeProtocol.event(json(#"{"type":"complete","data":{"has_update":true,"image_pulled":true}}"#))
            if case .complete(let data) = event {
                let result = try DockerImageUpgradeCheck(data)
                check("available update and pulled image", result.hasUpdate && result.imagePulled)
            } else { check("complete event", false) }
            let current = try DockerImageUpgradeCheck(json(#"{"ret":0,"data":{"has_update":false}}"#))
            check("up to date response", !current.hasUpdate && !current.imagePulled)
        } catch { check("valid protocol fixtures", false) }
        rejects("check errors cannot mean latest", {
            _ = try DockerImageUpgradeProtocol.event(json(#"{"type":"complete","data":{"check_method":"error","error":"registry unavailable","has_update":false}}"#))
        }, where: { $0.luckyMessage() == "registry unavailable" })
        rejects("require update verdict", { _ = try DockerImageUpgradeCheck(json(#"{"data":{"image_id":"x"}}"#)) })
        rejects("cancelled event", { _ = try DockerImageUpgradeProtocol.event(json(#"{"type":"cancelled"}"#)) }, where: { $0.isCancellation })
        rejects("socket auth failure", { _ = try DockerImageUpgradeProtocol.event(json(#"{"type":"error","msg":"invalid token"}"#)) }, where: { $0 is LuckyAuthError })

        do {
            let target = try DockerContainerUpgradeTarget(key: "alias", name: "App", inspect: json(#"{"ret":0,"data":{"container":{"Id":"container-1","Image":"sha256:old","Config":{"Image":"registry.example:5000/team/app:latest"}}}}"#))
            check("inspect config wins over image digest", target.imageReference == "registry.example:5000/team/app:latest")
            check("upgrade only selected canonical container", target.containerIDs == .array([.string("container-1")]))
            try DockerImageUpgradeProtocol.verifyUpgrade(json(#"{"upgraded":1,"failed":0}"#))
            check("confirmed single upgrade", true)
        } catch { check("valid target and upgrade result", false) }
        rejects("missing image name", { _ = try DockerContainerUpgradeTarget(key: "id", name: "App", inspect: json(#"{"Config":{}}"#)) })
        rejects("bare image digest", { _ = try DockerContainerUpgradeTarget(key: "id", name: "App", inspect: json(#"{"Config":{"Image":"sha256:old"}}"#)) })
        rejects("failed recreation", { try DockerImageUpgradeProtocol.verifyUpgrade(json(#"{"upgraded":0,"failed":1,"results":[{"error":"recreate failed"}]}"#)) }, where: { $0.luckyMessage() == "recreate failed" })
        rejects("zero upgrades are not success", { try DockerImageUpgradeProtocol.verifyUpgrade(json(#"{"upgraded":0,"failed":0}"#)) })
        rejects("unexpected broad upgrade", { try DockerImageUpgradeProtocol.verifyUpgrade(json(#"{"upgraded":2,"failed":0}"#)) })
        print("Docker compatibility: \(total - failures)/\(total) checks passed")
        exit(failures == 0 ? 0 : 1)
    }
}
