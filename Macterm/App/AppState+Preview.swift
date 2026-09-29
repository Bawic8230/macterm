import Foundation
import UniformTypeIdentifiers

/// The right-hand image preview panel (`macterm preview <paths…>`).
///
/// Kept in its own extension so the feature stays one self-contained diff on
/// top of upstream: the per-window state lives on `WindowState`, and these are
/// the app-wide entry points (CLI, hotkey, palette) that resolve to the window
/// the user is in — the same mirror shape as `sidebarVisible`.
extension AppState {
    /// The window an app-wide preview request lands in.
    private var previewTargetWindow: WindowState? {
        keyWindow ?? windows.first
    }

    var previewPanelVisible: Bool {
        get { previewTargetWindow?.previewPanelVisible ?? false }
        set { previewTargetWindow?.previewPanelVisible = newValue }
    }

    /// Show `urls` in the preview panel, replacing whatever it showed, and
    /// open it. Returns false when there is no window to show them in.
    @discardableResult
    func openPreview(_ urls: [URL], in window: WindowState? = nil) -> Bool {
        guard let target = window ?? previewTargetWindow, !urls.isEmpty else { return false }
        target.previewItems = urls
        target.previewSelection = 0
        target.previewPanelVisible = true
        return true
    }

    /// Toggle the panel. Opening it with nothing to show is pointless, so a
    /// toggle on an empty panel stays closed.
    func togglePreviewPanel() {
        guard let target = previewTargetWindow else { return }
        if target.previewPanelVisible {
            target.previewPanelVisible = false
        } else if !target.previewItems.isEmpty {
            target.previewPanelVisible = true
        }
    }

    /// Split `paths` into images the panel can show and everything else
    /// (missing files, directories, non-image types). Pure — the control
    /// handler and tests share it.
    nonisolated static func previewableImages(_ paths: [String]) -> (shown: [URL], skipped: [String]) {
        var shown: [URL] = []
        var skipped: [String] = []
        for path in paths {
            let url = URL(fileURLWithPath: (path as NSString).standardizingPath)
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
                  !isDirectory.boolValue,
                  let type = UTType(filenameExtension: url.pathExtension),
                  type.conforms(to: .image)
            else {
                skipped.append(path)
                continue
            }
            shown.append(url)
        }
        return (shown, skipped)
    }
}
