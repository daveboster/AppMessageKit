#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
example_path="$repo_root/Examples/RecentMessagesDatabaseCheck.swiftpm"

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-/private/tmp/clang-module-cache}"

swift test --package-path "$example_path"
swift run --package-path "$example_path" RecentMessagesDatabaseCheck --help
