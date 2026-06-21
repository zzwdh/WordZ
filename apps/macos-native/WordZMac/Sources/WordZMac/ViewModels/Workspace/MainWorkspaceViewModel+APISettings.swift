import Foundation
import WordZHost

@MainActor
extension MainWorkspaceViewModel {
    func saveAPICredential() async {
        let credential = settings.apiCredentialDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !credential.isEmpty else {
            let status = apiSettingsText("请输入 API Key 或 Token。", "Enter an API key or token.")
            settings.setAPICredentialStatus(status)
            settings.setSupportStatus(status)
            return
        }

        do {
            try apiCredentialStore.saveCredential(credential)
            settings.clearAPICredentialDraft()
            let status = apiSettingsText("API 凭据已保存。", "API credential saved.")
            settings.applyAPICredentialState(isConfigured: true, status: status)
            settings.setSupportStatus(status)
            clearActiveIssue()
        } catch {
            settings.setAPICredentialStatus(error.localizedDescription)
            presentIssue(error, titleZh: "无法保存 API 凭据", titleEn: "Unable to Save API Credential")
        }
    }

    func clearAPICredential() async {
        do {
            try apiCredentialStore.clearCredential()
            settings.clearAPICredentialDraft()
            let status = apiSettingsText("API 凭据已清除。", "API credential cleared.")
            settings.applyAPICredentialState(isConfigured: false, status: status)
            settings.setSupportStatus(status)
            clearActiveIssue()
        } catch {
            settings.setAPICredentialStatus(error.localizedDescription)
            presentIssue(error, titleZh: "无法清除 API 凭据", titleEn: "Unable to Clear API Credential")
        }
    }

    func testAPIConnection() async {
        guard settings.apiAccessEnabled else {
            let status = apiDisabledMessage()
            settings.setAPICredentialStatus(status)
            settings.setSupportStatus(status)
            clearActiveIssue()
            return
        }

        let runningStatus = apiSettingsText(
            "正在检查 API 连接；不会上传语料正文。",
            "Checking API connection; corpus text is not uploaded."
        )
        settings.setAPICredentialStatus(runningStatus)
        settings.setSupportStatus(runningStatus)

        do {
            let credential = try apiCredentialStore.loadCredential()
            let result = try await apiConnectionTester.testConnection(
                credential: credential,
                timeoutSeconds: settings.apiRequestTimeoutSeconds,
                maxConcurrentRequests: settings.apiMaxConcurrentRequests
            )
            recordAPIRequestDiagnostics(result.requestObservation)
            let credentialLine = credential?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                ? apiSettingsText("已使用保存的凭据验证请求头。", "Saved credential was used to validate the request header.")
                : apiSettingsText("未保存凭据，本次只验证基础连接。", "No credential is saved, so this checked basic connectivity only.")
            let status = apiSettingsText(
                "API 连接正常（HTTP \(result.statusCode)，\(result.durationMilliseconds) ms，\(result.endpointHost)）。\(credentialLine) 不会上传完整语料库。",
                "API connection is healthy (HTTP \(result.statusCode), \(result.durationMilliseconds) ms, \(result.endpointHost)). \(credentialLine) Full corpora are not uploaded."
            )
            settings.setAPICredentialStatus(status)
            settings.setSupportStatus(status)
            clearActiveIssue()
        } catch is CancellationError {
            let status = apiSettingsText(
                "API 连接检查已取消。",
                "API connection check was cancelled."
            )
            settings.setAPICredentialStatus(status)
            settings.setSupportStatus(status)
            clearActiveIssue()
        } catch {
            let status = apiConnectionFailureMessage(for: error)
            settings.setAPICredentialStatus(status)
            settings.setSupportStatus(status)
            presentIssue(error, titleZh: "API 连接检查失败", titleEn: "API Connection Check Failed")
        }
    }

    func canRunNetworkAPIAction() -> Bool {
        guard settings.apiAccessEnabled else {
            let message = apiDisabledMessage()
            settings.setSupportStatus(message)
            settings.setAPICredentialStatus(message)
            applyUpdateStateSnapshot(makeUpdateStateSnapshot(statusMessage: message))
            clearActiveIssue()
            return false
        }
        return true
    }

    func configuredUpdateService() -> any NativeUpdateServicing {
        guard let apiUpdateServiceFactory else { return updateService }
        return apiUpdateServiceFactory(
            settings.apiRequestTimeoutSeconds,
            settings.apiMaxConcurrentRequests
        )
    }

    func apiDisabledMessage() -> String {
        apiSettingsText(
            "联网 API 已关闭；本地分析仍可使用。若要检查或下载更新，请先在设置中开启联网 API。",
            "Network API access is off; local analysis still works. Turn on network API access in Settings to check or download updates."
        )
    }

    private func apiSettingsText(_ zh: String, _ en: String) -> String {
        t(zh, en)
    }

    private func recordAPIRequestDiagnostics(_ observation: NativeAPIRequestObservation?) {
        guard let observation else { return }
        apiRequestDiagnostics.append(
            NativeDiagnosticsAPIRequestMetadata(
                requestID: observation.requestID.uuidString,
                method: observation.method,
                url: observation.url,
                statusCode: observation.statusCode,
                durationMilliseconds: observation.durationMilliseconds,
                attemptCount: observation.attemptCount,
                headers: observation.headers,
                cacheState: observation.cacheState,
                outcome: observation.outcome
            ).redactedForDiagnostics()
        )
        if apiRequestDiagnostics.count > 20 {
            apiRequestDiagnostics.removeFirst(apiRequestDiagnostics.count - 20)
        }
    }

    private func apiConnectionFailureMessage(for error: Error) -> String {
        if let apiError = error as? NativeAPIClientError {
            switch apiError {
            case .httpStatus(let code, _, _, let retryAfterSeconds):
                if code == 401 || code == 403 {
                    return apiSettingsText(
                        "API 连接失败：凭据不可用或权限不足（HTTP \(code)）。请检查保存的 API Key 或 Token。",
                        "API connection failed: credential is invalid or lacks permission (HTTP \(code)). Check the saved API key or token."
                    )
                }
                if code == 429 {
                    let wait = retryAfterSeconds.map { "，约 \(Int($0)) 秒后再试" } ?? ""
                    return apiSettingsText(
                        "API 连接失败：服务端限流（HTTP 429）\(wait)。本地分析仍可使用。",
                        "API connection failed: service rate limited the request (HTTP 429). Local analysis still works."
                    )
                }
                return apiSettingsText(
                    "API 连接失败：服务端返回 HTTP \(code)。本地分析仍可使用。",
                    "API connection failed: server returned HTTP \(code). Local analysis still works."
                )
            case .transport(let underlying, _):
                return apiSettingsText(
                    "API 连接失败：\(underlying.localizedDescription)。本地分析仍可使用。",
                    "API connection failed: \(underlying.localizedDescription). Local analysis still works."
                )
            case .invalidResponse:
                return apiSettingsText(
                    "API 连接失败：响应格式无效。本地分析仍可使用。",
                    "API connection failed: invalid response. Local analysis still works."
                )
            }
        }
        return apiSettingsText(
            "API 连接失败：\(error.localizedDescription)。本地分析仍可使用。",
            "API connection failed: \(error.localizedDescription). Local analysis still works."
        )
    }
}
