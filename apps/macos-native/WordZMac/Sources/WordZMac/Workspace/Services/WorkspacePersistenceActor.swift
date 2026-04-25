import Foundation

enum WorkspacePersistenceStrategy: Sendable {
    case immediate
    case debounced(nanoseconds: UInt64)
}

actor WorkspacePersistenceActor {
    private struct PendingSave {
        let sequence: UInt64
        let draft: WorkspaceStateDraft
        let strategy: WorkspacePersistenceStrategy
        let onPersisted: @MainActor @Sendable (WorkspaceStateDraft) -> Void
        let onError: @MainActor @Sendable (Error) -> Void
    }

    private let saveOperation: @MainActor @Sendable (WorkspaceStateDraft) async throws -> Void

    private var nextSequence: UInt64 = 0
    private var latestScheduledSequence: UInt64 = 0
    private var scheduledSave: PendingSave?
    private var scheduleTask: Task<Void, Never>?
    private var isSaving = false
    private var lastSavedDraft: WorkspaceStateDraft?

    init(
        saveOperation: @escaping @MainActor @Sendable (WorkspaceStateDraft) async throws -> Void
    ) {
        self.saveOperation = saveOperation
    }

    func schedule(
        draft: WorkspaceStateDraft,
        strategy: WorkspacePersistenceStrategy,
        onPersisted: @escaping @MainActor @Sendable (WorkspaceStateDraft) -> Void,
        onError: @escaping @MainActor @Sendable (Error) -> Void
    ) {
        nextSequence &+= 1
        latestScheduledSequence = nextSequence
        scheduledSave = PendingSave(
            sequence: nextSequence,
            draft: draft,
            strategy: strategy,
            onPersisted: onPersisted,
            onError: onError
        )
        scheduleTask?.cancel()
        let expectedSequence = nextSequence
        scheduleTask = Task {
            await self.processScheduledSave(expectedSequence: expectedSequence)
        }
    }

    private func processScheduledSave(expectedSequence: UInt64) async {
        guard let pendingSave = scheduledSave, pendingSave.sequence == expectedSequence else { return }

        if case .debounced(let nanoseconds) = pendingSave.strategy {
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard !Task.isCancelled else { return }
        }

        guard let pending = scheduledSave, pending.sequence == expectedSequence else { return }
        if isSaving { return }

        scheduledSave = nil
        isSaving = true
        defer {
            isSaving = false
            if self.scheduledSave != nil {
                let expectedSequence = self.latestScheduledSequence
                self.scheduleTask = Task {
                    await self.processScheduledSave(expectedSequence: expectedSequence)
                }
            }
        }

        guard lastSavedDraft != pending.draft else {
            if pending.sequence == latestScheduledSequence {
                await pending.onPersisted(pending.draft)
            }
            return
        }

        do {
            try await saveOperation(pending.draft)
            lastSavedDraft = pending.draft
            if pending.sequence == latestScheduledSequence {
                await pending.onPersisted(pending.draft)
            }
        } catch {
            if pending.sequence == latestScheduledSequence {
                await pending.onError(error)
            }
        }
    }
}
