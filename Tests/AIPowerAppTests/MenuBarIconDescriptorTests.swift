import AppKit
import Testing
@testable import AIPowerApp

@MainActor
struct MenuBarIconDescriptorTests {
    @Test
    func idleStateUsesWaveformBadge() {
        let descriptor = MenuBarIconDescriptor.descriptor(for: .idle)

        #expect(descriptor.glyph == .waveformIdle)
        #expect(descriptor.badgeStyle == .standard)
    }

    @Test
    func activeStateUsesWaveformBadge() {
        let descriptor = MenuBarIconDescriptor.descriptor(for: .active)

        #expect(descriptor.glyph == .waveformActive)
        #expect(descriptor.badgeStyle == .standard)
    }

    @Test
    func warningStateUsesOrbitXIcon() {
        let descriptor = MenuBarIconDescriptor.descriptor(for: .warning)

        #expect(descriptor.glyph == .orbitX)
        #expect(descriptor.badgeStyle == .standard)
    }

    @Test
    func waveformBadgeUsesLargerFootprint() {
        #expect(MenuBarIconDescriptor.badgeRect.width >= 17.2)
        #expect(MenuBarIconDescriptor.badgeRect.height >= 17.2)

        let idleGlyphRect = MenuBarIconDescriptor.waveformGlyphRect(for: .waveformIdle)
        let activeGlyphRect = MenuBarIconDescriptor.waveformGlyphRect(for: .waveformActive)
        let warningGlyphRect = MenuBarIconDescriptor.waveformGlyphRect(for: .orbitX)

        #expect(idleGlyphRect.width >= 13.0)
        #expect(idleGlyphRect.height >= 10.6)
        #expect(activeGlyphRect.width >= 13.2)
        #expect(activeGlyphRect.height >= 10.9)
        #expect(warningGlyphRect.width >= 12.8)
        #expect(warningGlyphRect.height >= 12.8)
    }

    @Test
    func idleWaveformUsesQuietGrayPalette() {
        #expect(WaveformBadgeArtwork.idleAmplitudeRatio <= 0.11)
        #expect(WaveformBadgeArtwork.idleCoreStrokeWidth <= 1.2)

        let idleLine = WaveformBadgeArtwork.lineColor(for: .idle).usingColorSpace(.deviceRGB)
        #expect(idleLine != nil)
        if let idleLine {
            #expect(idleLine.redComponent >= 0.82)
            #expect(idleLine.greenComponent >= 0.84)
            #expect(idleLine.blueComponent >= 0.86)
            #expect(abs(idleLine.redComponent - idleLine.blueComponent) <= 0.08)
        }
    }
}
