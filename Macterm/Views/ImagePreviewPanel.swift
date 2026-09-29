import AppKit
import os
import SwiftUI

private let logger = Logger(subsystem: appBundleID, category: "ImagePreviewPanel")

/// The right-hand image preview panel (`macterm preview <paths…>`).
///
/// A lightbox beside the terminal, not a pane in its split tree: the tree
/// stays untouched, and the panel reads this window's `WindowState`
/// (`previewItems` / `previewSelection`). Everything here is mouse-driven on
/// purpose — the terminal keeps keyboard focus, and a Japanese IME would eat
/// letter keys anyway.
struct ImagePreviewPanel: View {
    @Environment(WindowState.self)
    private var windowState

    /// Panel width, dragged from the leading edge. Per view is enough: the
    /// panel is transient, reopened by the next `macterm preview`.
    @State
    private var width: CGFloat = 380
    @State
    private var dragStartWidth: CGFloat?
    @State
    private var images: [URL: NSImage] = [:]

    private static let widthRange: ClosedRange<CGFloat> = 220 ... 1000

    private var items: [URL] { windowState.previewItems }

    private var selection: Int {
        min(max(windowState.previewSelection, 0), max(items.count - 1, 0))
    }

    private var current: URL? { items.indices.contains(selection) ? items[selection] : nil }

    var body: some View {
        HStack(spacing: 0) {
            resizeHandle
            VStack(spacing: 0) {
                header
                Rectangle().fill(MactermTheme.border).frame(height: 1)
                canvas
                if let current {
                    footer(for: current)
                }
                if items.count > 1 {
                    filmstrip
                }
            }
            .background(MactermTheme.surface.opacity(0.5))
        }
        .frame(width: width)
        .onChange(of: items, initial: true) { _, urls in load(urls) }
    }

    // MARK: - Pieces

    /// A 5pt strip on the leading edge: the divider line, and a drag target
    /// wide enough to find. Beside the pane, never over it, so a SwiftUI
    /// gesture sees the press.
    private var resizeHandle: some View {
        Rectangle()
            .fill(MactermTheme.border)
            .frame(width: 1)
            .padding(.horizontal, 2)
            .contentShape(Rectangle())
            .onHover { inside in
                if inside { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
            }
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { value in
                        let start = dragStartWidth ?? width
                        if dragStartWidth == nil { dragStartWidth = width }
                        let proposed = start - value.translation.width
                        width = min(max(proposed, Self.widthRange.lowerBound), Self.widthRange.upperBound)
                    }
                    .onEnded { _ in dragStartWidth = nil }
            )
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "photo")
                .foregroundStyle(MactermTheme.fgDim)
            Text(current?.lastPathComponent ?? "")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(MactermTheme.fg)
                .lineLimit(1)
                .truncationMode(.middle)
                .help(current?.path ?? "")
            Spacer(minLength: 4)
            if items.count > 1 {
                stepButton("chevron.left", help: "Previous image") { step(-1) }
                Text("\(selection + 1) / \(items.count)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(MactermTheme.fgMuted)
                stepButton("chevron.right", help: "Next image") { step(1) }
            }
            stepButton("xmark", help: "Close preview (\(closeHint))") {
                windowState.previewPanelVisible = false
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
    }

    private func stepButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(MactermTheme.fgMuted)
        .help(help)
    }

    private var canvas: some View {
        ZStack {
            if let current, let image = images[current] {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .background(CheckerboardBackground())
                    .shadow(color: .black.opacity(0.35), radius: 10, y: 3)
                    .padding(16)
                    .onTapGesture(count: 2) { QuickLookLauncher.open(items, startingAt: selection) }
                    .contextMenu { contextMenu(for: current) }
                    .help("Double-click for Quick Look")
            } else if current != nil {
                Text("Can't read this image")
                    .font(.system(size: 12))
                    .foregroundStyle(MactermTheme.fgDim)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func footer(for url: URL) -> some View {
        Text(metadata(for: url))
            .font(.system(size: 10.5, design: .monospaced))
            .foregroundStyle(MactermTheme.fgDim)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
    }

    private var filmstrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, url in
                        thumbnail(url, selected: index == selection)
                            .id(index)
                            .onTapGesture { windowState.previewSelection = index }
                            .onTapGesture(count: 2) { QuickLookLauncher.open(items, startingAt: index) }
                            .contextMenu { contextMenu(for: url) }
                            .help(url.lastPathComponent)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .onChange(of: selection) { _, index in
                withAnimation(.smooth(duration: 0.2)) { proxy.scrollTo(index, anchor: .center) }
            }
        }
        .frame(height: 68)
        .overlay(alignment: .top) { Rectangle().fill(MactermTheme.border).frame(height: 1) }
    }

    private func thumbnail(_ url: URL, selected: Bool) -> some View {
        ZStack {
            if let image = images[url] {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.medium)
                    .aspectRatio(contentMode: .fill)
            } else {
                MactermTheme.surface
            }
        }
        .frame(width: 60, height: 48)
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(selected ? MactermTheme.accent : MactermTheme.border, lineWidth: selected ? 2 : 1)
        )
        .opacity(selected ? 1 : 0.7)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func contextMenu(for url: URL) -> some View {
        Button("Quick Look") {
            QuickLookLauncher.open(items, startingAt: items.firstIndex(of: url) ?? selection)
        }
        Button("Open in Preview") { NSWorkspace.shared.open(url) }
        Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
        Divider()
        Button("Copy Path") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(url.path, forType: .string)
        }
    }

    // MARK: - Behavior

    private var closeHint: String {
        HotkeyRegistry.displayString(for: HotkeyRegistry.selectedShortcutString(for: .togglePreviewPanel))
    }

    private func step(_ delta: Int) {
        guard !items.isEmpty else { return }
        windowState.previewSelection = (selection + delta + items.count) % items.count
    }

    /// Decode each image once. `NSImage(contentsOf:)` is lazy about pixels,
    /// so this is cheap even for a handful of large files.
    private func load(_ urls: [URL]) {
        var next: [URL: NSImage] = [:]
        for url in urls {
            if let cached = images[url] {
                next[url] = cached
            } else if let image = NSImage(contentsOf: url), image.isValid {
                next[url] = image
            } else {
                logger.error("unreadable image: \(url.path, privacy: .public)")
            }
        }
        images = next
    }

    private func metadata(for url: URL) -> String {
        var parts: [String] = []
        if let image = images[url], let rep = image.representations.first,
           rep.pixelsWide > 0, rep.pixelsHigh > 0
        {
            parts.append("\(rep.pixelsWide)×\(rep.pixelsHigh)")
        }
        if let bytes = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize {
            parts.append(ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file))
        }
        parts.append(url.pathExtension.uppercased())
        return parts.joined(separator: " · ")
    }
}

/// The conventional transparency checkerboard, drawn only under the image's
/// own frame so an opaque image shows none of it.
private struct CheckerboardBackground: View {
    var body: some View {
        Canvas { context, size in
            let cell: CGFloat = 8
            let light = Color.white.opacity(0.10)
            let dark = Color.white.opacity(0.04)
            var row = 0
            var y: CGFloat = 0
            while y < size.height {
                var col = 0
                var x: CGFloat = 0
                while x < size.width {
                    let rect = CGRect(x: x, y: y, width: cell, height: cell)
                    context.fill(Path(rect), with: .color((row + col).isMultiple(of: 2) ? light : dark))
                    x += cell
                    col += 1
                }
                y += cell
                row += 1
            }
        }
    }
}

/// Quick Look via `qlmanage -p`: the system's own full-size viewer without
/// adopting `QLPreviewPanel`'s responder-chain control, which the terminal
/// view (first responder) would have to take part in. The selected image is
/// passed first so the viewer opens on it and ←/→ walk the rest.
///
/// A click anywhere outside the viewer's windows dismisses it, like a
/// lightbox: `qlmanage` is another process, so Macterm watches mouse-downs
/// (local for its own windows, global for everything else — mouse events
/// need no Accessibility grant) and tests them against the viewer's window
/// frames from the window server.
@MainActor
enum QuickLookLauncher {
    private static var process: Process?
    private static var monitors: [Any] = []

    static func open(_ urls: [URL], startingAt index: Int) {
        guard urls.indices.contains(index) else { return }
        close()
        let ordered = Array(urls[index...]) + Array(urls[..<index])
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/qlmanage")
        process.arguments = ["-p"] + ordered.map(\.path)
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        process.terminationHandler = { ended in
            Task { @MainActor in
                if Self.process === ended { stopWatching() }
            }
        }
        do {
            try process.run()
        } catch {
            logger.error("qlmanage failed: \(error.localizedDescription, privacy: .public)")
            return
        }
        self.process = process
        startWatching()
    }

    static func close() {
        stopWatching()
        if let process, process.isRunning { process.terminate() }
        process = nil
    }

    private static func startWatching() {
        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { event in
            dismissIfOutside(NSEvent.mouseLocation)
            return event
        }) {
            monitors.append(local)
        }
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { _ in
            let location = NSEvent.mouseLocation
            Task { @MainActor in dismissIfOutside(location) }
        }) {
            monitors.append(global)
        }
    }

    private static func stopWatching() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
    }

    /// `location` is in AppKit screen coordinates (origin bottom-left of the
    /// main screen); the window server reports top-left origin.
    private static func dismissIfOutside(_ location: NSPoint) {
        guard let process, process.isRunning else { return stopWatching() }
        let frames = viewerWindowFrames(pid: process.processIdentifier)
        // No window yet (still launching): don't count the click.
        guard !frames.isEmpty else { return }
        let mainHeight = NSScreen.screens.first?.frame.height ?? 0
        let flipped = CGPoint(x: location.x, y: mainHeight - location.y)
        if !frames.contains(where: { $0.contains(flipped) }) { close() }
    }

    private static func viewerWindowFrames(pid: pid_t) -> [CGRect] {
        guard let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]]
        else { return [] }
        return info.compactMap { window in
            guard (window[kCGWindowOwnerPID as String] as? pid_t) == pid,
                  let bounds = window[kCGWindowBounds as String] as? NSDictionary
            else { return nil }
            return CGRect(dictionaryRepresentation: bounds)
        }
    }
}
