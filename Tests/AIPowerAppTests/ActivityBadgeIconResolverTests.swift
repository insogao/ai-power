import Testing
@testable import AIPowerApp

struct ActivityBadgeIconResolverTests {
    @Test
    func codexMapsToBundledAppIdentifier() {
        #expect(ActivityBadgeIconResolver.bundleIdentifiers(for: "codex") == ["com.openai.codex"])
    }
}
