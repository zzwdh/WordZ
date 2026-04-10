import AppKit

extension NativeTableView.Coordinator {
    @MainActor
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row >= 0, row < rows.count, let tableColumn else { return nil }
        let identifier = tableColumn.identifier
        let columnID = identifier.rawValue
        guard let column = descriptor.column(id: columnID) else { return nil }
        let textField: NSTextField
        if let reused = tableView.makeView(withIdentifier: identifier, owner: nil) as? NSTextField {
            textField = reused
        } else {
            textField = NSTextField(labelWithString: "")
            textField.identifier = identifier
            textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        }
        configure(textField, for: column)

        let rawValue = rows[row].value(for: columnID)
        textField.stringValue = displayValue(rawValue, for: column)
        textField.toolTip = rawValue.count > 24 ? rawValue : nil
        return textField
    }

    @MainActor
    func configure(_ textField: NSTextField, for columnID: String) {
        guard let column = descriptor.column(id: columnID) else { return }
        configure(textField, for: column)
    }

    @MainActor
    func configure(_ textField: NSTextField, for column: NativeTableColumnDescriptor) {
        let metrics = NativeTableView.metrics(for: resolvedDensity())
        textField.maximumNumberOfLines = 1
        textField.alignment = alignment(for: column)
        textField.font = font(for: column, metrics: metrics)
        textField.textColor = textColor(for: column)
        textField.lineBreakMode = lineBreakMode(for: column)
        textField.backgroundColor = .clear
        textField.drawsBackground = false
    }
}
