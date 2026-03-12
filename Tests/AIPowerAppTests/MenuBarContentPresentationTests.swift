import Testing
@testable import AIPowerApp

struct MenuBarContentPresentationTests {
    @Test
    func draggingKeepsContentPresentationOnCommittedSelection() {
        let contentSelection = MenuBarSelectionPresentation.contentSelection(
            committedSelection: .aiMode,
            previewSelection: .timed(duration: 8 * 60 * 60),
            isDragging: true
        )

        #expect(contentSelection == .aiMode)
    }

    @Test
    func offSelectionShowsInstructionInsteadOfMonitoringSummary() {
        let presentation = MenuBarContentPresentation.make(
            selection: .off,
            activityBadges: [],
            builtInSummaryText: "Monitoring 24 built-in AI tools"
        )

        #expect(presentation.primaryText == "Move the control to AI Mode or a time slot to start keeping your Mac awake.")
        #expect(presentation.showsBuiltInSummary == false)
        #expect(presentation.showsActivityBadges == false)
    }

    @Test
    func activeSelectionPrefersBadgesOverMonitoringSummary() {
        let presentation = MenuBarContentPresentation.make(
            selection: .aiMode,
            activityBadges: [
                ActivityBadge(label: "codex"),
                ActivityBadge(label: "vscode"),
            ],
            builtInSummaryText: "Monitoring 24 built-in AI tools"
        )

        #expect(presentation.primaryText == nil)
        #expect(presentation.showsBuiltInSummary == false)
        #expect(presentation.showsActivityBadges == true)
    }

    @Test
    func idleSelectionShowsMonitoringSummaryWhenNoBadgesExist() {
        let presentation = MenuBarContentPresentation.make(
            selection: .aiMode,
            activityBadges: [],
            builtInSummaryText: "Monitoring 24 built-in AI tools"
        )

        #expect(presentation.primaryText == nil)
        #expect(presentation.showsBuiltInSummary == true)
        #expect(presentation.showsActivityBadges == false)
    }

    @Test
    func timedSelectionDoesNotShowMonitoringSummaryOrBadges() {
        let presentation = MenuBarContentPresentation.make(
            selection: .timed(duration: 8 * 60 * 60),
            activityBadges: [
                ActivityBadge(label: "codex"),
            ],
            builtInSummaryText: "Monitoring 24 built-in AI tools"
        )

        #expect(presentation.primaryText == nil)
        #expect(presentation.showsBuiltInSummary == false)
        #expect(presentation.showsActivityBadges == false)
    }
}
