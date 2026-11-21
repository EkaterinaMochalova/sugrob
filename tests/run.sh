#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT
swiftc -target "$(uname -m)-apple-macos13" Weather.swift Atmosphere.swift tests/WeatherTests.swift tests/AtmosphereTests.swift -o "$TEST_DIR/weather-tests"
"$TEST_DIR/weather-tests"
