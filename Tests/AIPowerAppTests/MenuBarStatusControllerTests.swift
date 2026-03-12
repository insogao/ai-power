import AppKit
import Testing
@testable import AIPowerApp

struct MenuBarStatusControllerTests {
    @Test
    func toggleMaskSupportsLeftAndRightClicks() {
        #expect(MenuBarActivationBehavior.togglePopoverMask.contains(.leftMouseUp))
        #expect(MenuBarActivationBehavior.togglePopoverMask.contains(.rightMouseUp))
    }
}
