import Foundation

struct DiscoverCard: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let kind: String?
    let title: String
    let subtitle: String
    let ctaText: String
    let url: String
    let localizations: [String: DiscoverCardLocalization]?

    init(
        id: String,
        kind: String? = nil,
        title: String,
        subtitle: String,
        ctaText: String,
        url: String,
        localizations: [String: DiscoverCardLocalization]? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.ctaText = ctaText
        self.url = url
        self.localizations = localizations
    }

    var destinationURL: URL? {
        URL(string: url)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case kind
        case title
        case subtitle
        case ctaText = "cta_text"
        case url
        case localizations
    }

    func localized(for preferredLanguages: [String]) -> DiscoverCard {
        let normalizedLanguages = preferredLanguages.flatMap { language in
            let base = language.split(separator: "-").first.map(String.init)
            return base == language ? [language] : [language, base].compactMap { $0 }
        }

        for language in normalizedLanguages {
            if let localization = localizations?[language] {
                return DiscoverCard(
                    id: id,
                    kind: kind,
                    title: localization.title ?? title,
                    subtitle: localization.subtitle ?? subtitle,
                    ctaText: localization.ctaText ?? ctaText,
                    url: url,
                    localizations: localizations
                )
            }
        }

        return self
    }
}

struct DiscoverCardLocalization: Codable, Equatable, Sendable {
    let title: String?
    let subtitle: String?
    let ctaText: String?

    enum CodingKeys: String, CodingKey {
        case title
        case subtitle
        case ctaText = "cta_text"
    }
}

struct DiscoverFeed: Codable, Equatable, Sendable {
    let enabled: Bool
    let defaultExpanded: Bool
    let cards: [DiscoverCard]

    enum CodingKeys: String, CodingKey {
        case enabled
        case defaultExpanded = "default_expanded"
        case cards
    }

    static let demo = DiscoverFeed(
        enabled: true,
        defaultExpanded: false,
        cards: [
            DiscoverCard(
                id: "github",
                kind: "github",
                title: "Explore More Projects",
                subtitle: "See more AI and developer tools on GitHub.",
                ctaText: "Open GitHub",
                url: "https://github.com/insogao",
                localizations: [
                    "zh-Hans": DiscoverCardLocalization(
                        title: "查看更多项目",
                        subtitle: "在 GitHub 上查看更多 AI 和开发效率工具。",
                        ctaText: "打开 GitHub"
                    )
                ]
            ),
            DiscoverCard(
                id: "community",
                kind: "community",
                title: "Discover AI Builders",
                subtitle: "Browse a leading AI community and model ecosystem.",
                ctaText: "Open Hugging Face",
                url: "https://huggingface.co",
                localizations: [
                    "zh-Hans": DiscoverCardLocalization(
                        title: "发现 AI 社区",
                        subtitle: "浏览一个领先的 AI 社区与模型生态。",
                        ctaText: "打开 Hugging Face"
                    )
                ]
            )
        ]
    )
}

enum DiscoverFeedSource: Equatable, Sendable {
    case remote
    case fallback
}

struct DiscoverFeedLoadResult: Equatable, Sendable {
    let feed: DiscoverFeed
    let source: DiscoverFeedSource
}

enum DiscoverFeedDecoder {
    static func decode(_ data: Data) throws -> DiscoverFeed {
        try JSONDecoder().decode(DiscoverFeed.self, from: data)
    }
}

protocol DiscoverFeedLoading: Sendable {
    func load() async -> DiscoverFeedLoadResult
}

struct DiscoverFeedLoader: DiscoverFeedLoading {
    let remoteURLProvider: @Sendable () -> URL
    let fetcher: @Sendable (URL) async throws -> Data
    let fallbackFeed: DiscoverFeed

    init(
        remoteURLProvider: @escaping @Sendable () -> URL = { DiscoverFeedConfiguration.remoteURL },
        fetcher: @escaping @Sendable (URL) async throws -> Data = { url in
            let (data, _) = try await URLSession.shared.data(from: url)
            return data
        },
        fallbackFeed: DiscoverFeed = .demo
    ) {
        self.remoteURLProvider = remoteURLProvider
        self.fetcher = fetcher
        self.fallbackFeed = fallbackFeed
    }

    func load() async -> DiscoverFeedLoadResult {
        do {
            let data = try await fetcher(remoteURLProvider())
            let feed = try DiscoverFeedDecoder.decode(data)
            return DiscoverFeedLoadResult(feed: feed, source: .remote)
        } catch {
            return DiscoverFeedLoadResult(feed: fallbackFeed, source: .fallback)
        }
    }
}

enum DiscoverFeedConfiguration {
    static let remoteURL = URL(string: "https://raw.githubusercontent.com/insogao/ai-power-discover/main/cards.json")!
}
