import AppKit
import os

private let logger = Logger(subsystem: appBundleID, category: "SystemDictation")

/// macOS Dictation (F5 / fn) keeps listening after the Return that commits its
/// text. A plain Return in a pane ends it, the way pressing F5 again would.
///
/// Two things here are AppKit internals, both measured against a probe app on
/// macOS 26 before use:
/// - Whether dictation is running comes from the `_NSTextInputContextDictation
///   DidStart/DidEndNotification` posts. They arrive for dictation started by
///   the F5 key, which AppKit's own `NSApplication.stopDictation:` does not know
///   about — that action toggles, so it *started* dictation on an ordinary
///   Return and never stopped the F5 session (9ae86ef, reverted).
/// - Stopping is the input context's `_stopDictation:`, which ends the session
///   at once and posts DidEnd. It is only ever sent while DidStart is the last
///   post seen, so a typed Return can never start dictation.
/// If a macOS release renames either, the observers never fire and Return
/// simply leaves dictation running, as before.
@MainActor
enum SystemDictation {
    private(set) static var isActive = false
    private static var observers: [NSObjectProtocol] = []

    static func startObserving() {
        guard observers.isEmpty else { return }
        for (name, active) in [
            ("_NSTextInputContextDictationDidStartNotification", true),
            ("_NSTextInputContextDictationDidEndNotification", false),
        ] {
            observers.append(NotificationCenter.default.addObserver(
                forName: Notification.Name(name), object: nil, queue: .main
            ) { _ in
                MainActor.assumeIsolated { isActive = active }
            })
        }
    }

    /// Ends dictation if it is running. Deferred one turn so the Return's own
    /// commit lands first.
    static func stop(in context: NSTextInputContext?) {
        guard isActive, let context else { return }
        let stop = NSSelectorFromString("_stopDictation:")
        guard context.responds(to: stop) else { return }
        DispatchQueue.main.async {
            guard isActive else { return }
            logger.info("Return ends dictation")
            _ = context.perform(stop, with: nil)
        }
    }
}
