import AppKit

enum WaveformBadgeStyle {
    case idle
    case active
}

enum WaveformBadgeArtwork {
    static let idleAmplitudeRatio: CGFloat = 0.10
    static let activeAmplitudeRatio: CGFloat = 0.36
    static let idleGlowStrokeWidth: CGFloat = 1.35
    static let activeGlowStrokeWidth: CGFloat = 1.95
    static let idleCoreStrokeWidth: CGFloat = 1.05
    static let activeCoreStrokeWidth: CGFloat = 1.48

    static func drawGlyph(in rect: NSRect, style: WaveformBadgeStyle) {
        let path = NSBezierPath()
        let insetRect = rect.insetBy(dx: rect.width * 0.015, dy: rect.height * 0.05)
        let midY = insetRect.midY
        let amplitude = style == .idle ? insetRect.height * idleAmplitudeRatio : insetRect.height * activeAmplitudeRatio
        let cycles: CGFloat = 2.25
        let steps = 26

        for step in 0...steps {
            let progress = CGFloat(step) / CGFloat(steps)
            let x = insetRect.minX + insetRect.width * progress
            let phase = progress * .pi * 2 * cycles
            let y = midY - sin(phase) * amplitude

            if step == 0 {
                path.move(to: NSPoint(x: x, y: y))
            } else {
                path.line(to: NSPoint(x: x, y: y))
            }
        }

        path.lineWidth = style == .idle ? idleGlowStrokeWidth : activeGlowStrokeWidth
        path.lineCapStyle = .round
        path.lineJoinStyle = .round

        glowColor(for: style).setStroke()
        path.stroke()

        path.lineWidth = style == .idle ? idleCoreStrokeWidth : activeCoreStrokeWidth
        lineColor(for: style).setStroke()
        path.stroke()
    }

    static func lineColor(for style: WaveformBadgeStyle) -> NSColor {
        switch style {
        case .idle:
            return NSColor(calibratedRed: 0.87, green: 0.89, blue: 0.92, alpha: 0.96)
        case .active:
            return NSColor(calibratedRed: 0.16, green: 0.90, blue: 0.80, alpha: 1)
        }
    }

    static func glowColor(for style: WaveformBadgeStyle) -> NSColor {
        switch style {
        case .idle:
            return NSColor(calibratedRed: 0.96, green: 0.97, blue: 0.99, alpha: 0.16)
        case .active:
            return NSColor(calibratedRed: 0.54, green: 0.96, blue: 0.88, alpha: 0.34)
        }
    }
}
