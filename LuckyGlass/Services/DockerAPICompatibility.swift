import Foundation

enum DockerAPICompatibility {
    /// A missing route can justify a documented alternative API. A missing container,
    /// authentication failure, cancellation or registry error cannot.
    static func isUnavailableRoute(_ error: Error, method: String, path: String) -> Bool {
        guard !(error is LuckyAuthError), !error.isCancellation else { return false }
        if let status = (error as? LuckyError)?.statusCode,
           !(200..<300).contains(status), status != 404, status != 405 { return false }
        let message = error.luckyMessage().jsTrimmed.lowercased()
        let marker = "request url [\(method.lowercased())][\(path.lowercased())]"
        if let range = message.range(of: marker),
           message[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines) == "not found" {
            return true
        }
        guard let failure = error as? LuckyError else { return false }
        if failure.statusCode == 405 { return true }
        guard failure.statusCode == 404 else { return false }
        return ["404 page not found", "404 not found", "not found", "请求失败（http 404）"]
            .contains(message)
    }

    static func unsupported(_ operation: String) -> LuckyError {
        LuckyError("当前 Lucky 服务端不支持\(operation)。请升级 Lucky，或在 Web 管理端执行此操作。")
    }
}
