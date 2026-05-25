import Testing
@testable import RecentMessagesDatabaseCheck

@Suite("Database check configuration")
struct DatabaseCheckConfigurationTests {
    @Test("uses explicit database path and limit arguments")
    func usesExplicitDatabasePathAndLimitArguments() throws {
        let configuration = try DatabaseCheckConfiguration.parse(
            arguments: ["tool", "--database", "/tmp/chat.db", "--limit", "3"],
            environment: [:]
        )

        #expect(configuration.databasePath == "/tmp/chat.db")
        #expect(configuration.limit == 3)
    }

    @Test("uses environment database path when no argument is supplied")
    func usesEnvironmentDatabasePath() throws {
        let configuration = try DatabaseCheckConfiguration.parse(
            arguments: ["tool"],
            environment: [
                DatabaseCheckConfiguration.environmentDatabaseKey: "/tmp/from-env.db"
            ]
        )

        #expect(configuration.databasePath == "/tmp/from-env.db")
        #expect(configuration.limit == DatabaseCheckConfiguration.defaultLimit)
    }

    @Test("rejects invalid limits")
    func rejectsInvalidLimits() {
        #expect(throws: DatabaseCheckArgumentError.invalidLimit("0")) {
            try DatabaseCheckConfiguration.parse(
                arguments: ["tool", "--limit", "0"],
                environment: [:]
            )
        }
    }

    @Test("usage describes read-only database access")
    func usageDescribesReadOnlyDatabaseAccess() {
        let output = usage()

        #expect(output.contains("read-only"))
        #expect(output.contains("never sends messages"))
        #expect(output.contains("never mutates the database"))
    }
}
