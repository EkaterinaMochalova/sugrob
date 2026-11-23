#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT
sed '/^final class Overlay/,$d' main.swift | sed '${/^@MainActor$/d;}' > "$TEST_DIR/main.swift"
cat tests/ParticleChecks.swift >> "$TEST_DIR/main.swift"
swiftc -target "$(uname -m)-apple-macos13" "$TEST_DIR/main.swift" Weather.swift Atmosphere.swift -o "$TEST_DIR/particles"
"$TEST_DIR/particles"
