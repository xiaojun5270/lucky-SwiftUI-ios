#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
out="$(mktemp -d)"
trap 'rm -rf "$out"' EXIT
python3 - "$root" "$out" <<'PY'
import pathlib,sys
root,out=map(pathlib.Path,sys.argv[1:])
s=(root/'LuckyGlass/Core/StatusStream.swift').read_text()
assert '/api/temp-access-tickets' in s, 'V3 status must obtain a temporary-access ticket before opening its websocket'
assert 'await Self.socketRequest(' in s, 'Status connection must use the ticket request, not the legacy token URL'
for name in ['JSCompat.swift','JSONObject.swift','JSONValue.swift','JSONSerializer.swift','JSONParser.swift','LuckyError.swift','LuckyRequest.swift','StatusProtobuf.swift','StatusStream.swift']:
 s=(root/'LuckyGlass/Core'/name).read_text()
 (out/name).write_text(s.replace('import Foundation','import Foundation\n#if canImport(FoundationNetworking)\nimport FoundationNetworking\n#endif',1))
(out/'LuckyStatus.swift').write_text((root/'LuckyGlass/Models/LuckyStatus.swift').read_text())
PY
cp "$root/Tests/StatusCompatibility/Checks.swift" "$out/Checks.swift"
if command -v swiftc >/dev/null 2>&1; then
 swiftc -swift-version 5 -parse-as-library "$out"/*.swift -o "$out/checks"
 "$out/checks"
else
 docker run --rm -v "$out:/checks" -w /checks swift:6.2 bash -c 'swiftc -swift-version 5 -parse-as-library /checks/*.swift -o /checks/checks && /checks/checks'
fi
