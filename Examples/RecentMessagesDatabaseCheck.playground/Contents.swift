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
    if ProcessInfo.processInfo.environment["APPMESSAGEKIT_PLAYGROUND_EXIT_ON_FAILURE"] == "1" {
        exit(EXIT_FAILURE)
    }
}

func runRecentMessagesCheck(mode: PlaygroundRunMode) throws -> String {
    let packageURL = try recentMessagesPackageURL(context: .current)
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

struct PlaygroundRuntimeContext {
    var sourceFilePath: String
    var currentDirectoryPath: String
    var environment: [String: String]
    var bundlePaths: [String]

    static var current: PlaygroundRuntimeContext {
        PlaygroundRuntimeContext(
            sourceFilePath: #filePath,
            currentDirectoryPath: FileManager.default.currentDirectoryPath,
            environment: ProcessInfo.processInfo.environment,
            bundlePaths: [
                Bundle.main.bundlePath,
                Bundle.main.resourcePath
            ].compactMap { $0 }
        )
    }
}

private func recentMessagesPackageURL(context: PlaygroundRuntimeContext) throws -> URL {
    let fileManager = FileManager.default
    var candidates: [URL] = []

    if let override = context.environment["APPMESSAGEKIT_RECENT_MESSAGES_PACKAGE"], !override.isEmpty {
        candidates.append(URL(fileURLWithPath: override, isDirectory: true))
    }

    let sourceURL = URL(fileURLWithPath: context.sourceFilePath)
    if context.sourceFilePath.hasPrefix("/") && fileManager.fileExists(atPath: sourceURL.path) {
        addCandidates(near: sourceURL.deletingLastPathComponent(), to: &candidates)
    }

    addCandidates(near: URL(fileURLWithPath: context.currentDirectoryPath, isDirectory: true), to: &candidates)

    if let pwd = context.environment["PWD"], !pwd.isEmpty {
        addCandidates(near: URL(fileURLWithPath: pwd, isDirectory: true), to: &candidates)
    }

    for path in context.bundlePaths {
        addCandidates(near: URL(fileURLWithPath: path, isDirectory: true), to: &candidates)
    }

    let home = fileManager.homeDirectoryForCurrentUser
    candidates.append(home.appendingPathComponent("code/github/AppMessageKit/Examples/RecentMessagesDatabaseCheck", isDirectory: true))
    candidates.append(home.appendingPathComponent("Developer/AppMessageKit/Examples/RecentMessagesDatabaseCheck", isDirectory: true))

    var checked: [String] = []
    for candidate in uniqueURLs(candidates) {
        let manifestURL = candidate.appendingPathComponent("Package.swift")
        checked.append(manifestURL.path)
        if fileManager.fileExists(atPath: manifestURL.path) {
            return candidate
        }
    }

    throw PlaygroundCommandError.missingPackage(checked)
}

private func addCandidates(near anchor: URL, to candidates: inout [URL]) {
    let path = anchor.standardizedFileURL.path

    if path.hasSuffix(".playground") {
        let examplesURL = anchor.deletingLastPathComponent()
        candidates.append(examplesURL.appendingPathComponent("RecentMessagesDatabaseCheck", isDirectory: true))
    }

    candidates.append(anchor.appendingPathComponent("RecentMessagesDatabaseCheck", isDirectory: true))
    candidates.append(anchor.appendingPathComponent("Examples/RecentMessagesDatabaseCheck", isDirectory: true))
    candidates.append(anchor.deletingLastPathComponent().appendingPathComponent("RecentMessagesDatabaseCheck", isDirectory: true))
    candidates.append(anchor.deletingLastPathComponent().appendingPathComponent("Examples/RecentMessagesDatabaseCheck", isDirectory: true))
    candidates.append(anchor.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("RecentMessagesDatabaseCheck", isDirectory: true))
    candidates.append(anchor.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Examples/RecentMessagesDatabaseCheck", isDirectory: true))
}

private func uniqueURLs(_ urls: [URL]) -> [URL] {
    var seen: Set<String> = []
    var result: [URL] = []
    for url in urls {
        let path = url.standardizedFileURL.path
        if seen.insert(path).inserted {
            result.append(URL(fileURLWithPath: path, isDirectory: true))
        }
    }
    return result
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
    case missingPackage([String])
    case emptyDatabasePath
    case commandFailed(status: Int32, output: String, error: String)

    var description: String {
        switch self {
        case let .missingPackage(paths):
            return """
            Missing RecentMessagesDatabaseCheck Package.swift.

            Keep this playground next to Examples/RecentMessagesDatabaseCheck, or set APPMESSAGEKIT_RECENT_MESSAGES_PACKAGE to the package folder.

            Checked:
            \(paths.joined(separator: "\n"))
            """
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
