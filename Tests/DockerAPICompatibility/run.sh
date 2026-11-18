#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
test_output="$(mktemp -d)"
trap 'rm -f "$test_output/checks"; rmdir "$test_output"' EXIT

xcrun swiftc -swift-version 5 -parse-as-library \
  -target "$(uname -m)-apple-macosx13.0" \
  "$repo_root/LuckyGlass/Core/JSCompat.swift" \
  "$repo_root/LuckyGlass/Core/JSONObject.swift" \
  "$repo_root/LuckyGlass/Core/JSONValue.swift" \
  "$repo_root/LuckyGlass/Core/JSONSerializer.swift" \
  "$repo_root/LuckyGlass/Core/JSONParser.swift" \
  "$repo_root/LuckyGlass/Core/LuckyError.swift" \
  "$repo_root/LuckyGlass/Services/DockerAPICompatibility.swift" \
  "$repo_root/LuckyGlass/Services/DockerImageUpgradeProtocol.swift" \
  "$repo_root/Tests/DockerAPICompatibility/Checks.swift" \
  -o "$test_output/checks"
"$test_output/checks"
