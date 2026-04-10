import SwiftUI

struct WorkbenchMenuPicker<Option: Identifiable, SelectionValue: Hashable>: View {
    let title: String
    @Binding var selection: SelectionValue
    let options: [Option]
    let minWidth: CGFloat?
    let isDisabled: Bool
    let label: (Option) -> String
    let value: (Option) -> SelectionValue

    init(
        title: String,
        selection: Binding<SelectionValue>,
        options: [Option],
        minWidth: CGFloat? = nil,
        isDisabled: Bool = false,
        label: @escaping (Option) -> String,
        value: @escaping (Option) -> SelectionValue
    ) {
        self.title = title
        self._selection = selection
        self.options = options
        self.minWidth = minWidth
        self.isDisabled = isDisabled
        self.label = label
        self.value = value
    }

    var body: some View {
        Picker(title, selection: $selection) {
            ForEach(options) { option in
                Text(label(option)).tag(value(option))
            }
        }
        .pickerStyle(.menu)
        .frame(minWidth: minWidth, alignment: .leading)
        .disabled(isDisabled)
    }
}

extension WorkbenchMenuPicker where Option: Hashable, SelectionValue == Option {
    init(
        title: String,
        selection: Binding<Option>,
        options: [Option],
        minWidth: CGFloat? = nil,
        isDisabled: Bool = false,
        label: @escaping (Option) -> String
    ) {
        self.init(
            title: title,
            selection: selection,
            options: options,
            minWidth: minWidth,
            isDisabled: isDisabled,
            label: label,
            value: { $0 }
        )
    }
}
