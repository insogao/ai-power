import Testing
@testable import AIPowerCore

@Test
func defaultModeIsAuto() {
    #expect(AppMode.default == .auto)
}
