import AppKit

enum WordZMenuBarIcon {
    @MainActor private static var cachedImage: NSImage?

    @MainActor
    static func image() -> NSImage {
        if let cachedImage {
            return cachedImage
        }

        let image = NSImage(size: NSSize(width: 18, height: 14), flipped: false) { bounds in
            NSColor.labelColor.setFill()

            let lineHeight: CGFloat = 2.2
            let radius = lineHeight / 2
            let topY = bounds.maxY - 3.4
            let middleY = bounds.midY + 0.2
            let bottomY = bounds.minY + 1.8

            NSBezierPath(
                roundedRect: NSRect(x: bounds.minX + 1, y: topY, width: 9.5, height: lineHeight),
                xRadius: radius,
                yRadius: radius
            ).fill()
            NSBezierPath(
                roundedRect: NSRect(x: bounds.minX + 1, y: middleY, width: 12.5, height: lineHeight),
                xRadius: radius,
                yRadius: radius
            ).fill()
            NSBezierPath(
                roundedRect: NSRect(x: bounds.minX + 1, y: bottomY, width: 8, height: lineHeight),
                xRadius: radius,
                yRadius: radius
            ).fill()

            NSBezierPath(ovalIn: NSRect(x: bounds.maxX - 5.2, y: middleY - 1, width: 4.2, height: 4.2)).fill()
            return true
        }
        image.isTemplate = true
        cachedImage = image
        return image
    }
}
