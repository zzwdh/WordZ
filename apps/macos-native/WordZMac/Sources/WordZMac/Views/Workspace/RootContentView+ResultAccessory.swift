import SwiftUI

extension RootContentView {
    @ViewBuilder
    var workspaceResultActionAccessory: some View {
        if let artifact = viewModel.currentResultArtifact {
            AdaptiveSelectionAccessorySurface {
                HStack(alignment: .center, spacing: 10) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(artifact.title)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                            Text(resultAccessorySubtitle(for: artifact))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    } icon: {
                        Image(systemName: artifact.sourceTab.symbolName)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 12)

                    ForEach(artifact.actionDescriptors(in: languageMode)) { descriptor in
                        workspaceResultActionButton(descriptor)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 10)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    func workspaceResultActionButton(
        _ descriptor: WorkspaceResultArtifactActionDescriptor
    ) -> some View {
        Button {
            dispatcher.handleWorkspaceIntent(.resultArtifact(descriptor.action))
        } label: {
            Label(
                descriptor.title,
                systemImage: descriptor.systemImage
            )
        }
        .controlSize(.small)
        .adaptiveGlassButtonStyle(prominent: descriptor.isProminent)
        .help(descriptor.help)
    }

    func resultAccessorySubtitle(for artifact: WorkspaceResultArtifact) -> String {
        if artifact.totalRows > 0, artifact.visibleRows != artifact.totalRows {
            return "\(artifact.status) · \(artifact.visibleRows) / \(artifact.totalRows)"
        }
        if artifact.totalRows > 0 {
            return "\(artifact.status) · \(artifact.visibleRows)"
        }
        return artifact.status
    }
}
