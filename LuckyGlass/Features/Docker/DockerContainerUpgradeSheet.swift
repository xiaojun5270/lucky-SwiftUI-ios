import SwiftUI
import Observation

@MainActor
@Observable
private final class DockerContainerUpgradeModel {
    enum Phase { case checking, ready, current, pulling, upgrading, complete, failed }

    let key: String
    let name: String
    var phase: Phase = .checking
    var status = "正在读取容器镜像"
    var progress: Double = 0
    var failure = ""
    var target: DockerContainerUpgradeTarget?
    private var imagePulled = false
    private var pulledReference = ""
    private var generation = 0

    init(key: String, name: String) { self.key = key; self.name = name }
    var isMutating: Bool { phase == .pulling || phase == .upgrading }

    func check() async {
        generation += 1
        let request = generation
        phase = .checking
        status = "正在读取容器镜像"
        progress = 0
        failure = ""
        target = nil
        imagePulled = false
        pulledReference = ""
        do {
            let inspect = try await DockerService.container(key)
            let target = try DockerContainerUpgradeTarget(key: key, name: name, inspect: inspect)
            self.target = target
            // Match the web client's protection for the container hosting Lucky itself.
            if let info = try? await DockerService.selfContainerInfo(),
               info["running_in_container"]?.boolValue == true,
               info["self_container_id"]?.stringValue == target.id {
                throw LuckyError("这是 Lucky 正在运行的容器，请通过部署工具更新 Lucky 自身")
            }
            try Task.checkCancellation()
            status = "正在检查远程镜像版本"
            let payload = try await DockerService.checkImageUpgrade(target.imageReference) { [weak self] value in
                Task { @MainActor in
                    guard let self, self.generation == request, self.phase == .checking else { return }
                    self.progress = value.percent
                    self.status = value.message
                }
            }
            try Task.checkCancellation()
            guard generation == request else { return }
            let check = try DockerImageUpgradeCheck(payload)
            imagePulled = check.imagePulled
            phase = check.hasUpdate ? .ready : .current
            progress = 100
        } catch {
            guard generation == request, !error.isCancellation, !Task.isCancelled else { return }
            failure = error.luckyMessage("检查容器更新失败")
            phase = .failed
        }
    }

    func upgrade() async -> Bool {
        guard phase == .ready, let target else { return false }
        failure = ""
        phase = imagePulled ? .upgrading : .pulling
        do {
            if !imagePulled {
                let result = try await DockerService.pullImageWithBackup(target.imageReference, backupTag: true)
                let data = DockerImageUpgradeProtocol.unwrap(result, keys: ["data", "result"])
                pulledReference = data["image_ref"]?.stringValue?.jsTrimmed ?? ""
                imagePulled = true
            }
            phase = .upgrading
            let reference = pulledReference.isEmpty ? target.imageReference : pulledReference
            let result = try await DockerService.upgradeImageContainers(reference, containerIds: target.containerIDs)
            try DockerImageUpgradeProtocol.verifyUpgrade(result)
            phase = .complete
            return true
        } catch {
            // Keep the pulled image and checked target for retry; never broaden the selection.
            failure = error.luckyMessage("容器更新失败")
            phase = .ready
            return false
        }
    }
}

struct DockerContainerUpgradeSheet: View {
    var close: () -> Void
    var updated: () async -> Void
    @State private var model: DockerContainerUpgradeModel
    @State private var retry = 0
    @State private var confirming = false

    init(key: String, name: String, close: @escaping () -> Void, updated: @escaping () async -> Void) {
        self.close = close
        self.updated = updated
        _model = State(initialValue: DockerContainerUpgradeModel(key: key, name: name))
    }

    var body: some View {
        ServiceSheet(title: "更新容器", subtitle: model.name,
                     close: { if !model.isMutating { close() } }) {
            action
        } content: {
            LuckyCard {
                LuckyRow("容器", model.name)
                LuckyHairline()
                LuckyRow("镜像", model.target?.imageReference ?? "正在读取…", mono: true, lineLimit: nil)
            }
            if model.phase == .checking {
                LuckyCard {
                    Text(model.status).font(LuckyTheme.Text.body)
                    ProgressView(value: model.progress, total: 100).tint(LuckyTheme.accent)
                }
            } else if model.isMutating {
                LuckyLoadingView(text: model.phase == .pulling ? "正在下载新镜像并备份旧镜像…" : "正在重建此容器…")
            } else if model.phase == .ready {
                LuckyCard {
                    Label("发现镜像新版本", systemImage: "arrow.down.circle")
                        .font(LuckyTheme.Text.cardTitle)
                    Text("更新会短暂停止并重建此容器。其他使用同一镜像的容器不会一起更新，旧镜像会保留。")
                        .font(LuckyTheme.Text.body)
                        .foregroundStyle(LuckyTheme.textSecondary)
                }
            } else if model.phase == .current {
                LuckyEmptyState(symbol: "checkmark.circle", title: "当前镜像已是最新版本")
            } else if model.phase == .complete {
                LuckyEmptyState(symbol: "checkmark.circle", title: "容器已更新", message: "旧镜像已保留，可在镜像页面查看")
            }
            if !model.failure.isEmpty { LuckyErrorCard(message: model.failure) }
        }
        .interactiveDismissDisabled(model.isMutating)
        .task(id: retry) { await model.check() }
        .alert("确认更新容器", isPresented: $confirming) {
            Button("取消", role: .cancel) {}
            Button("更新", role: .destructive) {
                Task { if await model.upgrade() { await updated() } }
            }
        } message: {
            Text("将下载新镜像并重建容器“\(model.name)”。现有连接可能中断，确认继续？")
        }
    }

    @ViewBuilder
    private var action: some View {
        switch model.phase {
        case .checking:
            LuckyPillButton(title: "取消检查", symbol: "xmark", action: close)
        case .ready:
            LuckyPillButton(title: model.failure.isEmpty ? "更新此容器" : "重试更新",
                            symbol: "arrow.up.circle", prominent: true) { confirming = true }
        case .pulling, .upgrading:
            LuckyPillButton(title: model.phase == .pulling ? "正在下载镜像" : "正在重建容器",
                            prominent: true, loading: true, action: {})
        case .failed:
            LuckyPillButton(title: "重新检查", symbol: LuckySymbol.refresh, prominent: true) { retry += 1 }
        case .current, .complete:
            LuckyPillButton(title: "完成", symbol: "checkmark", prominent: true, action: close)
        }
    }
}
