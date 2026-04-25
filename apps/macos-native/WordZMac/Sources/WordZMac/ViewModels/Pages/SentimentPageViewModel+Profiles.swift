import Foundation

extension SentimentPageViewModel {
    var currentPackRecommendation: SentimentPackRecommendation {
        if let rawResult {
            return SentimentPackRecommendation(
                selectedPackID: rawResult.request.domainPackID,
                effectivePackID: rawResult.request.resolvedDomainPackID,
                reason: rawResult.request.usesAutomaticDomainPack
                    ? (rawResult.request.resolvedDomainPackID == .kwic ? .kwicSource : .newsSignals)
                    : .manualSelection
            )
        }
        return packRecommendationService.resolve(
            selectedPackID: selectedDomainPackID,
            source: source,
            texts: previewTextsForPackRecommendation
        )
    }

    var currentPackSummaryTitle: String {
        currentPackRecommendation.summary(in: WordZLocalization.shared.effectiveMode)
    }

    var currentCalibrationBiasPackID: SentimentDomainPackID {
        rawResult?.request.resolvedDomainPackID ?? currentPackRecommendation.effectivePackID
    }

    var availableRuleProfiles: [SentimentRuleProfile] {
        [configuredDefaultRuleProfile, configuredWorkspaceRuleProfile]
            + importedLexiconBundles
            .sorted { lhs, rhs in
                lhs.manifest.id.localizedCaseInsensitiveCompare(rhs.manifest.id) == .orderedAscending
            }
            .map(makeImportedRuleProfile)
    }

    var selectedRuleProfile: SentimentRuleProfile {
        availableRuleProfiles.first(where: { $0.id == selectedRuleProfileID }) ?? configuredDefaultRuleProfile
    }

    var selectedCalibrationProfile: SentimentCalibrationProfile {
        switch selectedCalibrationProfileID {
        case SentimentCalibrationProfile.workspaceDefault.id:
            return workspaceResolvedCalibrationProfile
        default:
            return defaultResolvedCalibrationProfile
        }
    }

    var canEditWorkspaceCalibration: Bool {
        selectedCalibrationProfileID == SentimentCalibrationProfile.workspaceDefault.id
    }

    var currentPackCalibrationBias: Double {
        get {
            workspaceCalibrationProfile.domainBiasAdjustments[currentCalibrationBiasPackID.rawValue] ?? 0
        }
        set {
            let normalized = min(max(newValue, -0.3), 0.3)
            let packID = currentCalibrationBiasPackID
            var nextProfile = workspaceCalibrationProfile
            if abs(normalized) < 0.0001 {
                nextProfile.domainBiasAdjustments.removeValue(forKey: packID.rawValue)
            } else {
                nextProfile.domainBiasAdjustments[packID.rawValue] = normalized
            }
            nextProfile.preferredPackIDs = [packID]
            nextProfile.revision = "calibration-workspace-\(packID.rawValue)-v1"
            if selectedCalibrationProfileID != SentimentCalibrationProfile.workspaceDefault.id {
                selectedCalibrationProfileID = SentimentCalibrationProfile.workspaceDefault.id
            }
            workspaceCalibrationProfile = nextProfile
        }
    }

    func selectedCalibrationProfileTitle(in mode: AppLanguageMode) -> String {
        availableCalibrationProfiles.first(where: { $0.id == selectedCalibrationProfileID })?.title
            ?? wordZText("默认", "Default", mode: mode)
    }

    var configuredDefaultRuleProfile: SentimentRuleProfile {
        SentimentRuleProfile(
            id: SentimentRuleProfile.default.id,
            title: wordZText("默认", "Default", mode: .system),
            sourceKind: .builtInDefault,
            preferredPackID: selectedDomainPackID,
            thresholdPreset: thresholdPreset,
            neutralShieldStrength: 0.65,
            quoteDiscountEnabled: true,
            quoteDiscountMultiplier: 0.85,
            reportingDiscountMultiplier: 0.9,
            revision: "rule-profile-default-v3"
        )
    }

    var configuredWorkspaceRuleProfile: SentimentRuleProfile {
        SentimentRuleProfile(
            id: SentimentRuleProfile.workspaceDefault.id,
            title: wordZText("工作区", "Workspace", mode: .system),
            sourceKind: .workspace,
            preferredPackID: selectedDomainPackID,
            thresholdPreset: thresholdPreset,
            neutralShieldStrength: 0.75,
            quoteDiscountEnabled: true,
            quoteDiscountMultiplier: 0.8,
            reportingDiscountMultiplier: 0.9,
            revision: "rule-profile-workspace-v3"
        )
    }

    private func makeImportedRuleProfile(from bundle: SentimentUserLexiconBundle) -> SentimentRuleProfile {
        SentimentRuleProfile(
            id: bundleRuleProfileID(for: bundle.id),
            title: importedBundleTitle(bundle),
            sourceKind: .importedBundle,
            preferredPackID: selectedDomainPackID,
            thresholdPreset: thresholdPreset,
            neutralShieldStrength: 0.7,
            quoteDiscountEnabled: true,
            quoteDiscountMultiplier: 0.85,
            reportingDiscountMultiplier: 0.9,
            customEntries: bundle.entries,
            importedBundleIDs: [bundle.id],
            revision: "bundle-\(bundle.manifest.id)-\(bundle.manifest.version)"
        )
    }

    func bundleRuleProfileID(for bundleID: String) -> String {
        "bundle:\(bundleID)"
    }

    private func importedBundleTitle(_ bundle: SentimentUserLexiconBundle) -> String {
        let trimmedID = bundle.manifest.id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedID.isEmpty else {
            return wordZText("导入词典", "Imported Bundle", mode: .system)
        }
        return trimmedID
    }

    private var defaultResolvedCalibrationProfile: SentimentCalibrationProfile {
        let preferredPackID = currentCalibrationBiasPackID
        return SentimentCalibrationProfile(
            id: SentimentCalibrationProfile.default.id,
            decisionThreshold: decisionThreshold,
            minimumEvidence: minimumEvidence,
            neutralBias: neutralBias,
            domainBiasAdjustments: SentimentCalibrationProfile.workspaceDefault.domainBiasAdjustments,
            preferredPackIDs: [preferredPackID],
            revision: "calibration-default-\(preferredPackID.rawValue)-v1"
        )
    }

    private var workspaceResolvedCalibrationProfile: SentimentCalibrationProfile {
        let preferredPackID = currentCalibrationBiasPackID
        return SentimentCalibrationProfile(
            id: SentimentCalibrationProfile.workspaceDefault.id,
            decisionThreshold: decisionThreshold,
            minimumEvidence: minimumEvidence,
            neutralBias: neutralBias,
            domainBiasAdjustments: workspaceCalibrationProfile.domainBiasAdjustments,
            preferredPackIDs: [preferredPackID],
            revision: workspaceCalibrationProfile.revision
        )
    }

    var currentCalibrationProfile: SentimentCalibrationProfile {
        selectedCalibrationProfile
    }

    func refreshAvailableBackends() {
        availableBackends = availableBackendProvider()
        backend = normalizedBackend(backend)
    }

    func normalizeSelectedRuleProfileSelection() {
        if !availableRuleProfiles.contains(where: { $0.id == selectedRuleProfileID }) {
            selectedRuleProfileID = configuredDefaultRuleProfile.id
        }
    }

    func normalizeSelectedCalibrationProfileSelection() {
        if !availableCalibrationProfiles.contains(where: { $0.id == selectedCalibrationProfileID }) {
            selectedCalibrationProfileID = SentimentCalibrationProfile.default.id
        }
    }

    func normalizedCalibrationProfileID(_ candidate: String) -> String {
        switch candidate {
        case SentimentCalibrationProfile.workspaceDefault.id:
            return SentimentCalibrationProfile.workspaceDefault.id
        default:
            return SentimentCalibrationProfile.default.id
        }
    }

    func normalizedBackend(_ candidate: SentimentBackendKind) -> SentimentBackendKind {
        if availableBackends.contains(candidate) {
            return candidate
        }
        if candidate == .coreML {
            backendNotice = wordZText(
                "本机当前没有可用的本地情感模型，已使用词典规则后端。",
                "No local sentiment model is currently available, so WordZ is using the lexicon backend.",
                mode: .system
            )
        }
        return .lexicon
    }

    private var previewTextsForPackRecommendation: [SentimentInputText] {
        switch source {
        case .pastedText:
            let trimmed = manualText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return [] }
            return [
                SentimentInputText(
                    id: "preview-manual",
                    sourceTitle: wordZText("粘贴文本", "Pasted Text", mode: .system),
                    text: trimmed
                )
            ]
        default:
            return rawResult?.request.texts ?? []
        }
    }
}
