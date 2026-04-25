import SwiftUI

extension TopicsView {
    func topicsSplitView(
        _ scene: TopicsSceneModel,
        availableWidth: CGFloat
    ) -> some View {
        let layout = TopicsPaneLayout.resolve(for: availableWidth)

        return topicsPaneLayout(scene, width: availableWidth, layout: layout)
            .frame(
                maxWidth: .infinity,
                minHeight: layout.preferredHeight,
                idealHeight: layout.preferredHeight,
                maxHeight: layout.preferredHeight,
                alignment: .topLeading
            )
    }

    @ViewBuilder
    private func topicsPaneLayout(
        _ scene: TopicsSceneModel,
        width: CGFloat,
        layout: TopicsPaneLayout
    ) -> some View {
        switch layout {
        case .threeColumn:
            HStack(alignment: .top, spacing: WordZTheme.sectionSpacing) {
                topicsListPane(scene)
                    .frame(width: max(280, min(360, width * 0.24)), alignment: .topLeading)
                    .frame(maxHeight: .infinity, alignment: .topLeading)

                topicDetailsPane(scene)
                    .frame(width: max(340, min(440, width * 0.31)), alignment: .topLeading)
                    .frame(maxHeight: .infinity, alignment: .topLeading)

                topicSegmentsPane(scene)
                    .frame(minWidth: max(460, width * 0.36), maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        case .twoColumn:
            HStack(alignment: .top, spacing: WordZTheme.sectionSpacing) {
                topicsListPane(scene)
                    .frame(width: max(280, min(360, width * 0.32)), alignment: .topLeading)
                    .frame(maxHeight: .infinity, alignment: .topLeading)

                VStack(alignment: .leading, spacing: WordZTheme.sectionSpacing) {
                    topicDetailsPane(scene)
                        .frame(
                            maxWidth: .infinity,
                            minHeight: layout.detailsPanePreferredHeight,
                            idealHeight: layout.detailsPanePreferredHeight,
                            maxHeight: layout.detailsPanePreferredHeight,
                            alignment: .topLeading
                        )

                    topicSegmentsPane(scene)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
        case .stacked:
            VStack(alignment: .leading, spacing: WordZTheme.sectionSpacing) {
                topicsListPane(scene)
                    .frame(
                        maxWidth: .infinity,
                        minHeight: layout.listPanePreferredHeight,
                        idealHeight: layout.listPanePreferredHeight,
                        maxHeight: layout.listPanePreferredHeight,
                        alignment: .topLeading
                    )

                topicDetailsPane(scene)
                    .frame(
                        maxWidth: .infinity,
                        minHeight: layout.detailsPanePreferredHeight,
                        idealHeight: layout.detailsPanePreferredHeight,
                        maxHeight: layout.detailsPanePreferredHeight,
                        alignment: .topLeading
                    )

                topicSegmentsPane(scene)
                    .frame(
                        maxWidth: .infinity,
                        minHeight: layout.segmentsPanePreferredHeight,
                        idealHeight: layout.segmentsPanePreferredHeight,
                        maxHeight: layout.segmentsPanePreferredHeight,
                        alignment: .topLeading
                    )
            }
        }
    }
}

enum TopicsPaneLayout: Equatable {
    case threeColumn
    case twoColumn
    case stacked

    var preferredHeight: CGFloat {
        switch self {
        case .threeColumn:
            return 760
        case .twoColumn:
            return 860
        case .stacked:
            return 1_220
        }
    }

    var listPanePreferredHeight: CGFloat {
        switch self {
        case .threeColumn, .twoColumn:
            return preferredHeight
        case .stacked:
            return 320
        }
    }

    var detailsPanePreferredHeight: CGFloat {
        switch self {
        case .threeColumn:
            return preferredHeight
        case .twoColumn:
            return 320
        case .stacked:
            return 360
        }
    }

    var segmentsPanePreferredHeight: CGFloat {
        switch self {
        case .threeColumn, .twoColumn:
            return preferredHeight
        case .stacked:
            return 520
        }
    }

    static func resolve(for width: CGFloat) -> TopicsPaneLayout {
        switch width {
        case ..<1080:
            return .stacked
        case ..<1500:
            return .twoColumn
        default:
            return .threeColumn
        }
    }
}
