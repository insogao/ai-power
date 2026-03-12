import Testing
@testable import AIPowerApp

struct DiscoverCarouselTests {
    @Test
    func autoRotationRequiresExpandedSectionAndMultipleCards() {
        #expect(DiscoverCarouselBehavior.shouldAutoRotate(isExpanded: false, cardCount: 2) == false)
        #expect(DiscoverCarouselBehavior.shouldAutoRotate(isExpanded: true, cardCount: 1) == false)
        #expect(DiscoverCarouselBehavior.shouldAutoRotate(isExpanded: true, cardCount: 2) == true)
    }

    @Test
    func nextIndexLoopsBackToStart() {
        #expect(DiscoverCarouselBehavior.nextIndex(currentIndex: 0, cardCount: 3) == 1)
        #expect(DiscoverCarouselBehavior.nextIndex(currentIndex: 2, cardCount: 3) == 0)
        #expect(DiscoverCarouselBehavior.nextIndex(currentIndex: 0, cardCount: 1) == 0)
    }
}
