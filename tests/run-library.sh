#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT
swiftc -target "$(uname -m)-apple-macos13" Weather.swift Atmosphere.swift LiveCamera.swift InlineCamera.swift CityLibrary.swift tests/CityLibraryTests.swift -o "$TEST_DIR/library-tests"
"$TEST_DIR/library-tests"
