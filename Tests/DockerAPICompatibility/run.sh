#!/bin/bash
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
test_output="$(mktemp -d)"
trap 'rm -rf "$test_output"' EXIT
cd "$repo_root"
sources=(
  LuckyGlass/Core/JSCompat.swift LuckyGlass/Core/JSONObject.swift
  LuckyGlass/Core/JSONValue.swift LuckyGlass/Core/JSONSerializer.swift
  LuckyGlass/Core/JSONParser.swift LuckyGlass/Core/LuckyError.swift
  LuckyGlass/Services/DockerAPICompatibility.swift
  LuckyGlass/Services/DockerImageUpgradeProtocol.swift
  Tests/DockerAPICompatibility/Checks.swift
)
if command -v xcrun >/dev/null; then
  xcrun swiftc -swift-version 5 -parse-as-library "${sources[@]}" -o "$test_output/checks"
  "$test_output/checks"
elif command -v swiftc >/dev/null; then
  swiftc -swift-version 5 -parse-as-library "${sources[@]}" -o "$test_output/checks"
  "$test_output/checks"
else
  docker run --rm -v "$repo_root:/src:ro" -w /src swift:6.2 \
    bash -c 'swiftc -swift-version 5 -parse-as-library "$@" -o /tmp/docker-checks && /tmp/docker-checks' -- "${sources[@]}"
fi
bash Tests/DockerAPICompatibility/run-services.sh
