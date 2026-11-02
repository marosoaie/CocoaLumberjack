@testable import Dangerfile
import StewardTesting
import Testing

@Suite("Carthage project")
struct CarthageProjectTests {
    static let failure = Finding.failure("Added or removed library files require the Carthage Xcode project to be updated.")

    @Test("a new library file without a project change fails")
    func added() async throws {
        let context = try Context.fixture(diff: SampleDiff.creation("Sources/CocoaLumberjack/DDNewLogger.m"))
        let findings = try await Checks.carthageProject.evaluate(context)
        #expect(findings == [Self.failure])
    }

    @Test("a removed library file without a project change fails")
    func removed() async throws {
        let context = try Context.fixture(diff: SampleDiff.deletion("Sources/CocoaLumberjack/include/CocoaLumberjack/DDOldLogger.h"))
        let findings = try await Checks.carthageProject.evaluate(context)
        #expect(findings == [Self.failure])
    }

    @Test("a new library file with a project change passes")
    func withProject() async throws {
        let context = try Context.fixture(diff: SampleDiff.creation("Sources/CocoaLumberjack/DDNewLogger.m") + SampleDiff.xcodeProject)
        let findings = try await Checks.carthageProject.evaluate(context)
        #expect(findings.isEmpty)
    }

    @Test(
        "files that aren't in the Carthage project pass",
        arguments: [
            "Sources/CocoaLumberjackSwiftLogBackend/DDLogHandler.swift",
            "Sources/CocoaLumberjack/PrivacyInfo.xcprivacy",
            "Tests/CocoaLumberjackTests/DDNewLoggerTests.m",
        ]
    )
    func notInProject(path: String) async throws {
        let context = try Context.fixture(diff: SampleDiff.creation(path))
        let findings = try await Checks.carthageProject.evaluate(context)
        #expect(findings.isEmpty)
    }
}

@Suite("Xcode project settings")
struct XcodeProjectSettingsTests {
    static let path = "Lumberjack.xcodeproj/project.pbxproj"

    @Test("a build setting outside the xcconfig files gets a warning at its line")
    func setting() async throws {
        let workspace = try Workspace()
        try workspace.write("""
            // !$*UTF8*$!
            {
            \t\t\t\tPRODUCT_NAME = CocoaLumberjack;
            \t\t\t\tSWIFT_VERSION = 5.0;
            }
            """, to: Self.path)
        let context = try Context.fixture(diff: SampleDiff.xcodeProject, workspace: workspace.path)
        let findings = try await Checks.xcodeProjectSettings.evaluate(context)
        #expect(findings == [
            .warning(
                "Xcode settings need to remain in Configs/*.xcconfig. Please move SWIFT_VERSION to the xcconfig file",
                at: Location(path: Self.path, line: 4)
            ),
        ])
    }

    @Test("a file reference relative to the project's root gets a warning at its line")
    func sourceRoot() async throws {
        let workspace = try Workspace()
        try workspace.write("""
            // !$*UTF8*$!
            {
            \t\t55C7E1F4 /* DDLog.m */ = {isa = PBXFileReference; path = Sources/CocoaLumberjack/DDLog.m; sourceTree = SOURCE_ROOT; };
            \t\t55C7E1F5 /* DDLog.h */ = {isa = PBXFileReference; path = Sources/CocoaLumberjackSwiftSupport/include/DDLog.h; sourceTree = SOURCE_ROOT; };
            \t\t55C7E1F6 /* DDLog.swift */ = {isa = PBXFileReference; path = DDLog.swift; sourceTree = "<group>"; };
            }
            """, to: Self.path)
        let context = try Context.fixture(diff: SampleDiff.xcodeProject, workspace: workspace.path)
        let findings = try await Checks.xcodeProjectSettings.evaluate(context)
        #expect(findings == [
            .warning("Files should be in sync with project structure", at: Location(path: Self.path, line: 3)),
        ])
    }

    @Test("a project that wasn't modified isn't read")
    func unmodified() async throws {
        let workspace = try Workspace()
        try workspace.write("SWIFT_VERSION = 5.0;\n", to: Self.path)
        let context = try Context.fixture(diff: SampleDiff.edit("README.md"), workspace: workspace.path)
        let findings = try await Checks.xcodeProjectSettings.evaluate(context)
        #expect(findings.isEmpty)
    }
}
