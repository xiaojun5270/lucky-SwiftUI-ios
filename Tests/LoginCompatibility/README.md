# Login compatibility checks

Run `bash Tests/LoginCompatibility/run.sh` from any directory. Requires Python 3 and either a local Swift compiler (macOS), or Docker with `swift:6.2` (Linux).

The runner compiles the actual login extension, JSON implementation, URL/nonce helpers, deadline implementation and request types. A minimal actor shell excludes unrelated application/UI session dependencies. URLProtocol supplies controlled server responses; no production credentials or server configuration changes are needed.

Linux exercises negotiation, V2 fallback, fail-closed errors, refresh classification, URL base paths, token extraction, exact credential schemas, surrogate escaping, and UTF-8 chunking. Apple platforms additionally exercise the production Security RSA encryption against a generated private key and a complete V3 request flow. Linux explicitly skips that Security-only test; it does not substitute another crypto implementation.

## Observed server protocol

Verified against Lucky V2 2.27.2 and V3 3.8.1 plus captured V3 web assets:

- `Fo()` generates 32 cryptographically random bytes, lowercase hex, in `Lucky-Login-Session`.
- `c6()` reuses that header for GET `/api/login/challenge` and POST `/api/login`.
- Challenge response is top-level `ret`, `challengeId`, `nonce`, `publicKey`; no cookie is required (`binding: session`).
- `Ec()` encrypts ordered `{account,password,twoFA,challengeId,nonce}` JSON. The supplied login-screen code maps to V3 `twoFA`.
- `Oo()` escapes UTF-16 surrogates, including astral characters as surrogate pairs.
- `zo()` / `Rc()` use JSEncrypt RSAES-PKCS1-v1_5, splitting at 120 UTF-8 bytes without breaking scalar boundaries and joining base64 ciphertext blocks with periods.
- Outer POST is `{challengeId,cipherText}` only.
- V2 challenge endpoint returns 404; `/version` returns `{ret:0,version:"2.27.2"}`. Plaintext is allowed only when challenge is explicitly absent (404/405) AND `/version` confirms major version 2. Other errors never permit downgrade.

No cookie setting changes or new project file inclusions are required: the encryption helper lives in the existing login Swift source.
