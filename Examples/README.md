# Examples

## Supported Scenarios

- `RecentMessagesDatabaseCheck.swiftpm` is a macOS console playground-style
  package that imports `AppMessageKit`, opens a Messages `chat.db` read-only,
  and prints the 10 most recent conversations.

The example depends on the local package checkout with `.package(path: "../..")`
so it can be used directly from this branch while the package API is still
evolving.

To run it against the default live Messages database:

```bash
cd Examples/RecentMessagesDatabaseCheck.swiftpm
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

To validate the example from the repository root:

```bash
bash scripts/check-swift-playground-examples.sh
```
