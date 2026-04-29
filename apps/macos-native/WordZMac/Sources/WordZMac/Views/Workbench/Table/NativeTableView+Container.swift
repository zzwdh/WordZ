import AppKit

extension NativeTableView {
    enum MarkerNavigationDirection {
        case previous
        case next
    }

    final class ActionTableView: NSTableView {
        weak var actionCoordinator: Coordinator?

        override func keyDown(with event: NSEvent) {
            if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
               event.charactersIgnoringModifiers?.lowercased() == "c",
               actionCoordinator?.copySelectedRowsToPasteboard() == true {
                return
            }
            if [36, 49, 76].contains(event.keyCode),
               actionCoordinator?.activateSelectedRow() == true {
                return
            }
            if event.modifierFlags.intersection([.command, .option, .control]).isEmpty,
               event.keyCode == 123,
               actionCoordinator?.selectAdjacentMarker(direction: .previous) == true {
                return
            }
            if event.modifierFlags.intersection([.command, .option, .control]).isEmpty,
               event.keyCode == 124,
               actionCoordinator?.selectAdjacentMarker(direction: .next) == true {
                return
            }
            super.keyDown(with: event)
        }

        override func menu(for event: NSEvent) -> NSMenu? {
            let point = convert(event.locationInWindow, from: nil)
            let clickedRow = row(at: point)
            if clickedRow >= 0, !selectedRowIndexes.contains(clickedRow) {
                selectRowIndexes(IndexSet(integer: clickedRow), byExtendingSelection: false)
            }
            return super.menu(for: event)
        }
    }

    final class IntrinsicTableContainerView: NSView {
        let scrollView = IntrinsicTableScrollView(frame: .zero)
        private let emptyContainer = NSView(frame: .zero)
        private let emptyLabel = NSTextField(labelWithString: "")

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)

            scrollView.hasVerticalScroller = true
            scrollView.hasHorizontalScroller = true
            scrollView.autohidesScrollers = true
            scrollView.borderType = .noBorder
            scrollView.drawsBackground = false
            scrollView.translatesAutoresizingMaskIntoConstraints = false
            addSubview(scrollView)

            emptyContainer.wantsLayer = true
            emptyContainer.translatesAutoresizingMaskIntoConstraints = false
            addSubview(emptyContainer)

            emptyLabel.alignment = .center
            emptyLabel.font = .systemFont(ofSize: 13)
            emptyLabel.textColor = .secondaryLabelColor
            emptyLabel.maximumNumberOfLines = 0
            emptyLabel.lineBreakMode = .byWordWrapping
            emptyLabel.translatesAutoresizingMaskIntoConstraints = false
            emptyContainer.addSubview(emptyLabel)
            updateEmptyContainerAppearance()

            NSLayoutConstraint.activate([
                scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
                scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
                scrollView.topAnchor.constraint(equalTo: topAnchor),
                scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

                emptyContainer.centerXAnchor.constraint(equalTo: centerXAnchor),
                emptyContainer.centerYAnchor.constraint(equalTo: centerYAnchor),
                emptyContainer.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 24),
                emptyContainer.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -24),

                emptyLabel.leadingAnchor.constraint(equalTo: emptyContainer.leadingAnchor, constant: 18),
                emptyLabel.trailingAnchor.constraint(equalTo: emptyContainer.trailingAnchor, constant: -18),
                emptyLabel.topAnchor.constraint(equalTo: emptyContainer.topAnchor, constant: 14),
                emptyLabel.bottomAnchor.constraint(equalTo: emptyContainer.bottomAnchor, constant: -14)
            ])
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func updateEmptyState(message: String, isEmpty: Bool) {
            emptyLabel.stringValue = message
            emptyContainer.isHidden = !isEmpty
            scrollView.isHidden = isEmpty
        }

        override func viewDidChangeEffectiveAppearance() {
            super.viewDidChangeEffectiveAppearance()
            updateEmptyContainerAppearance()
        }

        private func updateEmptyContainerAppearance() {
            emptyContainer.layer?.cornerRadius = 8
            emptyContainer.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.68).cgColor
            emptyContainer.layer?.borderWidth = 1
            emptyContainer.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.45).cgColor
        }

        override var intrinsicContentSize: NSSize {
            NSSize(width: NSView.noIntrinsicMetric, height: 360)
        }
    }

    final class IntrinsicTableScrollView: NSScrollView {
        override var intrinsicContentSize: NSSize {
            NSSize(width: NSView.noIntrinsicMetric, height: 360)
        }
    }

    final class MarkerStripCellView: NSView {
        var markers: [NativeTableMarkerValue] = []
        var selectedMarkerID: String?
        var isSelectedRow = false
        var onSelectMarker: ((String?, Bool) -> Void)?
        var onNavigateMarker: ((MarkerNavigationDirection) -> Bool)?
        var onActivateMarker: (() -> Bool)?

        override var isFlipped: Bool { true }
        override var acceptsFirstResponder: Bool { true }

        override func isAccessibilityElement() -> Bool {
            true
        }

        override func accessibilityRole() -> NSAccessibility.Role? {
            .group
        }

        override func accessibilityValue() -> Any? {
            if let selectedMarkerID,
               let marker = markers.first(where: { $0.id == selectedMarkerID }) {
                return marker.accessibilityLabel
            }
            guard !markers.isEmpty else { return wordZText("无命中", "No hits", mode: .system) }
            return wordZText("\(markers.count) 个命中", "\(markers.count) hits", mode: .system)
        }

        override func accessibilityHelp() -> String? {
            wordZText(
                "使用左右方向键选择上一个或下一个命中，按 Return 打开当前命中。",
                "Use the left and right arrow keys to select the previous or next hit, then press Return to open the current hit.",
                mode: .system
            )
        }

        override func accessibilityCustomActions() -> [NSAccessibilityCustomAction]? {
            guard !markers.isEmpty else { return nil }
            let navigationActions = [
                NSAccessibilityCustomAction(
                    name: wordZText("选择上一个命中", "Select previous hit", mode: .system),
                    target: self,
                    selector: #selector(accessibilitySelectPreviousMarker(_:))
                ),
                NSAccessibilityCustomAction(
                    name: wordZText("选择下一个命中", "Select next hit", mode: .system),
                    target: self,
                    selector: #selector(accessibilitySelectNextMarker(_:))
                ),
                NSAccessibilityCustomAction(
                    name: wordZText("打开当前命中", "Open selected hit", mode: .system),
                    target: self,
                    selector: #selector(accessibilityActivateMarker(_:))
                )
            ]
            let markerActions = markers.map { marker in
                NSAccessibilityCustomAction(
                    name: wordZText(
                        "选择命中：\(marker.accessibilityLabel)",
                        "Select hit: \(marker.accessibilityLabel)",
                        mode: .system
                    ),
                    target: accessibilityElement(for: marker),
                    selector: #selector(MarkerAccessibilityElement.accessibilitySelectMarker(_:))
                )
            }
            return navigationActions + markerActions
        }

        override func accessibilityChildren() -> [Any]? {
            guard !markers.isEmpty else { return nil }
            return markers.map { marker in
                accessibilityElement(for: marker)
            }
        }

        private func accessibilityElement(for marker: NativeTableMarkerValue) -> MarkerAccessibilityElement {
            MarkerAccessibilityElement(
                parentView: self,
                marker: marker,
                isSelected: marker.id == selectedMarkerID,
                frameInScreen: accessibilityFrame(for: marker),
                selectMarker: { [weak self] in
                    guard let self else { return false }
                    self.window?.makeFirstResponder(self)
                    self.onSelectMarker?(marker.id, false)
                    return true
                }
            )
        }

        override func draw(_ dirtyRect: NSRect) {
            super.draw(dirtyRect)

            let borderRect = bounds.insetBy(dx: 4, dy: 4)
            let borderPath = NSBezierPath(roundedRect: borderRect, xRadius: 4, yRadius: 4)
            NSColor.controlAccentColor.withAlphaComponent(isSelectedRow ? 0.10 : 0.04).setFill()
            borderPath.fill()
            NSColor.separatorColor.withAlphaComponent(isSelectedRow ? 0.55 : 0.28).setStroke()
            borderPath.lineWidth = 1
            borderPath.stroke()

            guard !markers.isEmpty else { return }

            let usableWidth = max(borderRect.width - 2, 1)
            let minY = borderRect.minY + 2
            let maxY = borderRect.maxY - 2
            let baseColor = NSColor.controlAccentColor.withAlphaComponent(isSelectedRow ? 0.9 : 0.62)
            let selectedColor = NSColor.controlAccentColor

            for marker in markers {
                let x = borderRect.minX + CGFloat(marker.normalizedPosition) * usableWidth
                if marker.id == selectedMarkerID {
                    let markerRect = NSRect(x: x - 2, y: minY - 1, width: 4, height: maxY - minY + 2)
                    NSColor.controlAccentColor.withAlphaComponent(0.18).setFill()
                    NSBezierPath(roundedRect: markerRect, xRadius: 2, yRadius: 2).fill()
                }

                let path = NSBezierPath()
                path.move(to: NSPoint(x: x, y: minY))
                path.line(to: NSPoint(x: x, y: maxY))
                path.lineWidth = marker.id == selectedMarkerID ? 2 : 1
                (marker.id == selectedMarkerID ? selectedColor : baseColor).setStroke()
                path.stroke()
            }
        }

        override func mouseDown(with event: NSEvent) {
            window?.makeFirstResponder(self)
            let shouldActivate = event.clickCount > 1
            guard !markers.isEmpty else {
                onSelectMarker?(nil, shouldActivate)
                return
            }
            let localPoint = convert(event.locationInWindow, from: nil)
            let markerID = nearestMarker(to: localPoint.x)?.id
            onSelectMarker?(markerID, shouldActivate)
        }

        override func keyDown(with event: NSEvent) {
            if event.modifierFlags.intersection([.command, .option, .control]).isEmpty,
               event.keyCode == 123,
               onNavigateMarker?(.previous) == true {
                return
            }
            if event.modifierFlags.intersection([.command, .option, .control]).isEmpty,
               event.keyCode == 124,
               onNavigateMarker?(.next) == true {
                return
            }
            if [36, 49, 76].contains(event.keyCode),
               onActivateMarker?() == true {
                return
            }
            super.keyDown(with: event)
        }

        private func nearestMarker(to x: CGFloat) -> NativeTableMarkerValue? {
            let borderRect = bounds.insetBy(dx: 4, dy: 4)
            let usableWidth = max(borderRect.width - 2, 1)
            return markers.min { lhs, rhs in
                let lhsX = borderRect.minX + CGFloat(lhs.normalizedPosition) * usableWidth
                let rhsX = borderRect.minX + CGFloat(rhs.normalizedPosition) * usableWidth
                return abs(lhsX - x) < abs(rhsX - x)
            }
        }

        private func markerRect(for marker: NativeTableMarkerValue) -> NSRect {
            let borderRect = bounds.insetBy(dx: 4, dy: 4)
            let usableWidth = max(borderRect.width - 2, 1)
            let x = borderRect.minX + CGFloat(marker.normalizedPosition) * usableWidth
            return NSRect(
                x: x - 5,
                y: borderRect.minY,
                width: 10,
                height: borderRect.height
            )
        }

        fileprivate func accessibilityFrame(for marker: NativeTableMarkerValue) -> NSRect {
            let markerRect = markerRect(for: marker)
            let windowRect = convert(markerRect, to: nil)
            return window?.convertToScreen(windowRect) ?? windowRect
        }

        @objc
        private func accessibilitySelectPreviousMarker(_ action: NSAccessibilityCustomAction) -> Bool {
            onNavigateMarker?(.previous) ?? false
        }

        @objc
        private func accessibilitySelectNextMarker(_ action: NSAccessibilityCustomAction) -> Bool {
            onNavigateMarker?(.next) ?? false
        }

        @objc
        private func accessibilityActivateMarker(_ action: NSAccessibilityCustomAction) -> Bool {
            onActivateMarker?() ?? false
        }
    }

    final class MarkerAccessibilityElement: NSAccessibilityElement {
        private weak var parentView: MarkerStripCellView?
        private let marker: NativeTableMarkerValue
        private let isSelected: Bool
        private let frameInScreen: NSRect
        private let selectMarker: () -> Bool

        init(
            parentView: MarkerStripCellView,
            marker: NativeTableMarkerValue,
            isSelected: Bool,
            frameInScreen: NSRect,
            selectMarker: @escaping () -> Bool
        ) {
            self.parentView = parentView
            self.marker = marker
            self.isSelected = isSelected
            self.frameInScreen = frameInScreen
            self.selectMarker = selectMarker
            super.init()
        }

        override func isAccessibilityElement() -> Bool {
            true
        }

        override func accessibilityRole() -> NSAccessibility.Role? {
            .button
        }

        override func accessibilityLabel() -> String? {
            marker.accessibilityLabel
        }

        override func accessibilityValue() -> Any? {
            isSelected ? wordZText("已选择", "Selected", mode: .system) : nil
        }

        override func accessibilityHelp() -> String? {
            wordZText(
                "选择此命中。选择后可按 Return 打开当前命中。",
                "Select this hit. After selecting it, press Return to open the current hit.",
                mode: .system
            )
        }

        override func accessibilityParent() -> Any? {
            parentView
        }

        override func accessibilityFrame() -> NSRect {
            frameInScreen
        }

        override func accessibilityPerformPress() -> Bool {
            selectMarker()
        }

        @objc
        func accessibilitySelectMarker(_ action: NSAccessibilityCustomAction?) -> Bool {
            selectMarker()
        }
    }
}
