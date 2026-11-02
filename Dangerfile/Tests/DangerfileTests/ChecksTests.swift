@testable import Dangerfile
import StewardTesting
import Testing

/// Every rule at once, as a run in GitHub Actions checks a pull request,
/// against a fake host that records what the run posts.
@Suite("Checks")
struct ChecksTests {
    @Test("a new library file without a project change fails, and the summary is posted")
    func failing() async throws {
        let workspace = try Workspace()
        try workspace.write("", to: "swiftlint.log")
        try workspace.write(CopyrightTests.sourceHeader, to: "Sources/CocoaLumberjack/DDNewLogger.m")
        let context = try Context.fixture(diff: SampleDiff.creation("Sources/CocoaLumberjack/DDNewLogger.m"), workspace: workspace.path)
        let host = FakePullRequestHost(pullRequest: context.pullRequest)
        let outcome = await Checks.run(on: context, postingTo: host)
        #expect(outcome.exitStatus == 1)
        #expect(outcome.report?.findings.map(\.rule) == ["Tests", "Carthage project"])
        #expect(await host.comments.map(\.body) == [outcome.summary])
    }

    @Test("a change with its tests and a clean lint report passes, and nothing is posted")
    func passing() async throws {
        let workspace = try Workspace()
        try workspace.write("", to: "swiftlint.log")
        try workspace.write(CopyrightTests.sourceHeader, to: "Sources/CocoaLumberjack/DDLog.m")
        try workspace.write(CopyrightTests.sourceHeader, to: "Tests/CocoaLumberjackTests/DDLogTests.m")
        let context = try Context.fixture(
            diff: SampleDiff.edit("Sources/CocoaLumberjack/DDLog.m") + SampleDiff.edit("Tests/CocoaLumberjackTests/DDLogTests.m"),
            workspace: workspace.path
        )
        let host = FakePullRequestHost(pullRequest: context.pullRequest)
        let outcome = await Checks.run(on: context, postingTo: host)
        #expect(outcome.exitStatus == 0)
        #expect(outcome.report?.findings == [])
        #expect(await host.comments.isEmpty)
    }
}
