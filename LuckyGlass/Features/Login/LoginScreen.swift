import SwiftUI

/// `app/login.tsx`.
///
/// Connection, credentials and the primary action stay together in one keyboard-aware scroll view.
struct LoginScreen: View {
    var addAccount: Bool = false
    @Environment(\.dismiss) private var dismiss
    private enum Field: Hashable { case remark, baseUrl, account, password, twoFACode }

    @State private var input = LuckyLoginInput()
    @State private var errors: [Field: String] = [:]
    @State private var failure = ""
    @State private var submitting = false
    @State private var seeded = false
    @State private var twoFAExpanded = false

    var body: some View {
        ZStack {
            LuckyBackdrop()
            ScrollView {
                VStack(alignment: .leading, spacing: LuckyTheme.Space.xl) {
                    header
                    card
                        .disabled(submitting)
                    loginButton
                    Label("登录凭据安全保存在此设备的钥匙串中", systemImage: "lock.shield")
                        .font(LuckyTheme.Text.caption)
                        .foregroundStyle(LuckyTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                    Text(LuckyAppVersion.displayString)
                        .font(LuckyTheme.Text.caption)
                        .foregroundStyle(LuckyTheme.textTertiary)
                        .monospacedDigit()
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: LuckyTheme.Layout.formWidth)
                .padding(.horizontal, LuckyTheme.Space.xl)
                .padding(.top, LuckyTheme.Space.xxl)
                .padding(.bottom, LuckyTheme.Space.pageBottom)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollBounceBehavior(.basedOnSize)
            .scrollClipDisabled()
        }
        .navigationTitle(addAccount ? "添加账号" : "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if addAccount {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .disabled(submitting)
                }
            }
        }
        .interactiveDismissDisabled(submitting)
        .task {
            // `defaultValues: { baseUrl: luckySessionState.baseUrl, … }` — read once, so typing is
            // never overwritten by a later store update.
            guard !addAccount, !seeded else { return }
            seeded = true
            let session = LuckySession.shared
            input.baseUrl = session.baseUrl
            input.account = session.account
            input.password = session.password
            input.remark = session.remark
        }
    }

    private var header: some View {
        VStack(spacing: LuckyTheme.Space.l) {
            LuckyMark(size: 80)
            VStack(spacing: LuckyTheme.Space.s) {
                Text(addAccount ? "连接新账号" : "连接到 Lucky")
                    .font(LuckyTheme.Text.hero)
                    .foregroundStyle(LuckyTheme.textPrimary)
                Text("你的服务器，尽在掌握。")
                    .font(LuckyTheme.Text.body)
                    .foregroundStyle(LuckyTheme.textSecondary)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.bottom, LuckyTheme.Space.s)
    }

    private var card: some View {
        LuckyCard(spacing: LuckyTheme.Space.l) {
            field(.baseUrl, "服务地址", "http://192.168.1.2:16601", "link",
                  keyboard: .URL, contentType: .URL)
            field(.remark, "备注（可选）", "例如：家里的服务器", "tag")
            LuckyHairline().padding(.vertical, LuckyTheme.Space.xs)
            field(.account, "管理员账号", "admin", "person",
                  contentType: .username)
            field(.password, "密码", "输入密码", "lock",
                  contentType: .password, secure: true)
            DisclosureGroup(isExpanded: $twoFAExpanded) {
                field(.twoFACode, "2FA 验证码", "6 位动态验证码", "key",
                      keyboard: .numberPad, contentType: .oneTimeCode)
                    .padding(.top, LuckyTheme.Space.m)
            } label: {
                Text("双重验证（可选）")
                    .font(LuckyTheme.Text.label)
                    .foregroundStyle(LuckyTheme.textSecondary)
                    .frame(minHeight: LuckyTheme.Space.touchTarget, alignment: .leading)
            }
            if !failure.isEmpty {
                Text(failure)
                    .font(LuckyTheme.Text.body)
                    .foregroundStyle(LuckyTheme.danger)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(LuckyTheme.Space.m)
                    .background(ConcentricRectangle().fill(LuckyTheme.dangerSoft))
            }
        }
    }

    private var loginButton: some View {
        Button(action: submit) {
            HStack(spacing: LuckyTheme.Space.s) {
                if submitting { ProgressView().tint(LuckyTheme.textOnAccent) }
                Text(submitting ? "正在连接…" : "连接服务器")
                    .font(LuckyTheme.Text.button)
                if !submitting { Image(systemName: "arrow.right") }
            }
            .foregroundStyle(LuckyTheme.textOnAccent)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(LuckyTheme.accent, in: .rect(cornerRadius: LuckyTheme.Radius.panel))
        }
        .buttonStyle(.plain)
        .disabled(submitting)
    }

    @ViewBuilder
    private func field(
        _ field: Field,
        _ label: String,
        _ placeholder: String,
        _ symbol: String,
        keyboard: UIKeyboardType = .default,
        contentType: UITextContentType? = nil,
        secure: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: LuckyTheme.Space.xs) {
            LuckyTextField(
                label: label,
                text: binding(field),
                placeholder: placeholder,
                symbol: symbol,
                secure: secure,
                keyboard: keyboard,
                autocapitalization: .never,
                contentType: contentType,
                submitLabel: field == .twoFACode || (field == .password && !twoFAExpanded) ? .go : .next,
                tone: errors[field] == nil ? nil : .danger,
                onSubmit: field == .twoFACode || (field == .password && !twoFAExpanded) ? submit : nil
            )
            if let message = errors[field] {
                Text(message)
                    .font(LuckyTheme.Text.caption)
                    .foregroundStyle(LuckyTheme.danger)
            }
        }
    }

    private func binding(_ field: Field) -> Binding<String> {
        switch field {
        case .remark: $input.remark
        case .baseUrl: $input.baseUrl
        case .account: $input.account
        case .password: $input.password
        // `onChangeText={(value) => field.onChange(value.replace(/\D/g, '').slice(0, 6))}`.
        case .twoFACode: Binding(
            get: { input.twoFACode },
            set: { input.twoFACode = String($0.filter(\.isASCIIDigit).prefix(6)) }
        )
        }
    }

    /// The zod schema. `z.string().url()` defers to the WHATWG URL parser, which requires a scheme
    /// and a non-empty authority — `URL(string:)` alone accepts `"admin"` as a relative reference,
    /// so the shape is checked explicitly.
    private func validate() -> [Field: String] {
        var found: [Field: String] = [:]
        if !isAbsoluteURL(input.baseUrl) {
            found[.baseUrl] = "请输入完整地址，例如 http://192.168.1.2:16601"
        }
        if input.account.isEmpty { found[.account] = "请输入管理员账号" }
        if input.password.isEmpty { found[.password] = "请输入密码" }
        if !input.twoFACode.isEmpty,
           !(input.twoFACode.count == 6 && input.twoFACode.allSatisfy(\.isASCIIDigit)) {
            found[.twoFACode] = "请输入6位数字验证码"
        }
        return found
    }

    private func isAbsoluteURL(_ text: String) -> Bool {
        guard let separator = text.range(of: "://") else { return false }
        let scheme = text[text.startIndex..<separator.lowerBound]
        guard let first = scheme.first, first.isLetter else { return false }
        let validScheme = scheme.allSatisfy { $0.isLetter || $0.isNumber || "+-.".contains($0) }
        let authority = text[separator.upperBound...].prefix { !"/?#".contains($0) }
        return validScheme && !authority.isEmpty
    }

    private func submit() {
        guard !submitting else { return }
        failure = ""
        let found = validate()
        errors = found
        if found[.twoFACode] != nil { twoFAExpanded = true }
        guard found.isEmpty else { return }
        submitting = true
        Task {
            defer { submitting = false }
            do {
                let token = try await LuckyClient.shared.signIn(input)
                await LuckySession.shared.save(
                    baseUrl: input.baseUrl,
                    account: input.account,
                    password: input.password,
                    token: token,
                    remark: input.remark
                )
                if addAccount { dismiss() }
                // `queryClient.clear()` then `router.replace('/monitor')`: there is no cache to
                // clear here, and the root view swaps to the tabs as soon as the token lands.
            } catch {
                failure = error.luckyMessage("登录失败")
            }
        }
    }
}

#if DEBUG
private struct LoginScreenPreviews: PreviewProvider {
    static var previews: some View {
        Group {
            LoginScreen().preferredColorScheme(.light).previewDisplayName("登录 · 浅色")
            LoginScreen().preferredColorScheme(.dark).previewDisplayName("登录 · 深色")
        }
    }
}
#endif

extension Character {
    /// `/\D/` and `/^\d{6}$/` match ASCII digits only — `isNumber` would also accept 一 and ٤.
    var isASCIIDigit: Bool { isASCII && isNumber }
}
