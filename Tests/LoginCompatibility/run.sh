#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
out="$(mktemp -d)"
trap 'rm -rf "$out"' EXIT
# Compile the real login extension and JSON stack. The actor shell excludes unrelated UI/session code.
python3 - "$root" "$out" <<'PY'
import pathlib,sys
root,out=map(pathlib.Path,sys.argv[1:])
files=['JSCompat.swift','JSONObject.swift','JSONValue.swift','JSONSerializer.swift','JSONParser.swift','LuckyError.swift','LuckyRequest.swift','LuckyClient+Login.swift']
files += [p.name for p in (root/'LuckyGlass/Core').glob('LuckyLogin*.swift')]
for name in files:
 s=(root/'LuckyGlass/Core'/name).read_text()
 (out/name).write_text(s.replace('import Foundation','import Foundation\n#if canImport(FoundationNetworking)\nimport FoundationNetworking\n#endif',1))
s=(root/'LuckyGlass/Core/LuckyClient.swift').read_text()
helpers=s[s.index('    static func nonce('):s.index('    // MARK: - Request')]
deadline=(root/'LuckyGlass/Core/LuckyClient+Envelope.swift').read_text().split('extension LuckyClient {')[0]
(out/'Shell.swift').write_text('import Foundation\n#if canImport(FoundationNetworking)\nimport FoundationNetworking\n#endif\nactor LuckyClient { let session = URLSession.shared\n'+helpers+'}\nstruct LuckyLoginInput { var baseUrl: String; var account: String; var password: String; var twoFACode: String }\n'+deadline)
PY
if command -v swiftc >/dev/null 2>&1; then
  swiftc -swift-version 5 -parse-as-library "$out"/*.swift "$root/Tests/LoginCompatibility/Checks.swift" -o "$out/checks"
  "$out/checks"
else
  cp "$root/Tests/LoginCompatibility/Checks.swift" "$out/Checks.swift"
  docker run --rm -v "$out:/checks" -w /checks swift:6.2 bash -c 'swiftc -swift-version 5 -parse-as-library /checks/*.swift -o /checks/checks && /checks/checks'
fi
