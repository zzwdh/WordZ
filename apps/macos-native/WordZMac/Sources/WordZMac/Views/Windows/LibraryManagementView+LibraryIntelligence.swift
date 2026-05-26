import SwiftUI

extension LibraryManagementView {
    var libraryReadinessButton: some View {
        Button {
            isShowingLibraryReadiness = true
        } label: {
            Label(t("可用度", "Readiness"), systemImage: "checkmark.seal")
        }
        .popover(isPresented: $isShowingLibraryReadiness, arrowEdge: .top) {
            LibraryReadinessPopoverView(
                scene: viewModel.scene.readinessSummary,
                canClean: canTriggerCleaning,
                cleanTitle: cleaningToolbarTitle,
                onClean: {
                    isShowingLibraryReadiness = false
                    onAction(cleaningToolbarAction)
                }
            )
        }
    }

    var metadataStudioButton: some View {
        Button {
            isShowingMetadataStudio = true
        } label: {
            Label(t("元数据", "Metadata"), systemImage: "slider.horizontal.3")
        }
        .popover(isPresented: $isShowingMetadataStudio, arrowEdge: .top) {
            LibraryMetadataStudioPopoverView(
                scene: viewModel.scene.metadataStudio,
                canEditOne: viewModel.scene.selectedCorpusIDs.count == 1,
                canEditMany: viewModel.scene.selectedCorpusIDs.count > 1,
                onEditOne: {
                    isShowingMetadataStudio = false
                    onAction(.editSelectedCorpusMetadata)
                },
                onEditMany: {
                    isShowingMetadataStudio = false
                    onAction(.editSelectedCorporaMetadata)
                },
                onSaveSet: {
                    isShowingMetadataStudio = false
                    onAction(.saveCurrentCorpusSet)
                }
            )
        }
    }
}

private struct LibraryReadinessPopoverView: View {
    @Environment(\.wordZLanguageMode) private var languageMode
    let scene: LibraryReadinessSummarySceneModel
    let canClean: Bool
    let cleanTitle: String
    let onClean: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            NativeWindowHeader(
                title: t("语料可用度", "Corpus Readiness"),
                subtitle: scene.actionSummaryText
            )

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 10)], spacing: 10) {
                NativeMetricTile(title: t("平均", "Average"), value: scene.averageScoreText)
                NativeMetricTile(title: t("可分析", "Ready"), value: "\(scene.readyCount)")
                NativeMetricTile(title: t("需补强", "Attention"), value: "\(scene.attentionCount)")
                NativeMetricTile(title: t("先整理", "Prepare"), value: "\(scene.blockedCount)")
            }

            HStack(spacing: 10) {
                Button(cleanTitle, action: onClean)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canClean)
                Spacer(minLength: 0)
            }
        }
        .padding(18)
        .frame(width: 440, alignment: .topLeading)
    }

    private func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }
}

private struct LibraryMetadataStudioPopoverView: View {
    @Environment(\.wordZLanguageMode) private var languageMode
    let scene: LibraryMetadataStudioSceneModel
    let canEditOne: Bool
    let canEditMany: Bool
    let onEditOne: () -> Void
    let onEditMany: () -> Void
    let onSaveSet: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            NativeWindowHeader(
                title: t("元数据工作台", "Metadata Studio"),
                subtitle: scene.actionHintText
            )

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 10)], spacing: 10) {
                NativeMetricTile(title: t("完整率", "Complete"), value: scene.completionText)
                NativeMetricTile(title: t("完整", "Complete"), value: "\(scene.completeMetadataCount)")
                NativeMetricTile(title: t("缺年份", "No Year"), value: "\(scene.missingYearCount)")
                NativeMetricTile(title: t("缺体裁", "No Genre"), value: "\(scene.missingGenreCount)")
                NativeMetricTile(title: t("缺标签", "No Tags"), value: "\(scene.missingTagsCount)")
            }

            HStack(spacing: 10) {
                Button(t("编辑所选", "Edit Selected"), action: onEditOne)
                    .buttonStyle(.bordered)
                    .disabled(!canEditOne)
                Button(t("批量编辑", "Batch Edit"), action: onEditMany)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canEditMany)
                Spacer(minLength: 0)
                Button(t("保存范围", "Save Scope"), action: onSaveSet)
                    .buttonStyle(.bordered)
                    .disabled(scene.visibleCorpusCount == 0)
            }
        }
        .padding(18)
        .frame(width: 480, alignment: .topLeading)
    }

    private func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }
}
