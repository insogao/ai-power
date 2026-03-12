import Foundation
import Testing
@testable import AIPowerApp

struct DiscoverFeedLoaderTests {
    @Test
    func configurationUsesDedicatedDiscoverRepository() {
        let remoteURL = DiscoverFeedConfiguration.remoteURL

        #expect(remoteURL.absoluteString == "https://raw.githubusercontent.com/insogao/ai-power-discover/main/cards.json")
    }

    @Test
    func decodeParsesFeedAndCards() throws {
        let data = """
        {
          "enabled": true,
          "default_expanded": true,
          "cards": [
            {
              "id": "github",
              "kind": "github",
              "title": "Explore More Projects",
              "subtitle": "See more AI tools on GitHub.",
              "cta_text": "Open GitHub",
              "url": "https://github.com/gaoshizai"
            }
          ]
        }
        """.data(using: .utf8)!

        let feed = try DiscoverFeedDecoder.decode(data)

        #expect(feed.enabled == true)
        #expect(feed.defaultExpanded == true)
        #expect(feed.cards.count == 1)
        #expect(feed.cards[0].ctaText == "Open GitHub")
    }

    @Test
    func decodeParsesLocalizedCardContent() throws {
        let data = """
        {
          "enabled": true,
          "default_expanded": false,
          "cards": [
            {
              "id": "github",
              "title": "Explore More Projects",
              "subtitle": "See more AI tools on GitHub.",
              "cta_text": "Open GitHub",
              "url": "https://github.com/insogao",
              "localizations": {
                "zh-Hans": {
                  "title": "查看更多项目",
                  "subtitle": "在 GitHub 上查看更多 AI 工具。",
                  "cta_text": "打开 GitHub"
                }
              }
            }
          ]
        }
        """.data(using: .utf8)!

        let feed = try DiscoverFeedDecoder.decode(data)

        #expect(feed.cards[0].localizations?["zh-Hans"]?.title == "查看更多项目")
        #expect(feed.cards[0].localized(for: ["zh-Hans"]).title == "查看更多项目")
        #expect(feed.cards[0].localized(for: ["en"]).title == "Explore More Projects")
    }

    @Test
    func loaderFallsBackWhenRemotePayloadIsInvalid() async throws {
        let loader = DiscoverFeedLoader(
            remoteURLProvider: { URL(string: "https://example.com/cards.json")! },
            fetcher: { _ in Data("not-json".utf8) },
            fallbackFeed: DiscoverFeed.demo
        )

        let result = await loader.load()

        #expect(result.source == .fallback)
        #expect(result.feed == .demo)
    }
}
