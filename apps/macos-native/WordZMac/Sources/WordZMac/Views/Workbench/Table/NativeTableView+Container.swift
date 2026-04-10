import AppKit

extension NativeTableView {
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

            emptyLabel.alignment = .center
            emptyLabel.font = .systemFont(ofSize: 13)
            emptyLabel.textColor = .secondaryLabelColor
            emptyLabel.maximumNumberOfLines = 0
            emptyLabel.lineBreakMode = .byWordWrapping
            emptyLabel.translatesAutoresizingMaskIntoConstraints = false
            addSubview(emptyLabel)

            NSLayoutConstraint.activate([
                scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
                scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
                scrollView.topAnchor.constraint(equalTo: topAnchor),
                scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

                emptyLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
                emptyLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
                emptyLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 24),
                emptyLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -24)
            ])
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func updateEmptyState(message: String, isEmpty: Bool) {
            emptyLabel.stringValue = message
            emptyLabel.isHidden = !isEmpty
            scrollView.isHidden = isEmpty
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
}
