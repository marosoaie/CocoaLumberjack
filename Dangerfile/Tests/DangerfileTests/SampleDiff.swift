import Foundation

/// Pull requests' diffs as `git diff` writes them, for the rule tests.
enum SampleDiff {
    /// An edit to `path` that adds its second line.
    static func edit(_ path: String) -> String {
        """
        diff --git a/\(path) b/\(path)
        index 1111111..2222222 100644
        --- a/\(path)
        +++ b/\(path)
        @@ -1,2 +1,3 @@
         import Foundation
        +let greeting = "Hello"
         print(greeting)

        """
    }

    /// A new file at `path`, one line long.
    static func creation(_ path: String) -> String {
        """
        diff --git a/\(path) b/\(path)
        new file mode 100644
        index 0000000..3333333
        --- /dev/null
        +++ b/\(path)
        @@ -0,0 +1 @@
        +import Foundation

        """
    }

    /// The deletion of the one-line file at `path`.
    static func deletion(_ path: String) -> String {
        """
        diff --git a/\(path) b/\(path)
        deleted file mode 100644
        index 3333333..0000000
        --- a/\(path)
        +++ /dev/null
        @@ -1 +0,0 @@
        -import Foundation

        """
    }

    static let xcodeProject = edit("Lumberjack.xcodeproj/project.pbxproj")
}

/// A checkout of its own for a test, in a temporary directory, for the rules
/// that read files.
struct Workspace: ~Copyable {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)

    var path: String { url.path }

    init() throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: url)
    }

    /// Writes `contents` to `path`, relative to the checkout's root.
    func write(_ contents: String, to path: String) throws {
        let file = url.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try contents.write(to: file, atomically: true, encoding: .utf8)
    }
}
