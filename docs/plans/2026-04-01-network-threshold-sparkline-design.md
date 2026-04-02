# Network Threshold Sparkline Design

## Goal

Make the AI network threshold chart easier to read by:

- showing the built-in threshold presets as visible guide ticks
- replacing raw linear scaling with logarithmic scaling
- replacing raw peak labels with rounded exponential scale labels

## Decisions

1. Keep the existing "last hour monitored traffic" sparkline.
2. Add guide lines for the default threshold presets: `10 / 30 / 50 / 80 / 100 KB`.
3. Scale the chart using a logarithmic transform so small values are still distinguishable when the hour contains a large spike.
4. Round the chart ceiling to a stable exponential bucket such as `100 KB`, `300 KB`, `1 MB`, `3 MB`, `10 MB`, instead of exposing an arbitrary raw peak like `8 MB`.
5. Keep the implementation lightweight and local to the menu bar UI.

## Testing

- Add a presentation-model test to verify the threshold guides are always visible.
- Add a presentation-model test to verify a large spike rounds to a stable logarithmic ceiling bucket instead of the raw peak.
