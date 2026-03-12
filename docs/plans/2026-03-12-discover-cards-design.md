# Discover Cards Design

## Goal

Add a lightweight `Discover` section inside the menu bar panel so AI Power can show outbound links such as the author's GitHub page and future promotional cards without interrupting the core wake-control workflow.

## Product Behavior

- `Discover` is a separate expandable section in the menu.
- Content is driven by a remote `cards.json`.
- `cards.json` controls:
  - whether `Discover` is enabled
  - whether it should be expanded by default
  - the list of cards to render
- If remote loading fails, the app falls back to bundled demo cards and keeps the section collapsed by default.
- First version supports text + hyperlink cards and manual switching between multiple cards.
- Automatic carousel behavior is explicitly deferred; the data model should still support multiple cards now.

## UX Rules

- `Discover` stays out of the primary wake controls flow.
- Default placement: below `Monitors`, above `Debug`.
- Cards show:
  - title
  - subtitle
  - CTA text
  - destination link
- If there is more than one card, show a simple `Previous / Next` navigation or a compact index indicator.
- If the feed is disabled or yields no valid cards, hide the whole section.

## Data Model

```json
{
  "enabled": true,
  "default_expanded": false,
  "cards": [
    {
      "id": "github",
      "kind": "github",
      "title": "Explore More Projects",
      "subtitle": "See more AI and developer tools on GitHub.",
      "cta_text": "Open GitHub",
      "url": "https://github.com/gaoshizai"
    }
  ]
}
```

## Architecture

- Add a small `DiscoverFeedLoader` in the app layer.
- The loader fetches remote JSON and decodes it into a feed model.
- `AppModel` owns discover state:
  - cards
  - visibility
  - default-expanded suggestion
- `MenuBarView` renders the section and handles local disclosure / card paging UI state.

## Failure Handling

- Remote fetch failure:
  - use local fallback cards
  - force collapsed default state
- Invalid card URLs:
  - skip invalid cards
- Empty valid card set:
  - hide `Discover`

## Demo Content

The repository should include a publishable `Config/Discover/cards.json` containing:

- a GitHub card pointing to `https://github.com/gaoshizai`
- a demo AI community card pointing to a well-known public destination such as `https://huggingface.co`

## Out of Scope

- ad network integration
- impressions / click analytics
- automatic rotation timer
- remote image loading
- full website / CMS
