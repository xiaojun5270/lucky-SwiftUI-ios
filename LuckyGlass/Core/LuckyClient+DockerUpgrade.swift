import Foundation

extension LuckyClient {
    func checkDockerImageUpgrade(
        _ image: String,
        onProgress: (@Sendable (DockerImageUpgradeProgress) -> Void)? = nil
    ) async throws -> JSONValue {
        do {
            return try await receiveImageUpgrade(image, onProgress: onProgress)
        } catch is LuckyAuthError {
            do {
                _ = try await refreshToken()
                return try await receiveImageUpgrade(image, onProgress: onProgress)
            } catch {
                if error.isCancellation || Task.isCancelled { throw CancellationError() }
                if error is LuckyAuthError { await LuckySession.shared.end() }
                throw error
            }
        }
    }

    private func receiveImageUpgrade(
        _ image: String,
        onProgress: (@Sendable (DockerImageUpgradeProgress) -> Void)?
    ) async throws -> JSONValue {
        try Task.checkCancellation()
        let credentials = snapshot
        guard !credentials.baseUrl.isEmpty else { throw LuckyError("请先配置 Lucky 服务地址") }
        guard !credentials.token.isEmpty else { throw LuckyAuthError() }
        guard let url = DockerImageUpgradeProtocol.socketURL(
            baseURL: credentials.baseUrl, token: credentials.token, image: image
        ) else { throw LuckyError("服务地址无效，无法检查镜像更新") }

        let socket = session.webSocketTask(with: url)
        socket.resume()
        let heartbeat = Task {
            while !Task.isCancelled {
                do {
                    try await socket.send(.string("{\"type\":\"ping\"}"))
                    try await Task.sleep(for: .seconds(2))
                } catch { return }
            }
        }
        defer {
            heartbeat.cancel()
            socket.cancel(with: .normalClosure, reason: nil)
        }

        do {
            return try await withDeadline(150) {
                try await withTaskCancellationHandler {
                    while true {
                        try Task.checkCancellation()
                        let message = try await socket.receive()
                        let data: Data
                        switch message {
                        case .string(let text): data = Data(text.utf8)
                        case .data(let bytes): data = bytes
                        @unknown default: throw LuckyError("无法识别镜像更新检查响应")
                        }
                        guard let payload = JSONParser.tryParse(data) else {
                            throw LuckyError("无法解析镜像更新检查响应")
                        }
                        switch try DockerImageUpgradeProtocol.event(payload) {
                        case .heartbeat: continue
                        case .progress(let value): onProgress?(value)
                        case .complete(let value): return value
                        }
                    }
                } onCancel: {
                    // Cancel the pending receive as well as the task, including on deadline.
                    socket.cancel(with: .goingAway, reason: nil)
                }
            }
        } catch is DeadlineExceeded {
            throw LuckyError("镜像更新检查超时，请稍后重试")
        } catch {
            if Task.isCancelled || error.isCancellation { throw CancellationError() }
            if let status = (socket.response as? HTTPURLResponse)?.statusCode, status != 101 {
                if status == 401 { throw LuckyAuthError() }
                throw LuckyError("请求失败（HTTP \(status)）", statusCode: status)
            }
            if error is LuckyError || error is LuckyAuthError { throw error }
            // Do not include a socket URL, which carries the authentication query parameter.
            throw LuckyError("镜像更新检查连接失败，请检查 Lucky 服务端和网络")
        }
    }
}
