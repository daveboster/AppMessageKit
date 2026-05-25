# AppMessageKit

Swift-native port of `photon-hq/imessage-kit` for macOS 26 and later, packaged
as an AppExperienceKit-style standalone Swift library.

The package is standalone and is not wired into the DitchKit Xcode project. It
exposes typed database queries, chat listing, AppleScript-based sending, WAL
watching, plugin hooks, and opt-in local database integration tests.

## Package

```swift
.package(url: "https://github.com/daveboster/AppMessageKit.git", branch: "main")
```

The library product is `AppMessageKit`.

## Basic Usage

```swift
import AppMessageKit

let sdk = try IMessageSDK()
let recent = try await sdk.messages(MessageQuery(limit: 25))
let chats = try await sdk.chats(ChatQuery(hasUnread: true))

try await sdk.send(SendRequest(to: "+15555550123", text: "Hello"))
try await sdk.close()
```

`send(_:)` resolves when Messages.app accepts the AppleScript dispatch. It does
not wait for delivery or for the sent row to appear in `chat.db`.

## Database Access

By default, the package opens:

```text
~/Library/Messages/chat.db
```

Access to the live Messages database requires macOS privacy approval, usually
Full Disk Access for the host process. Unit tests never open the live database.
Real database integration tests are opt-in:

```bash
APPMESSAGEKIT_INTEGRATION_DB=/path/to/chat.db \
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
swift test --filter Integration
```

Use a copied `chat.db` when possible. The reader opens databases read-only and
integration tests never send messages or mutate the database.

## Validation

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
CLANG_MODULE_CACHE_PATH=/private/tmp/clang-module-cache \
swift test
```

## Examples

`Examples/RecentMessagesDatabaseCheck.swiftpm` is a macOS console
playground-style package that imports `AppMessageKit`, verifies read access to a
local Messages database, and prints the 10 most recent conversations.

```bash
bash scripts/check-swift-playground-examples.sh
```

The public API keeps the iMessage-domain type names from the upstream port,
such as `IMessageSDK`, `IMessageConfig`, and `IMessageError`.

## Attribution

This package ports the public API and behavior of `photon-hq/imessage-kit`.
See `NOTICE.md` for upstream license attribution.
