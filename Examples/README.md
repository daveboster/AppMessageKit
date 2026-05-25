# Examples

## Supported Scenarios

- `RecentMessagesDatabaseCheck` is a macOS command-line Swift package that
  imports `AppMessageKit`, opens a Messages `chat.db` read-only, and prints the
  10 most recent conversations.

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
This is a standard Swift package, not a Swift Playgrounds app document. Open
`Examples/RecentMessagesDatabaseCheck/Package.swift` in Xcode.

To validate the example from the repository root without opening a real Messages
database:

```bash
bash scripts/check-swift-playground-examples.sh --local-package
```

The local-package mode copies the example to a temporary directory and rewrites
that copy to depend on the local AppMessageKit checkout for integration
validation.
