@testable import Dangerfile
import StewardTesting
import Testing

@Suite("Copyright")
struct CopyrightTests {
    static let sourceHeader = Checks.copyrightLines.source.joined(separator: "\n") + "\n\nimport Foundation\n"

    static let demosHeader = """
        //
        //  FileLogger.swift
        //  FileLogger
        //
        //  CocoaLumberjack Demos
        //

        import Foundation

        """

    static func summary(_ files: [String]) -> Finding {
        .warning("""
            Copyright is not valid. See our default copyright in all of our files (Sources, Demos and Benchmarking use different formats).<br/>
            Invalid files:<br/>
            \(files.map { "- \($0)" }.joined(separator: "<br/>\n"))
            """)
    }

    @Test("source files with their copyright pass")
    func valid() async throws {
        let workspace = try Workspace()
        try workspace.write(Self.sourceHeader, to: "Sources/CocoaLumberjack/DDLog.m")
        try workspace.write(Self.demosHeader, to: "Demos/FileLogger/FileLogger.swift")
        let context = try Context.fixture(
            diff: SampleDiff.edit("Sources/CocoaLumberjack/DDLog.m") + SampleDiff.edit("Demos/FileLogger/FileLogger.swift"),
            workspace: workspace.path
        )
        let findings = try await Checks.copyright.evaluate(context)
        #expect(findings.isEmpty)
    }

    @Test("source files without their copyright get a warning each, and one that lists them")
    func invalid() async throws {
        let workspace = try Workspace()
        try workspace.write("import Foundation\n", to: "Sources/CocoaLumberjack/DDLog.m")
        try workspace.write(Self.sourceHeader, to: "Demos/FileLogger/FileLogger.swift")
        let context = try Context.fixture(
            diff: SampleDiff.edit("Sources/CocoaLumberjack/DDLog.m") + SampleDiff.creation("Demos/FileLogger/FileLogger.swift"),
            workspace: workspace.path
        )
        let findings = try await Checks.copyright.evaluate(context)
        #expect(findings == [
            .warning("Invalid copyright!", at: Location(path: "Demos/FileLogger/FileLogger.swift", line: 1)),
            .warning("Invalid copyright!", at: Location(path: "Sources/CocoaLumberjack/DDLog.m", line: 1)),
            Self.summary(["Demos/FileLogger/FileLogger.swift", "Sources/CocoaLumberjack/DDLog.m"]),
        ])
    }

    @Test(
        "files that don't carry the copyright pass",
        arguments: [
            "Package.swift",
            "Package@swift-6.2.swift",
            "Dangerfile/Sources/Dangerfile/Checks.swift",
            "Demos/Vendor/Thing.m",
            "Sources/CocoaLumberjack/Extensions/FMDB/FMDatabase.m",
            "README.md",
        ]
    )
    func exempt(path: String) async throws {
        let workspace = try Workspace()
        try workspace.write("import Foundation\n", to: path)
        let context = try Context.fixture(diff: SampleDiff.edit(path), workspace: workspace.path)
        let findings = try await Checks.copyright.evaluate(context)
        #expect(findings.isEmpty)
    }

    @Test("a deleted file passes")
    func deleted() async throws {
        let workspace = try Workspace()
        let context = try Context.fixture(diff: SampleDiff.deletion("Sources/CocoaLumberjack/DDLog.m"), workspace: workspace.path)
        let findings = try await Checks.copyright.evaluate(context)
        #expect(findings.isEmpty)
    }
}
