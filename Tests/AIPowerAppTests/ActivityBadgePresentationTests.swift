import Testing
@testable import AIPowerApp

struct ActivityBadgePresentationTests {
    @Test
    func collapsesOverflowIntoCountBadge() {
        let badges = [
            ActivityBadge(label: "codex"),
            ActivityBadge(label: "vscode"),
            ActivityBadge(label: "kimi"),
            ActivityBadge(label: "cursor"),
            ActivityBadge(label: "port 18789"),
        ]

        let presentation = ActivityBadgePresentation.make(from: badges, maxVisible: 3)

        #expect(presentation.visibleBadges.map(\.label) == ["codex", "vscode", "kimi"])
        #expect(presentation.overflowCount == 2)
    }

    @Test
    func keepsAllBadgesWhenUnderLimit() {
        let badges = [
            ActivityBadge(label: "codex"),
            ActivityBadge(label: "vscode"),
        ]

        let presentation = ActivityBadgePresentation.make(from: badges, maxVisible: 3)

        #expect(presentation.visibleBadges.map(\.label) == ["codex", "vscode"])
        #expect(presentation.overflowCount == 0)
    }
}
