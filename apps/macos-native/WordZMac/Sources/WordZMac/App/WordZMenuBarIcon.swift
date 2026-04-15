import AppKit

enum WordZMenuBarIcon {
    @MainActor private static var cachedImages: [WordZMenuBarIconState: NSImage] = [:]

    @MainActor
    static func image(state: WordZMenuBarIconState = .idle) -> NSImage {
        if let cachedImage = cachedImages[state] {
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

            switch state {
            case .idle:
                NSBezierPath(ovalIn: NSRect(x: bounds.maxX - 5.2, y: middleY - 1, width: 4.2, height: 4.2)).fill()
            case .tasksRunning:
                NSBezierPath(ovalIn: NSRect(x: bounds.maxX - 5.8, y: bounds.maxY - 5.6, width: 4.8, height: 4.8)).fill()
            case .updateReady:
                let badgeRect = NSRect(x: bounds.maxX - 6.2, y: bounds.maxY - 6.4, width: 5.4, height: 5.4)
                NSBezierPath(roundedRect: badgeRect, xRadius: 1.8, yRadius: 1.8).fill()
            }
            return true
        }
        image.isTemplate = true
        cachedImages[state] = image
        return image
    }
}
