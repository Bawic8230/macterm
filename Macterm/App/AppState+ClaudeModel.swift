import AppKit
import os

private let logger = Logger(subsystem: appBundleID, category: "ClaudeModel")

/// A Claude model the sidebar's "Claude Model" menu can switch a tab's
/// Claude Code session to. Switching types `/model <id>` into the session —
/// `/model` is an immediate command, accepted even while Claude is working —
/// so this list is the only thing to update when a model ships or retires.
/// A model the account can't use is refused by Claude Code itself, which says
/// so and leaves the model unchanged.
struct ClaudeModelChoice: Identifiable, Equatable {
    let title: String
    let id: String

    static let all: [ClaudeModelChoice] = [
        ClaudeModelChoice(title: "Opus 5.5", id: "claude-opus-5-5"),
        ClaudeModelChoice(title: "Opus 5", id: "claude-opus-5"),
        ClaudeModelChoice(title: "Opus 4.8", id: "claude-opus-4-8"),
        ClaudeModelChoice(title: "Opus 4.7", id: "claude-opus-4-7"),
        ClaudeModelChoice(title: "Opus 4.6", id: "claude-opus-4-6"),
        ClaudeModelChoice(title: "Fable 5.1", id: "claude-fable-5-1"),
        ClaudeModelChoice(title: "Sonnet 5", id: "claude-sonnet-5"),
        ClaudeModelChoice(title: "Haiku 4.5", id: "claude-haiku-4-5-20251001"),
    ]

    /// What gets typed into the session (without the submitting Return).
    var command: String { "/model \(id)" }
}

extension AppState {
    /// The pane in `tab` running Claude Code that a model switch should
    /// target: the focused pane when it is one, else the first. Nil when no
    /// pane in the tab is running Claude — the menu hides itself then, so a
    /// `/model` line never lands in a plain shell.
    func claudePane(in tab: TerminalTab) -> Pane? {
        let claudePanes = tab.splitRoot.allPanes().filter { $0.agentIcon == .claude }
        if let focused = tab.focusedPaneID, let pane = claudePanes.first(where: { $0.id == focused }) {
            return pane
        }
        return claudePanes.first
    }

    /// Type `/model <id>` and Return into the tab's Claude session. Text goes
    /// through the paste path and Return through the key-encoding path, so
    /// the line is submitted rather than pasted with a literal newline.
    @discardableResult
    func switchClaudeModel(_ model: ClaudeModelChoice, in tab: TerminalTab) -> Bool {
        guard let pane = claudePane(in: tab), let view = pane.nsView else {
            logger.info("model switch skipped: no live Claude pane in tab \(tab.id.uuidString, privacy: .public)")
            return false
        }
        guard view.sendText(model.command) else { return false }
        // 36 = Return. Sent on the next turn so the pasted text has landed in
        // Claude Code's input before the submit arrives.
        DispatchQueue.main.async {
            _ = view.sendKey(keyCode: 36, mods: [])
        }
        noteSessionLeader(pane)
        logger.info("switched Claude model to \(model.id, privacy: .public)")
        return true
    }
}
