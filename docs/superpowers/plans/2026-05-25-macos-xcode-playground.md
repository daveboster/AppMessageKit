# macOS Xcode Playground Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a macOS Xcode playground that can run the recent Messages database check without turning the example into an iOS Swift Playgrounds app project.

**Architecture:** Keep `Examples/RecentMessagesDatabaseCheck` as the validated SwiftPM executable package and add `Examples/RecentMessagesDatabaseCheck.playground` as a thin Xcode macOS playground wrapper. The playground runs the SwiftPM executable with `--help` by default and only queries a database after the user supplies an explicit copied `chat.db` path or intentionally selects the live default mode.

**Tech Stack:** Swift 6, Xcode macOS playground format, SwiftPM executable package, shell validation script.

---

### Task 1: Add Playground Validation

**Files:**
- Modify: `scripts/check-swift-playground-examples.sh`
- Later create: `Examples/RecentMessagesDatabaseCheck.playground/contents.xcplayground`
- Later create: `Examples/RecentMessagesDatabaseCheck.playground/Contents.swift`

- [x] **Step 1: Extend validation script before creating the playground**

Add a `playground_path` variable, validate the playground document shape, copy the playground into the temporary local-package fixture, and run `Contents.swift` as a CLI-compatible smoke test. The smoke test must keep the default path on `--help`, so it does not open a Messages database.

- [x] **Step 2: Run validation and verify it fails for the missing playground**

Run:

```bash
bash scripts/check-swift-playground-examples.sh --local-package
```

Expected: fails with an error that `RecentMessagesDatabaseCheck.playground/contents.xcplayground` or `Contents.swift` is missing.

### Task 2: Add the macOS Playground

**Files:**
- Create: `Examples/RecentMessagesDatabaseCheck.playground/contents.xcplayground`
- Create: `Examples/RecentMessagesDatabaseCheck.playground/Contents.swift`
- Modify: `Examples/README.md`
- Modify: `README.md`

- [x] **Step 1: Create the macOS Xcode playground document**

Create `contents.xcplayground` with Xcode's macOS playground shape:

```xml
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<playground version='7.0' target-platform='macos' swift-version='6' buildActiveScheme='true' executeOnSourceChanges='false' importAppTypes='true'/>
```

- [x] **Step 2: Create the playground wrapper source**

Create `Contents.swift` that:
- imports `Foundation`
- defaults to `PlaygroundRunMode.helpOnly`
- resolves the sibling `RecentMessagesDatabaseCheck` package from a runtime context because Xcode playgrounds can expose a synthetic `#filePath`
- exposes an editable `packagePathOverride` when Xcode opens the playground from an unusual runtime location
- runs `/usr/bin/xcrun swift run --package-path <package> RecentMessagesDatabaseCheck --help` by default
- allows an explicit copied database path through `.copiedDatabase("/path/to/chat.db")`
- keeps live `~/Library/Messages/chat.db` access behind `.liveDefaultMessagesDatabase`
- prints the executable output and exits with a clear error if `swift run` fails

- [x] **Step 3: Update docs**

Update root and example READMEs to say:
- open `Examples/RecentMessagesDatabaseCheck.playground` in Xcode for the macOS playground
- leave the playground in help mode until a copied database path is supplied
- the SwiftPM executable remains the scriptable validation target
- the tool opens databases read-only, never sends messages, and never mutates the database

### Task 3: Verify and Publish Without Merge

**Files:**
- Validate all files changed above.

- [x] **Step 1: Run local validation**

Run:

```bash
bash scripts/check-swift-playground-examples.sh --local-package
```

Expected: 6 example tests pass, executable `--help` prints, playground wrapper prints the same help path without opening a database.

- [x] **Step 2: Run public dependency validation**

Run:

```bash
bash scripts/check-swift-playground-examples.sh
```

Expected: resolves the public AppMessageKit prerelease, 6 example tests pass, executable `--help` prints, playground wrapper prints the same help path without opening a database.

- [x] **Step 3: Run root package tests**

Run:

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer CLANG_MODULE_CACHE_PATH=/private/tmp/clang-module-cache swift test
```

Expected: AppMessageKit root tests pass.

- [x] **Step 4: Commit, push, and open a draft PR**

Use an explicit file list when staging so untracked `.DS_Store` and `.build` artifacts are not included. Open a draft PR for user verification and do not merge it.
