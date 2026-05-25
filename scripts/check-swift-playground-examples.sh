#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
package_url="https://github.com/daveboster/AppMessageKit.git"
package_version="0.1.0-alpha.3"
dependency_mode="public"

if [[ "${1:-}" == "--local-package" ]]; then
    dependency_mode="local"
elif [[ "${1:-}" != "" ]]; then
    echo "usage: $0 [--local-package]" >&2
    exit 1
fi

package_source_path="$repo_root/Examples/RecentMessagesDatabaseCheck"
playground_source_path="$repo_root/Examples/RecentMessagesDatabaseCheck.playground"

validate_manifest() {
    local manifest_path="$package_source_path/Package.swift"

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

validate_playground() {
    local playground_manifest="$playground_source_path/contents.xcplayground"
    local playground_source="$playground_source_path/Contents.swift"

    if [[ ! -f "$playground_manifest" ]]; then
        echo "error: RecentMessagesDatabaseCheck.playground is missing contents.xcplayground." >&2
        exit 1
    fi

    if [[ ! -f "$playground_source" ]]; then
        echo "error: RecentMessagesDatabaseCheck.playground is missing Contents.swift." >&2
        exit 1
    fi

    if ! grep -q "target-platform='macos'" "$playground_manifest"; then
        echo "error: RecentMessagesDatabaseCheck.playground must target macOS." >&2
        exit 1
    fi

    if ! grep -q 'let runMode: PlaygroundRunMode = .helpOnly' "$playground_source"; then
        echo "error: RecentMessagesDatabaseCheck.playground must default to help-only mode." >&2
        exit 1
    fi

    if ! grep -q 'case copiedDatabase' "$playground_source"; then
        echo "error: RecentMessagesDatabaseCheck.playground must support an explicit copied database path." >&2
        exit 1
    fi

    if ! grep -q 'PlaygroundRuntimeContext' "$playground_source"; then
        echo "error: RecentMessagesDatabaseCheck.playground must not depend only on #filePath for package discovery." >&2
        exit 1
    fi

    if ! grep -q 'packagePathOverride' "$playground_source"; then
        echo "error: RecentMessagesDatabaseCheck.playground must expose an editable package path override." >&2
        exit 1
    fi
}

validate_manifest
validate_playground

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-/private/tmp/clang-module-cache}"

build_path="$package_source_path"
playground_path="$playground_source_path"
cleanup_path=""

if [[ "$dependency_mode" == "local" ]]; then
    cleanup_path="$(mktemp -d "${TMPDIR:-/tmp}/RecentMessagesDatabaseCheck.XXXXXX")"
    build_path="$cleanup_path/RecentMessagesDatabaseCheck"
    playground_path="$cleanup_path/RecentMessagesDatabaseCheck.playground"
    mkdir -p "$build_path"
    rsync -a \
        --exclude '.build' \
        --exclude '.swiftpm' \
        --exclude 'Package.resolved' \
        "$package_source_path/" \
        "$build_path/"
    rsync -a "$playground_source_path/" "$playground_path/"
    perl -0pi -e "s#\\.package\\(url: \"$package_url\", exact: \"$package_version\"\\)#.package(name: \"AppMessageKit\", path: \"$repo_root\")#" "$build_path/Package.swift"
fi

rm -rf "$build_path/.build"
swift test --package-path "$build_path"
swift run --package-path "$build_path" RecentMessagesDatabaseCheck --help
APPMESSAGEKIT_PLAYGROUND_EXIT_ON_FAILURE=1 swift "$playground_path/Contents.swift"

if [[ -n "$cleanup_path" ]]; then
    rm -rf "$cleanup_path"
fi
