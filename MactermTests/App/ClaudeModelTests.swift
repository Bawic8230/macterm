@testable import Macterm
import Testing

struct ClaudeModelTests {
    @Test
    func every_choice_types_a_model_command_with_a_unique_id() {
        let ids = ClaudeModelChoice.all.map(\.id)
        #expect(Set(ids).count == ids.count)
        for model in ClaudeModelChoice.all {
            #expect(model.command == "/model \(model.id)")
            #expect(model.id.hasPrefix("claude-"))
            #expect(!model.id.contains(" "))
        }
    }

    @Test
    func older_opus_versions_are_offered() {
        let ids = Set(ClaudeModelChoice.all.map(\.id))
        for id in ["claude-opus-5", "claude-opus-4-8", "claude-opus-4-7", "claude-opus-4-6"] {
            #expect(ids.contains(id))
        }
    }
}
