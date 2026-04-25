import AppKit
import SwiftUI

struct LexicalAutocompleteTextField: NSViewRepresentable {
    let title: String
    @Binding var text: String
    let searchOptions: SearchOptionsState
    @ObservedObject var controller: LexicalAutocompleteController
    var maxSuggestions = 8

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField(string: text)
        field.placeholderString = title
        field.delegate = context.coordinator
        field.isBordered = true
        field.isBezeled = true
        field.bezelStyle = .roundedBezel
        field.lineBreakMode = .byTruncatingTail
        field.usesSingleLineMode = true
        field.maximumNumberOfLines = 1
        context.coordinator.attach(field: field)
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.parent = self

        context.coordinator.sync(field: field, text: text, placeholder: title)

        context.coordinator.refreshSuggestions()
    }

    static func dismantleNSView(_ field: NSTextField, coordinator: Coordinator) {
        coordinator.detach(from: field)
    }
}

extension LexicalAutocompleteTextField {
    @MainActor
    final class Coordinator: NSObject, NSTextFieldDelegate, NSTableViewDataSource, NSTableViewDelegate, NSPopoverDelegate {
        var parent: LexicalAutocompleteTextField
        var isApplyingTextUpdate = false

        private weak var field: NSTextField?
        private let popover = NSPopover()
        private let tableView = NSTableView(frame: .zero)
        private let scrollView = NSScrollView(frame: .zero)
        private var suggestions: [LexicalAutocompleteSuggestion] = []
        private var interactionState = LexicalAutocompleteInteractionState()

        init(parent: LexicalAutocompleteTextField) {
            self.parent = parent
            super.init()
            configurePopover()
            configureTableView()
        }

        func attach(field: NSTextField) {
            self.field = field
        }

        func detach(from field: NSTextField) {
            if self.field === field {
                dismissSuggestions()
                field.delegate = nil
                self.field = nil
            }
        }

        func sync(field: NSTextField, text: String, placeholder: String) {
            field.placeholderString = isEditing(field) ? nil : placeholder

            guard displayedText(in: field) != text else { return }

            isApplyingTextUpdate = true
            if let editor = field.currentEditor() as? NSTextView {
                editor.string = text
                editor.setSelectedRange(insertionRange(atEndOf: text))
            } else {
                field.stringValue = text
            }
            isApplyingTextUpdate = false
        }

        func refreshSuggestions(forcePresentation: Bool = false) {
            let query = parent.text
            let nextSuggestions = parent.controller.suggestions(
                for: query,
                options: parent.searchOptions,
                limit: parent.maxSuggestions
            )
            applySuggestions(nextSuggestions, for: query, forcePresentation: forcePresentation)
        }

        func controlTextDidBeginEditing(_ notification: Notification) {
            if let field = notification.object as? NSTextField {
                field.placeholderString = nil
            }
            refreshSuggestions()
        }

        func controlTextDidChange(_ notification: Notification) {
            guard isApplyingTextUpdate == false else { return }
            guard let field = notification.object as? NSTextField else { return }
            parent.text = displayedText(in: field)
            refreshSuggestions()
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            if let field = notification.object as? NSTextField {
                let finalText = displayedText(in: field)
                field.stringValue = finalText
                field.placeholderString = parent.title
                parent.text = finalText
            }
            dismissSuggestions()
        }

        func control(
            _ control: NSControl,
            textView: NSTextView,
            doCommandBy commandSelector: Selector
        ) -> Bool {
            switch commandSelector {
            case #selector(NSResponder.moveDown(_:)):
                return moveSelection(by: 1, forcePresentation: true)
            case #selector(NSResponder.moveUp(_:)):
                return moveSelection(by: -1, forcePresentation: true)
            case #selector(NSResponder.insertNewline(_:)):
                return acceptHighlightedSuggestion(in: textView)
            case #selector(NSResponder.cancelOperation(_:)):
                guard interactionState.isPresented else { return false }
                dismissSuggestions()
                return true
            case #selector(NSResponder.insertTab(_:)):
                dismissSuggestions()
                return false
            case #selector(NSResponder.deleteBackward(_:)):
                return deleteBackward(in: textView)
            case #selector(NSResponder.deleteForward(_:)):
                return deleteForward(in: textView)
            default:
                return false
            }
        }

        func numberOfRows(in tableView: NSTableView) -> Int {
            suggestions.count
        }

        func tableView(
            _ tableView: NSTableView,
            viewFor tableColumn: NSTableColumn?,
            row: Int
        ) -> NSView? {
            guard suggestions.indices.contains(row) else { return nil }
            let suggestion = suggestions[row]
            let identifier = NSUserInterfaceItemIdentifier(rawValue: tableColumn?.identifier.rawValue ?? "term")

            if let cell = tableView.makeView(withIdentifier: identifier, owner: nil) as? NSTableCellView {
                configure(cell: cell, for: suggestion, columnID: identifier.rawValue)
                return cell
            }

            let cell = NSTableCellView(frame: .zero)
            cell.identifier = identifier
            let label = NSTextField(labelWithString: "")
            label.translatesAutoresizingMaskIntoConstraints = false
            label.lineBreakMode = .byTruncatingTail
            label.maximumNumberOfLines = 1
            cell.addSubview(label)
            cell.textField = label

            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
                label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
                label.topAnchor.constraint(equalTo: cell.topAnchor, constant: 2),
                label.bottomAnchor.constraint(equalTo: cell.bottomAnchor, constant: -2)
            ])

            configure(cell: cell, for: suggestion, columnID: identifier.rawValue)
            return cell
        }

        func tableViewSelectionDidChange(_ notification: Notification) {
            let selectedRow = tableView.selectedRow
            guard selectedRow >= 0 else {
                interactionState.highlightedIndex = nil
                return
            }
            interactionState.highlightedIndex = selectedRow
        }

        @objc
        func handleSuggestionTableAction(_ sender: Any?) {
            let clickedRow = tableView.clickedRow >= 0 ? tableView.clickedRow : tableView.selectedRow
            guard suggestions.indices.contains(clickedRow) else { return }
            accept(suggestions[clickedRow])
        }

        func popoverDidClose(_ notification: Notification) {
            interactionState.dismiss()
            syncTableSelection()
        }

        private func configurePopover() {
            popover.behavior = .transient
            popover.animates = false
            popover.delegate = self

            scrollView.drawsBackground = false
            scrollView.hasVerticalScroller = true
            scrollView.borderType = .noBorder
            scrollView.documentView = tableView

            let contentViewController = NSViewController()
            contentViewController.view = scrollView
            popover.contentViewController = contentViewController
        }

        private func configureTableView() {
            tableView.headerView = nil
            tableView.delegate = self
            tableView.dataSource = self
            tableView.target = self
            tableView.action = #selector(handleSuggestionTableAction(_:))
            tableView.allowsEmptySelection = false
            tableView.allowsMultipleSelection = false
            tableView.focusRingType = .none
            tableView.intercellSpacing = NSSize(width: 4, height: 2)
            tableView.rowHeight = 24
            tableView.selectionHighlightStyle = .regular

            let termColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("term"))
            termColumn.resizingMask = .autoresizingMask
            termColumn.width = 220
            let countColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("count"))
            countColumn.width = 76

            tableView.addTableColumn(termColumn)
            tableView.addTableColumn(countColumn)
        }

        private func configure(
            cell: NSTableCellView,
            for suggestion: LexicalAutocompleteSuggestion,
            columnID: String
        ) {
            guard let label = cell.textField else { return }

            switch columnID {
            case "count":
                label.stringValue = "\(suggestion.count)"
                label.alignment = .right
                label.font = .monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
                label.textColor = .secondaryLabelColor
            default:
                label.stringValue = suggestion.term
                label.alignment = .left
                label.font = .systemFont(ofSize: NSFont.systemFontSize)
                label.textColor = .labelColor
            }
        }

        private func applySuggestions(
            _ nextSuggestions: [LexicalAutocompleteSuggestion],
            for query: String,
            forcePresentation: Bool = false
        ) {
            suggestions = nextSuggestions
            interactionState.updateSuggestions(
                nextSuggestions,
                for: query,
                forcePresentation: forcePresentation
            )
            tableView.reloadData()
            syncTableSelection()

            guard interactionState.isPresented else {
                dismissSuggestions()
                return
            }

            guard isFieldEditing else {
                dismissSuggestions()
                return
            }

            presentSuggestionsIfNeeded()
        }

        private var isFieldEditing: Bool {
            guard let field else { return false }
            return isEditing(field)
        }

        private func isEditing(_ field: NSTextField) -> Bool {
            guard let editor = field.currentEditor() else { return false }
            return field.window?.firstResponder == editor
        }

        private func displayedText(in field: NSTextField) -> String {
            if let editor = field.currentEditor() as? NSTextView {
                return editor.string
            }
            return field.stringValue
        }

        private func moveSelection(by delta: Int, forcePresentation: Bool = false) -> Bool {
            if forcePresentation, interactionState.isPresented == false {
                refreshSuggestions(forcePresentation: true)
            }

            guard interactionState.moveSelection(by: delta, suggestionCount: suggestions.count) else {
                return false
            }

            syncTableSelection()
            presentSuggestionsIfNeeded()
            return true
        }

        private func acceptHighlightedSuggestion(in textView: NSTextView?) -> Bool {
            guard let suggestion = interactionState.acceptHighlightedSuggestion(from: suggestions) else {
                return false
            }

            accept(suggestion, editor: textView)
            return true
        }

        private func accept(_ suggestion: LexicalAutocompleteSuggestion, editor: NSTextView? = nil) {
            isApplyingTextUpdate = true
            if let editor = editor ?? field?.currentEditor() as? NSTextView {
                editor.string = suggestion.term
                editor.setSelectedRange(insertionRange(atEndOf: suggestion.term))
            } else if field?.window == nil {
                field?.stringValue = suggestion.term
            }
            parent.text = suggestion.term
            isApplyingTextUpdate = false
            interactionState.markAcceptedSuggestion(suggestion.term)
            dismissSuggestions()
            focusFieldAtEnd(text: suggestion.term)
        }

        private func deleteBackward(in textView: NSTextView) -> Bool {
            guard deleteText(in: textView, direction: .backward) else {
                dismissSuggestions()
                return true
            }

            applyEditorTextChange(textView, refreshSuggestions: false)
            dismissSuggestions()
            return true
        }

        private func deleteForward(in textView: NSTextView) -> Bool {
            guard deleteText(in: textView, direction: .forward) else {
                dismissSuggestions()
                return true
            }

            applyEditorTextChange(textView, refreshSuggestions: false)
            dismissSuggestions()
            return true
        }

        private func applyEditorTextChange(
            _ textView: NSTextView,
            refreshSuggestions shouldRefreshSuggestions: Bool
        ) {
            guard isApplyingTextUpdate == false else { return }
            parent.text = textView.string
            if shouldRefreshSuggestions {
                refreshSuggestions()
            }
        }

        private enum DeleteDirection {
            case backward
            case forward
        }

        private func deleteText(in textView: NSTextView, direction: DeleteDirection) -> Bool {
            let text = textView.string as NSString
            var selection = textView.selectedRange()

            if selection.length > 0 {
                textView.replaceCharacters(in: selection, with: "")
                textView.setSelectedRange(NSRange(location: selection.location, length: 0))
                return true
            }

            switch direction {
            case .backward:
                guard selection.location > 0 else { return false }
                let deletionRange = text.rangeOfComposedCharacterSequence(at: selection.location - 1)
                textView.replaceCharacters(in: deletionRange, with: "")
                selection.location = deletionRange.location
            case .forward:
                guard selection.location < text.length else { return false }
                let deletionRange = text.rangeOfComposedCharacterSequence(at: selection.location)
                textView.replaceCharacters(in: deletionRange, with: "")
            }

            textView.setSelectedRange(NSRange(location: selection.location, length: 0))
            return true
        }

        private func focusFieldAtEnd(text: String) {
            guard let field, let window = field.window else { return }

            field.placeholderString = nil
            window.makeFirstResponder(field)
            if field.currentEditor() == nil {
                field.selectText(nil)
            }
            if let editor = field.currentEditor() as? NSTextView {
                editor.string = text
                editor.setSelectedRange(insertionRange(atEndOf: text))
            } else {
                field.stringValue = text
            }
        }

        private func insertionRange(atEndOf text: String) -> NSRange {
            NSRange(location: (text as NSString).length, length: 0)
        }

        private func syncTableSelection() {
            guard interactionState.isPresented else {
                tableView.deselectAll(nil)
                return
            }

            guard let index = interactionState.highlightedIndex,
                  suggestions.indices.contains(index) else {
                tableView.deselectAll(nil)
                return
            }

            let indexSet = IndexSet(integer: index)
            tableView.selectRowIndexes(indexSet, byExtendingSelection: false)
            tableView.scrollRowToVisible(index)
        }

        private func presentSuggestionsIfNeeded() {
            guard let field else { return }
            guard field.window != nil else { return }
            guard field.bounds.width > 0, field.bounds.height > 0 else { return }

            let safeMaxSuggestions = min(max(1, parent.maxSuggestions), 6)
            let width = min(max(field.bounds.width, 260), 360)
            let visibleRowCount = min(max(1, suggestions.count), safeMaxSuggestions)
            let countColumnWidth: CGFloat = 76
            let height = CGFloat(visibleRowCount) * tableView.rowHeight + 8

            if let termColumn = tableView.tableColumns.first(where: { $0.identifier.rawValue == "term" }),
               let countColumn = tableView.tableColumns.first(where: { $0.identifier.rawValue == "count" }) {
                countColumn.width = countColumnWidth
                termColumn.width = max(140, width - countColumnWidth - 16)
            }
            scrollView.hasVerticalScroller = suggestions.count > visibleRowCount
            popover.contentSize = NSSize(width: width, height: height)

            if popover.isShown {
                popover.positioningRect = field.bounds
            } else {
                popover.show(relativeTo: field.bounds, of: field, preferredEdge: .maxY)
            }
        }

        private func dismissSuggestions() {
            interactionState.dismiss()
            if popover.isShown {
                popover.performClose(nil)
            }
            tableView.deselectAll(nil)
        }
    }
}

struct LexicalAutocompleteInteractionState: Equatable {
    var isPresented = false
    var highlightedIndex: Int?
    private var acceptedSuggestionText: String?

    mutating func updateSuggestions(
        _ suggestions: [LexicalAutocompleteSuggestion],
        for query: String,
        forcePresentation: Bool = false
    ) {
        if forcePresentation {
            acceptedSuggestionText = nil
        } else if let acceptedSuggestionText,
                  acceptedSuggestionText.hasPrefix(query) {
            dismiss()
            return
        }

        acceptedSuggestionText = nil
        guard suggestions.isEmpty == false else {
            dismiss()
            return
        }

        isPresented = true
        if let highlightedIndex {
            self.highlightedIndex = min(max(0, highlightedIndex), suggestions.count - 1)
        } else {
            highlightedIndex = 0
        }
    }

    mutating func moveSelection(by delta: Int, suggestionCount: Int) -> Bool {
        guard suggestionCount > 0 else {
            dismiss()
            return false
        }

        if isPresented == false {
            isPresented = true
        }

        let baseIndex: Int
        if let highlightedIndex {
            baseIndex = highlightedIndex
        } else {
            baseIndex = delta >= 0 ? -1 : suggestionCount
        }

        highlightedIndex = min(max(0, baseIndex + delta), suggestionCount - 1)
        return true
    }

    func acceptHighlightedSuggestion(
        from suggestions: [LexicalAutocompleteSuggestion]
    ) -> LexicalAutocompleteSuggestion? {
        guard isPresented, let highlightedIndex, suggestions.indices.contains(highlightedIndex) else {
            return nil
        }
        return suggestions[highlightedIndex]
    }

    mutating func markAcceptedSuggestion(_ text: String) {
        acceptedSuggestionText = text
        dismiss()
    }

    mutating func dismiss() {
        isPresented = false
        highlightedIndex = nil
    }
}
