#!/bin/bash
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
output="$(mktemp -d)"
trap 'rm -rf "$output"' EXIT
sources=(
  LuckyGlass/Core/JSCompat.swift LuckyGlass/Core/JSONObject.swift
  LuckyGlass/Core/JSONValue.swift LuckyGlass/Core/JSONSerializer.swift
  LuckyGlass/Core/JSONParser.swift LuckyGlass/Core/LuckyError.swift
  LuckyGlass/Core/LuckyRequest.swift LuckyGlass/Core/JSONUnwrap.swift
  LuckyGlass/Services/LuckyQuery.swift LuckyGlass/Services/ScoredRecords.swift
  LuckyGlass/Services/DockerAPICompatibility.swift
  LuckyGlass/Services/DockerImageUpgradeProtocol.swift
  LuckyGlass/Services/DockerService.swift LuckyGlass/Services/DdnsService.swift
  LuckyGlass/Services/SslService.swift LuckyGlass/Services/TunnelsService.swift
  Tests/DockerAPICompatibility/ServiceHarness.swift
)
cd "$repo_root"
if command -v xcrun >/dev/null; then
  xcrun swiftc -swift-version 5 -parse-as-library "${sources[@]}" -o "$output/checks"
  "$output/checks"
elif command -v swiftc >/dev/null; then
  swiftc -swift-version 5 -parse-as-library "${sources[@]}" -o "$output/checks"
  "$output/checks"
else
  docker run --rm -v "$repo_root:/src:ro" -w /src swift:6.2 \
    bash -c 'swiftc -swift-version 5 -parse-as-library "$@" -o /tmp/service-checks && /tmp/service-checks' -- "${sources[@]}"
fi
