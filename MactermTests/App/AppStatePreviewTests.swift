import AppKit
import Foundation
@testable import Macterm
import Testing

@MainActor
struct AppStatePreviewTests {
    private func makeAppState() -> AppState {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("macterm-preview-tests-\(UUID().uuidString).json")
        let projectsDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("macterm-preview-tests-projects-\(UUID().uuidString)", isDirectory: true)
        return AppState(
            workspaceStore: WorkspaceStore(fileURL: tmp),
            projectFiles: ProjectFileStore(directoryURL: projectsDir)
        )
    }

    /// A real 2×2 PNG in a fresh temp dir.
    private func makePNG(named name: String = "image.png") throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("macterm-preview-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let rep = try #require(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 2, pixelsHigh: 2, bitsPerSample: 8,
            samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ))
        let data = try #require(rep.representation(using: .png, properties: [:]))
        let url = dir.appendingPathComponent(name)
        try data.write(to: url)
        return url
    }

    @Test
    func previewable_images_skips_missing_directories_and_non_images() throws {
        let png = try makePNG()
        let text = png.deletingLastPathComponent().appendingPathComponent("notes.txt")
        try "hi".write(to: text, atomically: true, encoding: .utf8)
        let dir = png.deletingLastPathComponent().path

        let (shown, skipped) = AppState.previewableImages([png.path, text.path, dir, "/no/such/file.png"])

        #expect(shown == [png])
        #expect(skipped == [text.path, dir, "/no/such/file.png"])
    }

    @Test
    func open_preview_fills_and_opens_the_key_window_only() throws {
        let state = makeAppState()
        let a = WindowState()
        let b = WindowState()
        state.registerWindow(a)
        state.registerWindow(b)
        state.noteKeyWindow(b)
        let png = try makePNG()

        #expect(state.openPreview([png]))

        #expect(b.previewPanelVisible)
        #expect(b.previewItems == [png])
        #expect(b.previewSelection == 0)
        #expect(!a.previewPanelVisible)
        #expect(a.previewItems.isEmpty)
    }

    @Test
    func open_preview_replaces_items_and_resets_selection() throws {
        let state = makeAppState()
        let window = WindowState()
        state.registerWindow(window)
        let first = try makePNG(named: "a.png")
        let second = try makePNG(named: "b.png")
        state.openPreview([first, second])
        window.previewSelection = 1

        state.openPreview([second])

        #expect(window.previewItems == [second])
        #expect(window.previewSelection == 0)
    }

    @Test
    func toggle_does_not_open_an_empty_panel() {
        let state = makeAppState()
        let window = WindowState()
        state.registerWindow(window)

        state.togglePreviewPanel()
        #expect(!window.previewPanelVisible)

        window.previewItems = [URL(fileURLWithPath: "/tmp/x.png")]
        state.togglePreviewPanel()
        #expect(window.previewPanelVisible)
        state.togglePreviewPanel()
        #expect(!window.previewPanelVisible)
    }

    @Test
    func open_preview_without_a_window_reports_failure() {
        #expect(!makeAppState().openPreview([URL(fileURLWithPath: "/tmp/x.png")]))
    }
}
