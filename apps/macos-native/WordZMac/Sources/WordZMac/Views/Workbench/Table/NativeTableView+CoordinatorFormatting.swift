import AppKit

@MainActor
private enum NativeTableNumberFormatterCache {
    struct Key: Hashable {
        let localeIdentifier: String
        let minimumFractionDigits: Int
        let maximumFractionDigits: Int
        let usesGrouping: Bool
    }

    private static var formatters: [Key: NumberFormatter] = [:]

    static func formatter(
        locale: Locale,
        minimumFractionDigits: Int,
        maximumFractionDigits: Int,
        usesGrouping: Bool
    ) -> NumberFormatter {
        let key = Key(
            localeIdentifier: locale.identifier,
            minimumFractionDigits: minimumFractionDigits,
            maximumFractionDigits: maximumFractionDigits,
            usesGrouping: usesGrouping
        )
        if let formatter = formatters[key] {
            return formatter
        }

        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = usesGrouping
        formatter.minimumFractionDigits = minimumFractionDigits
        formatter.maximumFractionDigits = maximumFractionDigits
        formatters[key] = formatter
        return formatter
    }
}

@MainActor
extension NativeTableView.Coordinator {
    func alignment(for column: NativeTableColumnDescriptor) -> NSTextAlignment {
        switch column.presentation {
        case .numeric:
            return .right
        case .keyword, .contextCenter:
            return .center
        case .contextLeading:
            return .right
        default:
            return .left
        }
    }

    func font(for column: NativeTableColumnDescriptor, metrics: NativeTableView.DensityMetrics) -> NSFont {
        switch column.presentation {
        case .numeric:
            return .monospacedSystemFont(ofSize: metrics.fontSize, weight: .regular)
        case .keyword:
            return .systemFont(ofSize: metrics.fontSize, weight: .semibold)
        default:
            return .systemFont(ofSize: metrics.fontSize)
        }
    }

    func textColor(for column: NativeTableColumnDescriptor) -> NSColor {
        switch column.presentation {
        case .keyword:
            return .controlAccentColor
        case .contextLeading, .contextTrailing, .summary:
            return .secondaryLabelColor
        default:
            return .labelColor
        }
    }

    func lineBreakMode(for column: NativeTableColumnDescriptor) -> NSLineBreakMode {
        switch column.presentation {
        case .contextLeading:
            return .byTruncatingHead
        case .summary:
            return .byTruncatingMiddle
        default:
            return .byTruncatingTail
        }
    }

    func displayValue(_ rawValue: String, for column: NativeTableColumnDescriptor) -> String {
        switch column.presentation {
        case .numeric(let precision, let usesGrouping):
            return formattedNumericValue(rawValue, precision: precision, usesGrouping: usesGrouping)
        default:
            return rawValue
        }
    }

    func formattedNumericValue(_ rawValue: String, precision: Int?, usesGrouping: Bool) -> String {
        let normalized = rawValue.replacingOccurrences(of: ",", with: "")
        guard let number = Double(normalized) else { return rawValue }
        if let precision, number != 0 {
            let threshold = pow(10.0, Double(-precision))
            if abs(number) < threshold {
                return number < 0
                    ? "-<\(formattedThreshold(threshold, precision: precision))"
                    : "<\(formattedThreshold(threshold, precision: precision))"
            }
        }

        let resolvedPrecision: Int?
        if let precision {
            resolvedPrecision = precision
        } else if number.rounded() == number {
            resolvedPrecision = 0
        } else {
            resolvedPrecision = 2
        }

        let minimumFractionDigits: Int
        let maximumFractionDigits: Int
        if let resolvedPrecision {
            minimumFractionDigits = resolvedPrecision == 0 ? 0 : resolvedPrecision
            maximumFractionDigits = resolvedPrecision
        } else {
            minimumFractionDigits = 0
            maximumFractionDigits = 6
        }
        let formatter = NativeTableNumberFormatterCache.formatter(
            locale: WordZLocalization.shared.locale,
            minimumFractionDigits: minimumFractionDigits,
            maximumFractionDigits: maximumFractionDigits,
            usesGrouping: usesGrouping
        )
        return formatter.string(from: NSNumber(value: number)) ?? rawValue
    }

    func formattedThreshold(_ value: Double, precision: Int) -> String {
        let formatter = NativeTableNumberFormatterCache.formatter(
            locale: WordZLocalization.shared.locale,
            minimumFractionDigits: precision,
            maximumFractionDigits: precision,
            usesGrouping: false
        )
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.\(precision)f", value)
    }
}
