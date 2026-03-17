import AppKit
import Testing
@testable import AIPowerApp

@MainActor
struct MenuBarIconDescriptorTests {
    @Test
    func offStateUsesQuietWaveformBadge() {
        let descriptor = MenuBarIconDescriptor.descriptor(for: .off)

        #expect(descriptor.glyph == .waveformIdle)
        #expect(descriptor.badgeStyle == .standard)
    }

    @Test
    func armedStateUsesActiveWaveformBadge() {
        let descriptor = MenuBarIconDescriptor.descriptor(for: .armed)

        #expect(descriptor.glyph == .waveformActive)
        #expect(descriptor.badgeStyle == .standard)
    }

    @Test
    func infinityStateUsesInfinityGlyph() {
        let descriptor = MenuBarIconDescriptor.descriptor(for: .infinity)

        #expect(descriptor.glyph == .infinity)
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

        let offGlyphRect = MenuBarIconDescriptor.waveformGlyphRect(for: .waveformIdle)
        let armedGlyphRect = MenuBarIconDescriptor.waveformGlyphRect(for: .waveformActive)
        let infinityGlyphRect = MenuBarIconDescriptor.waveformGlyphRect(for: .infinity)
        let warningGlyphRect = MenuBarIconDescriptor.waveformGlyphRect(for: .orbitX)

        #expect(offGlyphRect.width >= 13.0)
        #expect(offGlyphRect.height >= 10.6)
        #expect(armedGlyphRect.width >= 13.2)
        #expect(armedGlyphRect.height >= 10.9)
        #expect(infinityGlyphRect.width >= 11.0)
        #expect(infinityGlyphRect.height >= 11.0)
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
