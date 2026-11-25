# LuckyGlass for iOS

Lucky 管理控制台的原生 SwiftUI 客户端，面向 iOS 26。

## App 版本

当前版本为 **1.2.8**，本地构建号为 **8**。设置页和登录页会显示已安装 App 的实际版本与构建号。

版本统一配置在 `Version.xcconfig`，Debug 与 Release 共用。后续发布时在此递增版本：修复问题递增末位，增加功能递增次位，重大变更递增首位。GitHub Actions 的构建号由配置中的基础构建号加工作流运行编号生成，每次新的打包运行自动递增；重跑同一次运行沿用原编号。

## 多账号与备注

- 登录页可填写可选备注名，用于在账号列表中辨认服务器和账号；备注不会发送给 Lucky 服务端。
- 点击「总览」标题下方的账号名称打开快速切换列表，优先显示备注名，同时提供账号与服务器信息。
- 在切换列表中选择「添加账号」可登录另一套 Lucky，不必先退出当前账号；取消添加不会退出原账号。
- 保存的账号凭据保存在设备钥匙串中。已有单账号会话会迁移为首个已保存账号。

## 本地构建

需要 Xcode 26。打开 `LuckyGlass.xcodeproj`，选择 `LuckyGlass` Scheme 和模拟器后运行。

真机调试需要在 Xcode 的 Signing & Capabilities 中选择自己的开发团队。

## 界面预览

在 Xcode 中打开 `DashboardScreen.swift`、`ServicesScreen.swift` 或 `LoginScreen.swift` 的 Canvas，可查看浅色、深色预览；总览和服务页还提供大字体预览。总览预览使用本地示例数据，无需连接 Lucky 服务器。

`WebRulesPreviews.swift` 提供 HTTP/HTTPS 规则的新布局，可交互展开 27 条示例子规则、搜索域名或后端地址、筛选状态与切换启停，并包含窄屏、深色和大字体预览。

`DockerContainersView.swift` 提供容器卡片预览，六项指标在常规字体下按三列两行排列，较大字体切换为两列，辅助功能字号切换为单列。

Docker 更新接口的兼容检查可在 macOS / Xcode 环境运行 `bash Tests/DockerAPICompatibility/run.sh`，GitHub Actions 会在打包前执行这些检查。

容器更新流程已按 Lucky 2.27.2 万吉版网页端核对：通过镜像 WebSocket 检测更新，确认后备份旧镜像、下载新镜像，并仅重建所选容器。

## 无证书 IPA

推送到 `main` 分支或在 GitHub Actions 中手动运行 **Build Unsigned iOS IPA**。构建完成后，在该次运行的 Artifacts 中下载 `lucky-ios-unsigned-ipa-v<版本>-build-<构建号>`。IPA 文件名同样包含版本与构建号，例如 `lucky-ios-1.1.0-build-42-unsigned.ipa`，具体编号以该次构建摘要为准。

无证书 IPA 不能直接通过 App Store 安装，需要使用支持自签名的安装工具重新签名。
