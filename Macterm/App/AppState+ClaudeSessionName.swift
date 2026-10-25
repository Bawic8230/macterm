import AppKit
import os

private let logger = Logger(subsystem: appBundleID, category: "ClaudeSessionName")

/// Claude Code titles its terminal `<status glyph> <session name>` — `✳` while
/// idle, a spinner frame while working. A tab running Claude is named after
/// that session, so the session name is the single source of the tab's name:
/// the glyph is dropped for display (the sidebar has its own activity
/// indicator), and a rename from Macterm becomes a `/rename` of the session.
enum ClaudeSessionName {
    /// Glyphs Claude Code puts in front of the session name.
    private static let statusGlyphs: Set<Character> = ["✳", "✢", "✶", "✻", "✽", "·", "*", "◐", "◓", "◑", "◒"]

    /// `title` without Claude Code's leading status glyph. A title that is
    /// nothing but the glyph, or doesn't start with one, comes back unchanged.
    static func strippingStatusGlyph(_ title: String) -> String {
        guard let first = title.first, isStatusGlyph(first) else { return title }
        let rest = title.dropFirst()
        guard rest.first == " " else { return title }
        let name = rest.drop(while: { $0 == " " })
        return name.isEmpty ? title : String(name)
    }

    /// What gets typed into the session (without the submitting Return).
    static func renameCommand(_ name: String) -> String {
        "/rename \(name)"
    }

    private static func isStatusGlyph(_ character: Character) -> Bool {
        if statusGlyphs.contains(character) { return true }
        // Braille spinner frames (U+2800–U+28FF).
        guard let scalar = character.unicodeScalars.first, character.unicodeScalars.count == 1 else { return false }
        return (0x2800 ... 0x28FF).contains(scalar.value)
    }
}

extension AppState {
    /// Rename `tab` — the one path every rename (sidebar, CLI, ghostty
    /// keybind) goes through. A tab running Claude Code renames the session
    /// instead (`/rename <name>`) and keeps no custom title, so the tab goes
    /// on following the session's name, including later `/rename`s typed in
    /// Claude itself. Any other tab stores the name as its custom title. nil
    /// or empty restores automatic naming.
    func renameTab(_ tab: TerminalTab, to newName: String?) {
        let name = newName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !name.isEmpty, renameClaudeSession(in: tab, to: name) {
            tab.customTitle = nil
        } else {
            tab.customTitle = name.isEmpty ? nil : name
        }
        saveWorkspaces()
    }

    /// Type `/rename <name>` and Return into the tab's Claude session, the
    /// same way `switchClaudeModel` sends `/model`. False when the tab has no
    /// live Claude pane.
    private func renameClaudeSession(in tab: TerminalTab, to name: String) -> Bool {
        guard let pane = claudePane(in: tab), let view = pane.nsView else { return false }
        guard view.sendText(ClaudeSessionName.renameCommand(name)) else { return false }
        // 36 = Return, on the next turn so the pasted text has landed first.
        DispatchQueue.main.async {
            _ = view.sendKey(keyCode: 36, mods: [])
        }
        noteSessionLeader(pane)
        logger.info("renamed Claude session in tab \(tab.id.uuidString, privacy: .public)")
        return true
    }
}
