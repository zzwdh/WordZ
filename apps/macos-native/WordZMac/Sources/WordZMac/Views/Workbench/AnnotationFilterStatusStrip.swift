import SwiftUI

struct AnnotationFilterStatusStrip: View {
    @Environment(\.wordZLanguageMode) private var languageMode

    let state: WorkspaceAnnotationState
    let resultCount: Int?
    let showsImpact: Bool

    init(
        state: WorkspaceAnnotationState,
        resultCount: Int? = nil,
        showsImpact: Bool = true
    ) {
        self.state = state
        self.resultCount = resultCount
        self.showsImpact = showsImpact
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    titleLabel
                    statusChips
                    Spacer(minLength: 0)
                }

                VStack(alignment: .leading, spacing: 7) {
                    titleLabel
                    statusChips
                }
            }

            if showsImpact || isEmptyFilteredResult {
                Label(impactText, systemImage: isEmptyFilteredResult ? "exclamationmark.triangle" : "scope")
                    .font(.caption2)
                    .foregroundStyle(isEmptyFilteredResult ? AnyShapeStyle(.orange) : AnyShapeStyle(.tertiary))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(state.summary(in: languageMode)). \(impactText)")
    }

    private var titleLabel: some View {
        Label(
            wordZText("标注口径", "Annotation Scope", mode: languageMode),
            systemImage: state.hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "slider.horizontal.3"
        )
        .font(.caption.weight(.semibold))
        .foregroundStyle(WordZTheme.textPrimary)
    }

    private var statusChips: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) {
                statusChip(systemImage: "character.book.closed", text: state.profile.title(in: languageMode))
                statusChip(systemImage: "character.textbox", text: state.scriptFilterSummary(in: languageMode))
                statusChip(systemImage: "tag", text: state.lexicalClassFilterSummary(in: languageMode))
            }

            VStack(alignment: .leading, spacing: 6) {
                statusChip(systemImage: "character.book.closed", text: state.profile.title(in: languageMode))
                statusChip(systemImage: "character.textbox", text: state.scriptFilterSummary(in: languageMode))
                statusChip(systemImage: "tag", text: state.lexicalClassFilterSummary(in: languageMode))
            }
        }
    }

    private func statusChip(systemImage: String, text: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption2.weight(.medium))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(.quaternary.opacity(0.28), in: Capsule())
    }

    private var impactText: String {
        isEmptyFilteredResult
            ? state.emptyResultHint(in: languageMode)
            : state.impactSummary(in: languageMode)
    }

    private var isEmptyFilteredResult: Bool {
        resultCount == 0 && state.hasActiveFilters
    }
}
