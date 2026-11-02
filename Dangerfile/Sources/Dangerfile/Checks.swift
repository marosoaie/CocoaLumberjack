import Foundation
import Steward

/// The rules Steward checks CocoaLumberjack's pull requests with, in the
/// order they run and their findings show. Ported from the danger-swift
/// `Dangerfile.swift` this package replaces.
///
/// In a GitHub Actions `pull_request` workflow, `swift run --package-path
/// Dangerfile` posts the summary as a comment on the pull request; anywhere
/// else it's a dry run that prints the summary. Each rule is a static
/// property, so a test can call it on its own (see Tests/DangerfileTests).
@main
struct Checks: Dangerfile {
    static var rules: [Rule] {
        workInProgress
        bigPullRequest
        testsUnmodified
        swiftLint
        carthageProject
        xcodeProjectSettings
        copyright
    }

    // MARK: - Pull request

    /// Make it more obvious that a pull request is a work in progress and
    /// shouldn't be merged yet.
    static let workInProgress = Rule("Work in progress") { context in
        let pullRequest = context.pullRequest
        guard pullRequest.title.contains("WIP"), !pullRequest.isDraft else { return [] }
        return [.warning("PR is marked as Work in Progress. Please consider marking the PR as Draft in GitHub to prevent merges.")]
    }

    /// Warn when there is a big pull request.
    static let bigPullRequest = Rule("Big pull request") { context in
        let sum = context.pullRequest.additions + context.pullRequest.deletions
        guard sum > 1000 else { return [] }
        return [.warning("Pull request is relatively big (\(sum) lines changed). If this PR contains multiple changes, consider splitting it into separate PRs for easier reviews.")]
    }

    /// Warn when library files have been updated but not tests.
    static let testsUnmodified = Rule("Tests") { context in
        let git = context.git
        let hasSourceChanges = (git.modifiedFiles + git.createdFiles).contains(where: \.isInSources)
        guard hasSourceChanges, !git.modifiedFiles.contains(where: \.isInTests) else { return [] }
        return [.warning("The library files were changed, but the tests remained unmodified. Consider updating or adding to the tests to match the library changes.")]
    }

    // MARK: - SwiftLint

    /// SwiftLint's violations on the lines the pull request changes, read
    /// from the report the workflow's SwiftLint step wrote.
    static let swiftLint = Rule.diagnosticsOnChangedLines(in: [.swiftLint("swiftlint.log")])

    // MARK: - Xcode project

    static let xcodeProjectFile = "Lumberjack.xcodeproj/project.pbxproj"

    /// Added (or removed) library files need to be added (or removed) from the
    /// Carthage Xcode project to avoid breaking things for our Carthage users.
    static let carthageProject = Rule("Carthage project") { context in
        let git = context.git
        guard (git.createdFiles + git.deletedFiles).contains(where: { $0.isInSources && $0.isSourceFile && !$0.isSPMOnlySourceFile }),
              !git.modifiedFiles.contains(xcodeProjectFile)
        else { return [] }
        return [.failure("Added or removed library files require the Carthage Xcode project to be updated.")]
    }

    static let acceptedSettings: Set<String> = [
        "APPLICATION_EXTENSION_API_ONLY",
        "ASSETCATALOG_COMPILER_APPICON_NAME",
        "ASSETCATALOG_COMPILER_LAUNCHIMAGE_NAME",
        "ATTRIBUTES",
        "CODE_SIGN_IDENTITY",
        "COMBINE_HIDPI_IMAGES",
        "FRAMEWORK_VERSION",
        "GCC_PRECOMPILE_PREFIX_HEADER",
        "GCC_PREFIX_HEADER",
        "IBSC_MODULE",
        "INFOPLIST_FILE",
        "MODULEMAP_FILE",
        "PRIVATE_HEADERS_FOLDER_PATH",
        "PRODUCT_BUNDLE_IDENTIFIER",
        "PRODUCT_NAME",
        "PUBLIC_HEADERS_FOLDER_PATH",
        "SDKROOT",
        "SUPPORTED_PLATFORMS",
        "TARGETED_DEVICE_FAMILY",
        "WRAPPER_EXTENSION",
    ]

    /// Check xcodeproj settings are not changed, and that none of the project's
    /// files has a line with "SOURCE_ROOT", which indicates that the file isn't
    /// in sync with Finder.
    static let xcodeProjectSettings = Rule("Xcode project settings") { context in
        guard context.git.modifiedFiles.contains(xcodeProjectFile),
              let contents = context.contents(of: xcodeProjectFile)
        else { return [] }
        var findings: [Finding] = []
        for (offset, line) in contents.split(separator: "\n").enumerated() {
            let location = Location(path: xcodeProjectFile, line: offset + 1)
            if line.contains("sourceTree = SOURCE_ROOT;"),
               line.contains("PBXFileReference"),
               !line.contains("path = Sources/CocoaLumberjackSwiftSupport/include/") {
                findings.append(.warning("Files should be in sync with project structure", at: location))
            }
            if let range = line.range(of: "[A-Z_]+ = .*;", options: .regularExpression) {
                let setting = String(line[range].prefix(while: { $0 != " " }))
                if !acceptedSettings.contains(setting) {
                    findings.append(.warning("Xcode settings need to remain in Configs/*.xcconfig. Please move " + setting + " to the xcconfig file", at: location))
                }
            }
        }
        return findings
    }

    // MARK: - Copyright

    static let copyrightLines = (
        source: [
            "// Software License Agreement (BSD License)",
            "//",
            "// Copyright (c) 2010-2026, Deusty, LLC",
            "// All rights reserved.",
            "//",
            "// Redistribution and use of this software in source and binary forms,",
            "// with or without modification, are permitted provided that the following conditions are met:",
            "//",
            "// * Redistributions of source code must retain the above copyright notice,",
            "//   this list of conditions and the following disclaimer.",
            "//",
            "// * Neither the name of Deusty nor the names of its contributors may be used",
            "//   to endorse or promote products derived from this software without specific",
            "//   prior written permission of Deusty, LLC.",
        ],
        demos: [
            "//",
            "//  ",
            "//  ",
            "//",
            "//  CocoaLumberjack Demos",
            "//",
        ],
        benchmarking: [
            "//",
            "//  ",
            "//  ",
            "//",
            "//  CocoaLumberjack Benchmarking",
            "//",
        ]
    )

    /// Every added or modified source file starts with the copyright header
    /// for where it lives (Sources, Demos and Benchmarking use different ones).
    static let copyright = Rule("Copyright") { context in
        let git = context.git
        let filesWithInvalidCopyright = Set(git.modifiedFiles + git.createdFiles)
            .filter { $0.isSourceFile && !$0.isSwiftPackageDefinition && !$0.isInDangerfile }
            .filter { !$0.isInVendor && !$0.isInFMDB }
            .filter { path in
                guard let contents = context.contents(of: path) else { return false }
                let actualLines = contents.split(separator: "\n").lazy.map(String.init)
                if path.isInDemos {
                    return !zip(actualLines, copyrightLines.demos).allSatisfy { $0.starts(with: $1) }
                } else if path.isInBenchmarking {
                    return !zip(actualLines, copyrightLines.benchmarking).allSatisfy { $0.starts(with: $1) }
                } else {
                    return !actualLines.starts(with: copyrightLines.source)
                }
            }
            .sorted()
        guard !filesWithInvalidCopyright.isEmpty else { return [] }
        return filesWithInvalidCopyright.map { .warning("Invalid copyright!", at: Location(path: $0, line: 1)) } + [
            .warning("""
                Copyright is not valid. See our default copyright in all of our files (Sources, Demos and Benchmarking use different formats).<br/>
                Invalid files:<br/>
                \(filesWithInvalidCopyright.map { "- \($0)" }.joined(separator: "<br/>\n"))
                """),
        ]
    }
}

extension Context {
    /// The text of the file at `path`, relative to the repository's root, as
    /// the checkout has it; `nil` when there's no such file.
    func contents(of path: String) -> String? {
        let url = URL(fileURLWithPath: run.workspace, isDirectory: true).appendingPathComponent(path)
        return try? String(contentsOf: url, encoding: .utf8)
    }
}

extension String {
    var isInSources: Bool { hasPrefix("Sources/") }
    var isInTests: Bool { hasPrefix("Tests/") }
    var isInDemos: Bool { hasPrefix("Demos/") }
    var isInBenchmarking: Bool { hasPrefix("Benchmarking/") }
    var isInDangerfile: Bool { hasPrefix("Dangerfile/") }

    var isInVendor: Bool { contains("/Vendor/") }
    var isInFMDB: Bool { contains("/FMDB/") }

    var isSourceFile: Bool {
        [".swift", ".m", ".mm", ".h"].contains(where: hasSuffix)
    }

    private static let spmOnlyTargetNames: Set<String> = [
        "CocoaLumberjackSwiftLogBackend",
    ]

    var isSPMOnlySourceFile: Bool {
        guard isSourceFile else { return false }
        if isInSources {
            return Self.spmOnlyTargetNames.contains(where: { contains("/\($0)/") })
        } else if isInTests {
            return Self.spmOnlyTargetNames.contains(where: { contains("/\($0)Tests/") })
        }
        return false
    }

    var isSwiftPackageDefinition: Bool {
        hasPrefix("Package") && hasSuffix(".swift")
    }
}
