#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
out="$(mktemp -d)"
trap 'rm -rf "$out"' EXIT
python3 - "$root" "$out" <<'PY'
import pathlib,sys
root,out=map(pathlib.Path,sys.argv[1:])
files=['LuckySession.swift','JSCompat.swift','JSONObject.swift','JSONValue.swift','JSONParser.swift','JSONSerializer.swift']
files += [p.name for p in (root/'LuckyGlass/Core').glob('LuckyAccount*.swift')]
for name in files:
 (out/name).write_text((root/'LuckyGlass/Core'/name).read_text())
PY
cp "$root/Tests/AccountSwitching/Checks.swift" "$out/Checks.swift"
if command -v swiftc >/dev/null 2>&1; then
  swiftc -swift-version 5 -parse-as-library "$out"/*.swift -o "$out/checks"
  "$out/checks"
else
  docker run --rm -v "$out:/checks" -w /checks swift:6.2 bash -c 'swiftc -swift-version 5 -parse-as-library /checks/*.swift -o /checks/checks && /checks/checks'
fi
bash "$root/Tests/AccountSwitching/run-client.sh"
bash "$root/Tests/AccountSwitching/run-status.sh"
