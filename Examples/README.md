# Examples

## Supported Scenarios

- `RecentMessagesDatabaseCheck.playground` is a macOS Xcode playground that
  wraps the SwiftPM executable for interactive use. It defaults to `--help`, so
  opening and running it in Xcode does not touch a Messages database. Change
  `runMode` to `.copiedDatabase("/path/to/chat.db")` to run against a copied
  database.
- `RecentMessagesDatabaseCheck` is a macOS command-line Swift package that
  imports `AppMessageKit`, opens a Messages `chat.db` read-only, and prints the
  10 most recent conversations.

To use the playground, open this file in Xcode:

```text
Examples/RecentMessagesDatabaseCheck.playground
```

To run it against the default live Messages database:

```bash
cd Examples/RecentMessagesDatabaseCheck
swift run RecentMessagesDatabaseCheck
```

The live database defaults to `~/Library/Messages/chat.db` and may require Full
Disk Access for the host process. To avoid touching the live database, pass a
copied database path:

```bash
swift run RecentMessagesDatabaseCheck --database /path/to/chat.db
```

or:

```bash
APPMESSAGEKIT_MESSAGES_DB=/path/to/chat.db swift run RecentMessagesDatabaseCheck
```

The tool opens the database read-only. It never sends messages and never mutates
the database.

The checked-in example manifest depends on the public GitHub package URL so it
can be opened directly in Xcode without requiring access to this local checkout.
Open `Examples/RecentMessagesDatabaseCheck.playground` for the macOS Xcode
playground, or open `Examples/RecentMessagesDatabaseCheck/Package.swift` for
the SwiftPM executable package.

To validate the example from the repository root without opening a real Messages
database:

```bash
bash scripts/check-swift-playground-examples.sh --local-package
```

The local-package mode copies the example to a temporary directory and rewrites
that copy to depend on the local AppMessageKit checkout for integration
validation.
