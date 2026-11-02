@testable import Dangerfile
import StewardTesting
import Testing

@Suite("SwiftLint")
struct SwiftLintTests {
    static let diff = SampleDiff.edit("Sources/CocoaLumberjackSwift/DDLog+Combine.swift")

    @Test("a violation on an added line is reported at that line")
    func onAddedLine() async throws {
        let workspace = try Workspace()
        try workspace.write("""
            /ci/checkout/Sources/CocoaLumberjackSwift/DDLog+Combine.swift:2:22: warning: Force Unwrapping Violation: Force unwrapping should be avoided (force_unwrapping)
            /ci/checkout/Sources/CocoaLumberjackSwift/DDLog+Combine.swift:3:1: error: Empty Count Violation: Prefer checking `isEmpty` over comparing `count` to zero (empty_count)

            """, to: "swiftlint.log")
        let context = try Context.fixture(diff: Self.diff, workspace: workspace.path)
        let findings = try await Checks.swiftLint.evaluate(context)
        #expect(findings == [
            .warning(
                "Force Unwrapping Violation: Force unwrapping should be avoided (`force_unwrapping`)",
                at: Location(path: "Sources/CocoaLumberjackSwift/DDLog+Combine.swift", line: 2)
            ),
        ])
    }

    @Test("an error on an added line fails")
    func errorOnAddedLine() async throws {
        let workspace = try Workspace()
        try workspace.write("""
            /ci/checkout/Sources/CocoaLumberjackSwift/DDLog+Combine.swift:2:1: error: Empty Count Violation: Prefer checking `isEmpty` over comparing `count` to zero (empty_count)

            """, to: "swiftlint.log")
        let context = try Context.fixture(diff: Self.diff, workspace: workspace.path)
        let findings = try await Checks.swiftLint.evaluate(context)
        #expect(findings == [
            .failure(
                #"Empty Count Violation: Prefer checking \`isEmpty\` over comparing \`count\` to zero (`empty_count`)"#,
                at: Location(path: "Sources/CocoaLumberjackSwift/DDLog+Combine.swift", line: 2)
            ),
        ])
    }

    @Test("a missing report fails")
    func missingReport() async throws {
        let workspace = try Workspace()
        let context = try Context.fixture(diff: Self.diff, workspace: workspace.path)
        let findings = try await Checks.swiftLint.evaluate(context)
        #expect(findings.count == 1)
    }
}
