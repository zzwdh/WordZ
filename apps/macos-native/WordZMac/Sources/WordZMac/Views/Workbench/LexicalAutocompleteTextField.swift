import AppKit
import SwiftUI
import WordZShared

struct LexicalAutocompleteTextField: NSViewRepresentable {
    let title: String
    @Binding var text: String
    let searchOptions: SearchOptionsState
    var stopwordFilter: StopwordFilterState = .default
    var suggestionScope: LexicalSuggestionScope? = nil
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
        private var displayItems: [LexicalAutocompleteDisplayItem] = []
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
            let snapshot = parent.controller.suggestionSnapshot(
                for: query,
                options: parent.searchOptions,
                stopwordFilter: parent.stopwordFilter,
                scope: parent.suggestionScope,
                limit: parent.maxSuggestions
            )
            applySnapshot(snapshot, for: query, forcePresentation: forcePresentation)
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
            displayItems.count
        }

        func tableView(
            _ tableView: NSTableView,
            viewFor tableColumn: NSTableColumn?,
            row: Int
        ) -> NSView? {
            guard displayItems.indices.contains(row) else { return nil }
            let item = displayItems[row]
            let identifier = NSUserInterfaceItemIdentifier(rawValue: tableColumn?.identifier.rawValue ?? "term")

            if let cell = tableView.makeView(withIdentifier: identifier, owner: nil) as? NSTableCellView {
                configure(cell: cell, for: item, columnID: identifier.rawValue)
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

            configure(cell: cell, for: item, columnID: identifier.rawValue)
            return cell
        }

        func tableViewSelectionDidChange(_ notification: Notification) {
            let selectedRow = tableView.selectedRow
            guard selectedRow >= 0,
                  displayItems.indices.contains(selectedRow),
                  displayItems[selectedRow].suggestion != nil else {
                interactionState.highlightedIndex = nil
                return
            }
            interactionState.highlightedIndex = selectedRow
        }

        func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
            guard displayItems.indices.contains(row) else { return false }
            return displayItems[row].suggestion != nil
        }

        @objc
        func handleSuggestionTableAction(_ sender: Any?) {
            let clickedRow = tableView.clickedRow >= 0 ? tableView.clickedRow : tableView.selectedRow
            guard displayItems.indices.contains(clickedRow),
                  let suggestion = displayItems[clickedRow].suggestion else { return }
            accept(suggestion)
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
            tableView.allowsEmptySelection = true
            tableView.allowsMultipleSelection = false
            tableView.focusRingType = .none
            tableView.intercellSpacing = NSSize(width: 4, height: 2)
            tableView.rowHeight = 24
            tableView.selectionHighlightStyle = .regular

            let termColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("term"))
            termColumn.resizingMask = .autoresizingMask
            termColumn.width = 220
            let countColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("count"))
            countColumn.width = 116

            tableView.addTableColumn(termColumn)
            tableView.addTableColumn(countColumn)
        }

        private func configure(
            cell: NSTableCellView,
            for item: LexicalAutocompleteDisplayItem,
            columnID: String
        ) {
            guard let label = cell.textField else { return }

            switch columnID {
            case "count":
                label.stringValue = detailText(for: item)
                label.alignment = .right
                label.font = .monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
                label.textColor = .secondaryLabelColor
            default:
                label.stringValue = termText(for: item)
                label.alignment = .left
                label.font = termFont(for: item)
                label.textColor = termColor(for: item)
            }
        }

        private func termText(for item: LexicalAutocompleteDisplayItem) -> String {
            switch item {
            case .header(let source):
                return headerText(for: source)
            case .suggestion(let suggestion):
                return suggestion.term
            case .status(let status):
                return statusText(for: status, query: parent.text) ?? ""
            }
        }

        private func detailText(for item: LexicalAutocompleteDisplayItem) -> String {
            guard case .suggestion(let suggestion) = item else { return "" }

            switch suggestion.source {
            case .prefix:
                return wordZText("\(suggestion.count) 次", "\(suggestion.count) hits", mode: WordZLocalization.shared.effectiveMode)
            case .collocate:
                return relatedDetailText(for: suggestion)
            }
        }

        private func termFont(for item: LexicalAutocompleteDisplayItem) -> NSFont {
            switch item {
            case .header:
                return .systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold)
            case .status:
                return .systemFont(ofSize: NSFont.smallSystemFontSize)
            case .suggestion:
                return .systemFont(ofSize: NSFont.systemFontSize)
            }
        }

        private func termColor(for item: LexicalAutocompleteDisplayItem) -> NSColor {
            switch item {
            case .header, .status:
                return .secondaryLabelColor
            case .suggestion:
                return .labelColor
            }
        }

        private func applySnapshot(
            _ snapshot: LexicalSuggestionSnapshot,
            for query: String,
            forcePresentation: Bool = false
        ) {
            suggestions = snapshot.suggestions
            displayItems = makeDisplayItems(
                suggestions: snapshot.suggestions,
                status: snapshot.status,
                query: query
            )
            interactionState.updatePresentation(
                displayItemCount: displayItems.count,
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

            guard interactionState.moveSelection(by: delta, displayItems: displayItems) else {
                return false
            }

            syncTableSelection()
            presentSuggestionsIfNeeded()
            return true
        }

        private func acceptHighlightedSuggestion(in textView: NSTextView?) -> Bool {
            guard let suggestion = interactionState.acceptHighlightedSuggestion(from: displayItems) else {
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

            applyEditorTextChange(textView, refreshSuggestions: true)
            return true
        }

        private func deleteForward(in textView: NSTextView) -> Bool {
            guard deleteText(in: textView, direction: .forward) else {
                dismissSuggestions()
                return true
            }

            applyEditorTextChange(textView, refreshSuggestions: true)
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
                  displayItems.indices.contains(index),
                  displayItems[index].suggestion != nil else {
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

            let safeMaxSuggestions = min(max(1, parent.maxSuggestions + 2), 8)
            let width = min(max(field.bounds.width, 300), 420)
            let visibleRowCount = min(max(1, displayItems.count), safeMaxSuggestions)
            let countColumnWidth: CGFloat = 116
            let height = CGFloat(visibleRowCount) * tableView.rowHeight + 8

            if let termColumn = tableView.tableColumns.first(where: { $0.identifier.rawValue == "term" }),
               let countColumn = tableView.tableColumns.first(where: { $0.identifier.rawValue == "count" }) {
                countColumn.width = countColumnWidth
                termColumn.width = max(140, width - countColumnWidth - 16)
            }
            scrollView.hasVerticalScroller = displayItems.count > visibleRowCount
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

        private func makeDisplayItems(
            suggestions: [LexicalAutocompleteSuggestion],
            status: LexicalSuggestionStatus,
            query: String
        ) -> [LexicalAutocompleteDisplayItem] {
            var items: [LexicalAutocompleteDisplayItem] = []
            var displayedSources = Set<LexicalSuggestionSource>()

            for suggestion in suggestions {
                if !displayedSources.contains(suggestion.source) {
                    displayedSources.insert(suggestion.source)
                    items.append(.header(suggestion.source))
                }
                items.append(.suggestion(suggestion))
            }

            if statusText(for: status, query: query) != nil {
                items.append(.status(status))
            }

            return items
        }

        private func headerText(for source: LexicalSuggestionSource) -> String {
            switch source {
            case .prefix:
                return wordZText("补全", "Matches", mode: WordZLocalization.shared.effectiveMode)
            case .collocate:
                return wordZText("相关词", "Related words", mode: WordZLocalization.shared.effectiveMode)
            }
        }

        private func statusText(for status: LexicalSuggestionStatus, query: String) -> String? {
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            let mode = WordZLocalization.shared.effectiveMode

            switch status {
            case .ready:
                return nil
            case .noCorpus:
                guard !trimmed.isEmpty else { return nil }
                return wordZText("先选择一条语料。", "Select a corpus first.", mode: mode)
            case .loading:
                guard !trimmed.isEmpty else { return nil }
                return wordZText("正在准备词表…", "Preparing word list...", mode: mode)
            case .unavailable:
                guard !trimmed.isEmpty else { return nil }
                return wordZText("当前语料还没有可用词表。", "No word list is available for this corpus.", mode: mode)
            case .queryTooShort(let minimumLength):
                guard !trimmed.isEmpty else { return nil }
                let remaining = max(1, minimumLength - trimmed.count)
                return wordZText("再输入 \(remaining) 个字即可联想。", "Type \(remaining) more character(s) for suggestions.", mode: mode)
            case .unsupportedMode:
                guard !trimmed.isEmpty else { return nil }
                return wordZText("当前匹配方式不使用联想。", "Suggestions are off for the current match mode.", mode: mode)
            case .noMatches:
                guard !trimmed.isEmpty else { return nil }
                return wordZText("没有找到匹配词。", "No matching words found.", mode: mode)
            case .relatedLoading:
                return wordZText("正在查找相关词…", "Looking up related words...", mode: mode)
            case .noRelatedMatches:
                return wordZText("没有找到相关词。", "No related words found.", mode: mode)
            }
        }

        private func relatedDetailText(for suggestion: LexicalSuggestion) -> String {
            let mode = WordZLocalization.shared.effectiveMode
            let strength: String
            switch suggestion.score ?? 0 {
            case 8...:
                strength = wordZText("关联强", "Strong", mode: mode)
            case 5..<8:
                strength = wordZText("关联中", "Medium", mode: mode)
            default:
                strength = wordZText("关联弱", "Light", mode: mode)
            }
            let cooccurrence = suggestion.cooccurrence ?? 0
            return wordZText("\(strength) · 共现 \(cooccurrence)", "\(strength) · \(cooccurrence)x", mode: mode)
        }
    }
}

enum LexicalAutocompleteDisplayItem: Equatable {
    case header(LexicalSuggestionSource)
    case suggestion(LexicalAutocompleteSuggestion)
    case status(LexicalSuggestionStatus)

    var suggestion: LexicalAutocompleteSuggestion? {
        guard case .suggestion(let suggestion) = self else { return nil }
        return suggestion
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
        updatePresentation(
            displayItemCount: suggestions.count,
            for: query,
            forcePresentation: forcePresentation
        )
    }

    mutating func updatePresentation(
        displayItemCount: Int,
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
        guard displayItemCount > 0 else {
            dismiss()
            return
        }

        isPresented = true
        if let highlightedIndex {
            self.highlightedIndex = min(max(0, highlightedIndex), displayItemCount - 1)
        } else {
            highlightedIndex = nil
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

    mutating func moveSelection(
        by delta: Int,
        displayItems: [LexicalAutocompleteDisplayItem]
    ) -> Bool {
        let selectableIndexes = displayItems.indices.filter { displayItems[$0].suggestion != nil }
        guard selectableIndexes.isEmpty == false else {
            highlightedIndex = nil
            return false
        }

        if isPresented == false {
            isPresented = true
        }

        let nextIndex: Int
        if let highlightedIndex {
            if delta >= 0 {
                nextIndex = selectableIndexes.first(where: { $0 > highlightedIndex }) ?? selectableIndexes.last!
            } else {
                nextIndex = selectableIndexes.reversed().first(where: { $0 < highlightedIndex }) ?? selectableIndexes.first!
            }
        } else {
            nextIndex = delta >= 0 ? selectableIndexes.first! : selectableIndexes.last!
        }

        highlightedIndex = nextIndex
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

    func acceptHighlightedSuggestion(
        from displayItems: [LexicalAutocompleteDisplayItem]
    ) -> LexicalAutocompleteSuggestion? {
        guard isPresented, let highlightedIndex, displayItems.indices.contains(highlightedIndex) else {
            return nil
        }
        return displayItems[highlightedIndex].suggestion
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
