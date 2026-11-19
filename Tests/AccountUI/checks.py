"""Linux-runnable source wiring guards; iOS compilation/UI testing remains required."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
def source(path):
    return (ROOT / "LuckyGlass" / path).read_text()

class AccountUIWiring(unittest.TestCase):
    def test_optional_remark_flows_from_form_to_session(self):
        model = source("Models/LuckyModels.swift")
        login = source("Features/Login/LoginScreen.swift")
        self.assertIn('var remark: String = ""', model)
        self.assertIn('field(.remark, "备注（可选）"', login)
        self.assertIn('case .remark: $input.remark', login)
        self.assertIn('input.remark = session.remark', login)
        self.assertIn('remark: input.remark', login)

    def test_add_account_is_blank_cancelable_and_dismisses_after_save(self):
        login = source("Features/Login/LoginScreen.swift")
        self.assertIn('var addAccount: Bool = false', login)
        self.assertIn('guard !addAccount, !seeded else { return }', login)
        self.assertIn('Button("取消") { dismiss() }', login)
        self.assertIn('if addAccount { dismiss() }', login)
        self.assertNotIn('.end()', login)
        self.assertLess(login.index('remark: input.remark'), login.index('if addAccount { dismiss() }'))
        self.assertIn('.interactiveDismissDisabled(submitting)', login)

    def test_dashboard_subtitle_opens_accessible_profile_picker(self):
        dashboard = source("Features/Dashboard/DashboardScreen.swift")
        header = source("Design/LuckyPage.swift")
        self.assertIn('subtitle: accountDisplayName', dashboard)
        self.assertIn('subtitleAction: { showingAccounts = true }', dashboard)
        self.assertIn('Button(action: subtitleAction)', header)
        self.assertIn('Image(systemName: "chevron.down")', header)
        self.assertIn('ForEach(session.profiles)', dashboard)
        self.assertIn('Text(profile.displayName)', dashboard)
        self.assertIn('Text(profile.account)', dashboard)
        self.assertIn('profile.id == session.activeProfileID', dashboard)
        self.assertIn('await session.switchTo(profileID: profile.id)', dashboard)
        self.assertIn('LoginScreen(addAccount: true)', dashboard)
        self.assertIn('.accessibilityValue(isCurrent ? "当前账号" : "")', dashboard)
        self.assertNotIn('profile.password', dashboard)
        self.assertNotIn('profile.token', dashboard)

    def test_authenticated_tree_resets_for_each_session_generation(self):
        app = source("App/LuckyGlassApp.swift")
        self.assertRegex(app, r'LuckyRoot\(\)\s*\.id\(session.sessionGeneration\)')

if __name__ == "__main__":
    unittest.main()
