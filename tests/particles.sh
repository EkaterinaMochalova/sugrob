#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT
# Compile the production particle engine without its application entry point.
sed '/\/\/ MARK: - Окно настроек/,$d' main.swift > "$TEST_DIR/ParticleEngine.swift"
swiftc -target "$(uname -m)-apple-macos13" "$TEST_DIR/ParticleEngine.swift" Weather.swift Atmosphere.swift tests/ParticlesTests.swift -o "$TEST_DIR/particle-tests"
"$TEST_DIR/particle-tests"
