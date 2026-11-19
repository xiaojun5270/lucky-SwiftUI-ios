# Saved-account regression checks

Run from repository root:

```sh
bash Tests/AccountSwitching/run.sh
bash Tests/AccountSwitching/run-client.sh
bash Tests/AccountSwitching/run-status.sh
```

These compile actual Swift production sources using `swift:6.2` (Swift 5 language mode, matching existing compatibility suites). They do not contact any Lucky server. `run.sh` compiles the real observable session with in-memory Keychain and client/status boundary doubles. `run-client.sh` compiles the real networking actor, envelope, deadline and JSON code, suspending login with a continuation and intercepting HTTP with URLProtocol. `run-status.sh` compiles the real status store, exposing its private decode application/generation only in the temporary test copy to inject a status frame deterministically.

TDD observations during implementation:

- RED: missing saved-profile migration API. GREEN: migrated exact account/password and normalized URL.
- RED: missing remark/save/switch/generation API. GREEN: saved profiles, identity deduplication, persistence, switching, logout retention, lifecycle resets.
- RED: missing guarded token/end overloads. GREEN: stale account completions ignored.
- RED (runtime): `stale refresh must fail`. GREEN: request and refresh generation guards, no stale token save/session end.
- RED: status lifecycle reset missing. GREEN: previous-account data cleared and late decode ignored.
- RED (runtime): `joined stale refresh must fail`. GREEN: single-flight joiners also validate their original account generation.

The shell runners only add FoundationNetworking imports in temporary source copies for Linux; OS Keychain access and Apple Security RSA are not exercised here. The existing LoginCompatibility suite covers login protocol behavior separately.
