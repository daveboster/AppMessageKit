#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
package_url="https://github.com/daveboster/AppMessageKit.git"
package_version="0.1.0-alpha.1"
dependency_mode="public"

if [[ "${1:-}" == "--local-package" ]]; then
    dependency_mode="local"
elif [[ "${1:-}" != "" ]]; then
    echo "usage: $0 [--local-package]" >&2
    exit 1
fi

source_path="$repo_root/Examples/RecentMessagesDatabaseCheck.swiftpm"

validate_manifest() {
    local manifest_path="$source_path/Package.swift"

    if grep -q 'path: "../.."' "$manifest_path"; then
        echo "error: RecentMessagesDatabaseCheck must use the public package URL, not a local path dependency." >&2
        exit 1
    fi

    if ! grep -q "$package_url" "$manifest_path"; then
        echo "error: RecentMessagesDatabaseCheck is missing public package URL $package_url." >&2
        exit 1
    fi

    if ! grep -q "exact: \"$package_version\"" "$manifest_path"; then
        echo "error: RecentMessagesDatabaseCheck must depend on prerelease $package_version." >&2
        exit 1
    fi
}

validate_manifest

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-/private/tmp/clang-module-cache}"

build_path="$source_path"
cleanup_path=""

if [[ "$dependency_mode" == "local" ]]; then
    cleanup_path="$(mktemp -d "${TMPDIR:-/tmp}/RecentMessagesDatabaseCheck.XXXXXX")"
    build_path="$cleanup_path/RecentMessagesDatabaseCheck.swiftpm"
    mkdir -p "$build_path"
    rsync -a \
        --exclude '.build' \
        --exclude '.swiftpm' \
        --exclude 'Package.resolved' \
        "$source_path/" \
        "$build_path/"
    perl -0pi -e "s#\\.package\\(url: \"$package_url\", exact: \"$package_version\"\\)#.package(name: \"AppMessageKit\", path: \"$repo_root\")#" "$build_path/Package.swift"
fi

swift test --package-path "$build_path"
swift run --package-path "$build_path" RecentMessagesDatabaseCheck --help

if [[ -n "$cleanup_path" ]]; then
    rm -rf "$cleanup_path"
fi
