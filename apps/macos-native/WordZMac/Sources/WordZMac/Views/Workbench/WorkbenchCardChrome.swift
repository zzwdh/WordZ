import SwiftUI

struct WorkbenchCardChromeModifier: ViewModifier {
    let cornerRadius: CGFloat
    let backgroundColor: Color
    let borderColor: Color
    let lineWidth: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                backgroundColor,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(borderColor, lineWidth: lineWidth)
            )
    }
}

extension View {
    func workbenchCardChrome(
        cornerRadius: CGFloat = WordZTheme.radiusMedium,
        backgroundColor: Color = WordZTheme.cardBackground,
        borderColor: Color = WordZTheme.shellBorder,
        lineWidth: CGFloat = 1
    ) -> some View {
        modifier(
            WorkbenchCardChromeModifier(
                cornerRadius: cornerRadius,
                backgroundColor: backgroundColor,
                borderColor: borderColor,
                lineWidth: lineWidth
            )
        )
    }
}
