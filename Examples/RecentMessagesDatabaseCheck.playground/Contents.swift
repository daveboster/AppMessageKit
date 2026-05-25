import Darwin
import Foundation

enum PlaygroundRunMode {
    case helpOnly
    case copiedDatabase(String)
    case liveDefaultMessagesDatabase
}

let runMode: PlaygroundRunMode = .helpOnly
// let runMode: PlaygroundRunMode = .copiedDatabase("/path/to/copied/chat.db")
// let runMode: PlaygroundRunMode = .liveDefaultMessagesDatabase

do {
    let output = try runRecentMessagesCheck(mode: runMode)
    print(output)
} catch {
    let message = "RecentMessagesDatabaseCheck playground failed:\n\(error)\n"
    FileHandle.standardError.write(Data(message.utf8))
    exit(EXIT_FAILURE)
}

func runRecentMessagesCheck(mode: PlaygroundRunMode) throws -> String {
    let packageURL = try recentMessagesPackageURL()
    var arguments = [
        "swift",
        "run",
        "--package-path",
        packageURL.path,
        "RecentMessagesDatabaseCheck"
    ]

    switch mode {
    case .helpOnly:
        arguments.append("--help")
    case let .copiedDatabase(path):
        guard !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PlaygroundCommandError.emptyDatabasePath
        }
        arguments.append(contentsOf: ["--database", path])
    case .liveDefaultMessagesDatabase:
        break
    }

    return try runXcrun(arguments: arguments, currentDirectory: packageURL)
}

private func recentMessagesPackageURL() throws -> URL {
    let playgroundURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    let examplesURL = playgroundURL.deletingLastPathComponent()
    let packageURL = examplesURL.appendingPathComponent("RecentMessagesDatabaseCheck", isDirectory: true)
    let manifestURL = packageURL.appendingPathComponent("Package.swift")

    guard FileManager.default.fileExists(atPath: manifestURL.path) else {
        throw PlaygroundCommandError.missingPackage(manifestURL.path)
    }

    return packageURL
}

private func runXcrun(arguments: [String], currentDirectory: URL) throws -> String {
    let process = Process()
    let output = Pipe()
    let error = Pipe()

    process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
    process.arguments = arguments
    process.currentDirectoryURL = currentDirectory
    process.standardOutput = output
    process.standardError = error

    var environment = ProcessInfo.processInfo.environment
    environment["DEVELOPER_DIR"] = environment["DEVELOPER_DIR"] ?? "/Applications/Xcode.app/Contents/Developer"
    process.environment = environment

    try process.run()
    process.waitUntilExit()

    let stdout = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    let stderr = String(data: error.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

    guard process.terminationStatus == 0 else {
        throw PlaygroundCommandError.commandFailed(
            status: process.terminationStatus,
            output: stdout,
            error: stderr
        )
    }

    return stdout
}

enum PlaygroundCommandError: Error, CustomStringConvertible {
    case missingPackage(String)
    case emptyDatabasePath
    case commandFailed(status: Int32, output: String, error: String)

    var description: String {
        switch self {
        case let .missingPackage(path):
            return "Missing sibling Swift package manifest at \(path). Keep this playground next to Examples/RecentMessagesDatabaseCheck."
        case .emptyDatabasePath:
            return "Provide a non-empty copied chat.db path before using .copiedDatabase."
        case let .commandFailed(status, output, error):
            return """
            xcrun swift run exited with status \(status).

            stdout:
            \(output)

            stderr:
            \(error)
            """
        }
    }
}
