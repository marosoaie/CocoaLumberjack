@testable import Dangerfile
import StewardTesting
import Testing

@Suite("Work in progress")
struct WorkInProgressTests {
    static let warning = Finding.warning("PR is marked as Work in Progress. Please consider marking the PR as Draft in GitHub to prevent merges.")

    @Test("a WIP pull request that's ready for review gets a warning")
    func readyForReview() async throws {
        let context = try Context.fixture(diff: SampleDiff.edit("README.md"), pullRequest: .fixture(title: "WIP: Faster file logger"))
        let findings = try await Checks.workInProgress.evaluate(context)
        #expect(findings == [Self.warning])
    }

    @Test("a WIP draft passes")
    func draft() async throws {
        let context = try Context.fixture(
            diff: SampleDiff.edit("README.md"),
            pullRequest: .fixture(title: "WIP: Faster file logger", isDraft: true)
        )
        let findings = try await Checks.workInProgress.evaluate(context)
        #expect(findings.isEmpty)
    }

    @Test("a pull request without WIP in its title passes")
    func notWorkInProgress() async throws {
        let context = try Context.fixture(diff: SampleDiff.edit("README.md"), pullRequest: .fixture(title: "Faster file logger"))
        let findings = try await Checks.workInProgress.evaluate(context)
        #expect(findings.isEmpty)
    }
}

@Suite("Big pull request")
struct BigPullRequestTests {
    @Test("more than 1000 changed lines gets a warning")
    func big() async throws {
        let context = try Context.fixture(diff: SampleDiff.edit("README.md"), pullRequest: .fixture(additions: 900, deletions: 101))
        let findings = try await Checks.bigPullRequest.evaluate(context)
        #expect(findings == [.warning("Pull request is relatively big (1001 lines changed). If this PR contains multiple changes, consider splitting it into separate PRs for easier reviews.")])
    }

    @Test("1000 changed lines pass")
    func atTheLimit() async throws {
        let context = try Context.fixture(diff: SampleDiff.edit("README.md"), pullRequest: .fixture(additions: 900, deletions: 100))
        let findings = try await Checks.bigPullRequest.evaluate(context)
        #expect(findings.isEmpty)
    }
}

@Suite("Tests")
struct TestsUnmodifiedTests {
    static let warning = Finding.warning("The library files were changed, but the tests remained unmodified. Consider updating or adding to the tests to match the library changes.")

    @Test("a library change without a test change gets a warning")
    func libraryOnly() async throws {
        let context = try Context.fixture(diff: SampleDiff.edit("Sources/CocoaLumberjack/DDLog.m"))
        let findings = try await Checks.testsUnmodified.evaluate(context)
        #expect(findings == [Self.warning])
    }

    @Test("a new library file without a test change gets a warning")
    func newLibraryFile() async throws {
        let context = try Context.fixture(diff: SampleDiff.creation("Sources/CocoaLumberjack/DDNewLogger.m"))
        let findings = try await Checks.testsUnmodified.evaluate(context)
        #expect(findings == [Self.warning])
    }

    @Test("a library change with a modified test passes")
    func withTests() async throws {
        let context = try Context.fixture(
            diff: SampleDiff.edit("Sources/CocoaLumberjack/DDLog.m") + SampleDiff.edit("Tests/CocoaLumberjackTests/DDLogTests.m")
        )
        let findings = try await Checks.testsUnmodified.evaluate(context)
        #expect(findings.isEmpty)
    }

    @Test("a change outside the library passes")
    func outsideLibrary() async throws {
        let context = try Context.fixture(diff: SampleDiff.edit("README.md"))
        let findings = try await Checks.testsUnmodified.evaluate(context)
        #expect(findings.isEmpty)
    }
}
