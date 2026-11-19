#!/bin/bash
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"
sources=(LuckyGlass/Core/JSCompat.swift LuckyGlass/Core/JSONObject.swift
 LuckyGlass/Core/JSONValue.swift LuckyGlass/Core/JSONSerializer.swift
 LuckyGlass/Core/JSONParser.swift LuckyGlass/Core/LuckyError.swift
 LuckyGlass/Core/LuckyRequest.swift LuckyGlass/Core/JSONUnwrap.swift
 LuckyGlass/Services/LuckyQuery.swift LuckyGlass/Services/DockerAPICompatibility.swift
 LuckyGlass/Services/WebService.swift Tests/WebServiceCompatibility/Checks.swift)
# Linux lacks Apple's UniformTypeIdentifiers; a test-only module provides its tiny
# upload metadata surface without replacing or rewriting production service code.
if command -v xcrun >/dev/null; then
 output="$(mktemp -d)"; trap 'rm -rf "$output"' EXIT
 xcrun swiftc -swift-version 5 -parse-as-library "${sources[@]}" -o "$output/checks"
 "$output/checks"
else
 docker run --rm -v "$repo_root:/work:ro" -w /work swift:6.2 bash -c '
 set -e
 mkdir -p /tmp/webservice-checks
 swiftc -emit-library -static -emit-module -module-name UniformTypeIdentifiers Tests/WebServiceCompatibility/UniformTypeIdentifiers.swift -emit-module-path /tmp/webservice-checks/UniformTypeIdentifiers.swiftmodule -o /tmp/webservice-checks/libUniformTypeIdentifiers.a
 swiftc -swift-version 5 -I /tmp/webservice-checks -L /tmp/webservice-checks -lUniformTypeIdentifiers -parse-as-library "$@" -o /tmp/webservice-checks/checks
 /tmp/webservice-checks/checks' -- "${sources[@]}"
fi
