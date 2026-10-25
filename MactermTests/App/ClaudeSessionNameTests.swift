@testable import Macterm
import Testing

struct ClaudeSessionNameTests {
    @Test
    func strips_the_idle_and_spinner_glyphs() {
        #expect(ClaudeSessionName.strippingStatusGlyph("✳ Akiwatch 7") == "Akiwatch 7")
        #expect(ClaudeSessionName.strippingStatusGlyph("◑ Xログイン時のひらがな入力不具合") == "Xログイン時のひらがな入力不具合")
        #expect(ClaudeSessionName.strippingStatusGlyph("✶ build") == "build")
        #expect(ClaudeSessionName.strippingStatusGlyph("⠂ build") == "build")
    }

    @Test
    func leaves_other_titles_alone() {
        #expect(ClaudeSessionName.strippingStatusGlyph("Claude Code") == "Claude Code")
        #expect(ClaudeSessionName.strippingStatusGlyph("✳") == "✳")
        #expect(ClaudeSessionName.strippingStatusGlyph("✳ ") == "✳ ")
        #expect(ClaudeSessionName.strippingStatusGlyph("*nix tips") == "*nix tips")
        #expect(ClaudeSessionName.strippingStatusGlyph("").isEmpty)
    }

    @Test
    func spinner_frames_are_working_and_the_idle_glyph_is_not() {
        #expect(ClaudeSessionName.isWorkingTitle("⠂ build"))
        #expect(ClaudeSessionName.isWorkingTitle("✶ build"))
        #expect(!ClaudeSessionName.isWorkingTitle("✳ build"))
        #expect(!ClaudeSessionName.isWorkingTitle("Claude Code"))
        #expect(!ClaudeSessionName.isWorkingTitle("*nix tips"))
        #expect(!ClaudeSessionName.isWorkingTitle("⠂"))
        #expect(!ClaudeSessionName.isWorkingTitle(""))
    }

    @Test
    func rename_command_types_the_name_verbatim() {
        #expect(ClaudeSessionName.renameCommand("屋根裏部屋") == "/rename 屋根裏部屋")
    }
}
