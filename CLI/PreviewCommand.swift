import ArgumentParser
import Foundation

/// `macterm preview <images…>` — show images in the right-hand preview panel
/// of the window you're in; `macterm preview --close` hides it.
///
/// Paths are resolved against the CALLER's working directory here, because
/// the app's own cwd means nothing to the shell that typed them. Non-images
/// are skipped (and reported on stderr) rather than failing the request.
struct PreviewCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "preview",
        abstract: "Show images in the window's preview panel.",
        discussion: """
        Replaces whatever the panel showed and opens it. Click a thumbnail or \
        use ←/→ to switch; double-click an image for Quick Look.
        """
    )

    @Argument(help: "Image files to show.", completion: .file())
    var paths: [String] = []

    @Flag(help: "Hide the preview panel instead.")
    var close = false

    @Option(help: "Window index or id (defaults to the key window).")
    var window: String?

    @OptionGroup var options: ConnectionOptions

    func validate() throws {
        if !close, paths.isEmpty {
            throw ValidationError("pass one or more image files, or --close")
        }
    }

    func run() throws {
        var args = ControlArgs(paths: close ? nil : paths.map(Self.absolutePath))
        args.window = window
        if close {
            try runControlCommand(command: "preview.close", args: args, options: options)
            return
        }
        try runControlCommand(command: "preview.open", args: args, options: options)
    }

    /// `path` made absolute against the caller's cwd, `~` expanded.
    static func absolutePath(_ path: String) -> String {
        let expanded = (path as NSString).expandingTildeInPath
        if expanded.hasPrefix("/") { return (expanded as NSString).standardizingPath }
        let cwd = FileManager.default.currentDirectoryPath
        return ((cwd as NSString).appendingPathComponent(expanded) as NSString).standardizingPath
    }
}
