import AppKit
import SwiftUI

enum WarningOrbitArtwork {
    static let primaryColor = NSColor(calibratedRed: 0.95, green: 0.42, blue: 0.10, alpha: 1)
    static let secondaryColor = NSColor(calibratedRed: 1.0, green: 0.67, blue: 0.22, alpha: 0.95)
    static let centerColor = NSColor(calibratedRed: 0.83, green: 0.29, blue: 0.07, alpha: 1)

    static func makeImage(size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        drawGlyph(in: NSRect(origin: .zero, size: size))
        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    static func drawGlyph(
        in rect: NSRect,
        primary: NSColor = primaryColor,
        secondary: NSColor = secondaryColor,
        center: NSColor = centerColor
    ) {
        let orbitRect = rect.insetBy(dx: rect.width * 0.06, dy: rect.height * 0.08)
        let centerPoint = CGPoint(x: orbitRect.midX, y: orbitRect.midY)
        let majorOrbit = NSRect(
            x: centerPoint.x - orbitRect.width * 0.44,
            y: centerPoint.y - orbitRect.height * 0.16,
            width: orbitRect.width * 0.88,
            height: orbitRect.height * 0.32
        )
        let lineWidth = max(1.25, min(rect.width, rect.height) * 0.12)

        drawOrbit(
            ovalIn: majorOrbit,
            angle: 43,
            centerPoint: centerPoint,
            lineWidth: lineWidth,
            color: primary
        )
        drawOrbit(
            ovalIn: majorOrbit,
            angle: -43,
            centerPoint: centerPoint,
            lineWidth: lineWidth,
            color: secondary
        )

        let centerDot = NSBezierPath(ovalIn: NSRect(
            x: centerPoint.x - lineWidth * 0.58,
            y: centerPoint.y - lineWidth * 0.58,
            width: lineWidth * 1.16,
            height: lineWidth * 1.16
        ))
        center.setFill()
        centerDot.fill()
    }

    private static func drawOrbit(
        ovalIn rect: NSRect,
        angle: CGFloat,
        centerPoint: CGPoint,
        lineWidth: CGFloat,
        color: NSColor
    ) {
        let orbit = NSBezierPath(ovalIn: rect)
        var transform = AffineTransform()
        transform.translate(x: centerPoint.x, y: centerPoint.y)
        transform.rotate(byDegrees: angle)
        transform.translate(x: -centerPoint.x, y: -centerPoint.y)
        orbit.transform(using: transform)
        orbit.lineWidth = lineWidth
        orbit.lineCapStyle = .round
        orbit.lineJoinStyle = .round
        color.setStroke()
        orbit.stroke()
    }
}

struct WarningOrbitIcon: View {
    var size: CGFloat = 14

    var body: some View {
        Image(nsImage: WarningOrbitArtwork.makeImage(size: NSSize(width: size, height: size)))
            .interpolation(.high)
            .antialiased(true)
            .frame(width: size, height: size)
    }
}
