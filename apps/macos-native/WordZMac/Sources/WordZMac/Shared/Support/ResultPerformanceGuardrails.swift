import Foundation

enum ResultPerformanceGuardrails {
    static let maximumInteractiveAllRows = 1_000
}

protocol InteractiveAllPageSizing: Equatable {
    var isAllSelection: Bool { get }
    static var safeInteractiveFallback: Self { get }
}

extension InteractiveAllPageSizing {
    func resolvedInteractivePageSize(totalRows: Int?) -> Self {
        guard isAllSelection, let totalRows else { return self }
        return Self.allowsInteractiveAllPageSize(totalRows: totalRows) ? self : Self.safeInteractiveFallback
    }

    static func allowsInteractiveAllPageSize(totalRows: Int) -> Bool {
        totalRows <= ResultPerformanceGuardrails.maximumInteractiveAllRows
    }
}

extension StatsPageSize: InteractiveAllPageSizing {
    var isAllSelection: Bool { self == .all }
    static var safeInteractiveFallback: StatsPageSize { .twoHundredFifty }
}

extension WordPageSize: InteractiveAllPageSizing {
    var isAllSelection: Bool { self == .all }
    static var safeInteractiveFallback: WordPageSize { .twoHundredFifty }
}

extension TokenizePageSize: InteractiveAllPageSizing {
    var isAllSelection: Bool { self == .all }
    static var safeInteractiveFallback: TokenizePageSize { .twoHundredFifty }
}

extension NgramPageSize: InteractiveAllPageSizing {
    var isAllSelection: Bool { self == .all }
    static var safeInteractiveFallback: NgramPageSize { .twoHundredFifty }
}

extension KWICPageSize: InteractiveAllPageSizing {
    var isAllSelection: Bool { self == .all }
    static var safeInteractiveFallback: KWICPageSize { .oneHundred }
}

extension ComparePageSize: InteractiveAllPageSizing {
    var isAllSelection: Bool { self == .all }
    static var safeInteractiveFallback: ComparePageSize { .oneHundred }
}

extension KeywordPageSize: InteractiveAllPageSizing {
    var isAllSelection: Bool { self == .all }
    static var safeInteractiveFallback: KeywordPageSize { .oneHundred }
}

extension CollocatePageSize: InteractiveAllPageSizing {
    var isAllSelection: Bool { self == .all }
    static var safeInteractiveFallback: CollocatePageSize { .oneHundred }
}

extension LocatorPageSize: InteractiveAllPageSizing {
    var isAllSelection: Bool { self == .all }
    static var safeInteractiveFallback: LocatorPageSize { .oneHundred }
}

extension TopicsPageSize: InteractiveAllPageSizing {
    var isAllSelection: Bool { self == .all }
    static var safeInteractiveFallback: TopicsPageSize { .oneHundred }
}
