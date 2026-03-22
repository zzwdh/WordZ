using System.Text.Json;
using CommunityToolkit.Mvvm.ComponentModel;
using WordZ.Windows.Contracts;
using WordZ.Windows.Services;

namespace WordZ.Windows.ViewModels;

public sealed class MainWindowViewModel : ObservableObject, IAsyncDisposable
{
    private readonly EngineClient _engineClient;
    private readonly NativeShellService _nativeShellService;
    private readonly UpdateService _updateService;
    private bool _initialized;
    private string _windowTitle = "WordZ";
    private string _versionText = "Windows Native Preview";
    private string _engineStatus = "正在连接本地引擎...";
    private string _workspaceSummary = "等待载入本地语料库";
    private string _buildSummary = "WinUI 3 + Node.js sidecar";
    private bool _isBusy = true;
    private bool _isConnected;

    public MainWindowViewModel(EngineClient engineClient, NativeShellService nativeShellService, UpdateService updateService)
    {
        _engineClient = engineClient;
        _nativeShellService = nativeShellService;
        _updateService = updateService;
        _engineClient.NotificationReceived += HandleNotificationReceived;
        _engineClient.EngineErrorReceived += HandleEngineErrorReceived;
    }

    public string WindowTitle
    {
        get => _windowTitle;
        private set => SetProperty(ref _windowTitle, value);
    }

    public string VersionText
    {
        get => _versionText;
        private set => SetProperty(ref _versionText, value);
    }

    public string EngineStatus
    {
        get => _engineStatus;
        private set => SetProperty(ref _engineStatus, value);
    }

    public string WorkspaceSummary
    {
        get => _workspaceSummary;
        private set => SetProperty(ref _workspaceSummary, value);
    }

    public string BuildSummary
    {
        get => _buildSummary;
        private set => SetProperty(ref _buildSummary, value);
    }

    public bool IsBusy
    {
        get => _isBusy;
        private set => SetProperty(ref _isBusy, value);
    }

    public bool IsConnected
    {
        get => _isConnected;
        private set => SetProperty(ref _isConnected, value);
    }

    public async Task InitializeAsync(CancellationToken cancellationToken = default)
    {
        if (_initialized) return;
        _initialized = true;

        try
        {
            var userDataDir = _nativeShellService.GetUserDataDirectory();
            await _engineClient.StartAsync(userDataDir, cancellationToken);

            using var appInfoDocument = await _engineClient.InvokeAsync(EngineContracts.Methods.AppGetInfo, cancellationToken: cancellationToken);
            if (appInfoDocument is not null)
            {
                ApplyAppInfo(appInfoDocument.RootElement);
            }

            using var libraryDocument = await _engineClient.InvokeAsync(
                EngineContracts.Methods.LibraryList,
                new { folderId = "all" },
                cancellationToken
            );
            if (libraryDocument is not null)
            {
                ApplyLibraryInfo(libraryDocument.RootElement);
            }

            var updateState = await _updateService.CheckForUpdatesAsync(cancellationToken);
            BuildSummary = updateState.Supported
                ? "WinUI 3 + Node.js sidecar + MSIX updates"
                : "WinUI 3 + Node.js sidecar（更新链待接入）";
            EngineStatus = "本地引擎已连接";
            IsConnected = true;
        }
        catch (Exception exception)
        {
            EngineStatus = $"本地引擎启动失败：{exception.Message}";
            WorkspaceSummary = "请检查 packages/wordz-engine-js/src/index.mjs、Node.js 24.x 与用户数据目录。";
        }
        finally
        {
            IsBusy = false;
        }
    }

    private void ApplyAppInfo(JsonElement payload)
    {
        if (!payload.TryGetProperty("result", out var resultElement)) return;
        if (!resultElement.TryGetProperty("appInfo", out var appInfoElement)) return;

        var name = appInfoElement.TryGetProperty("name", out var nameElement) ? nameElement.GetString() : "WordZ";
        var version = appInfoElement.TryGetProperty("version", out var versionElement) ? versionElement.GetString() : string.Empty;
        WindowTitle = string.IsNullOrWhiteSpace(name) ? "WordZ" : name!;
        VersionText = string.IsNullOrWhiteSpace(version) ? "Windows Native Preview" : $"当前版本 v{version}";
    }

    private void ApplyLibraryInfo(JsonElement payload)
    {
        if (!payload.TryGetProperty("result", out var resultElement)) return;
        var folders = resultElement.TryGetProperty("folders", out var foldersElement) && foldersElement.ValueKind == JsonValueKind.Array
            ? foldersElement.GetArrayLength()
            : 0;
        var corpora = resultElement.TryGetProperty("corpora", out var corporaElement) && corporaElement.ValueKind == JsonValueKind.Array
            ? corporaElement.GetArrayLength()
            : 0;
        WorkspaceSummary = $"已发现 {corpora} 条语料，{folders} 个分类文件夹。";
    }

    private void HandleNotificationReceived(object? sender, EngineNotificationEventArgs eventArgs)
    {
        if (eventArgs.Method.StartsWith("task.", StringComparison.Ordinal))
        {
            EngineStatus = $"分析任务事件：{eventArgs.Method}";
            return;
        }

        if (eventArgs.Method == "diagnostics.log")
        {
            EngineStatus = "已收到诊断日志事件";
        }
    }

    private void HandleEngineErrorReceived(object? sender, string message)
    {
        EngineStatus = $"Engine stderr: {message}";
    }

    public async ValueTask DisposeAsync()
    {
        _engineClient.NotificationReceived -= HandleNotificationReceived;
        _engineClient.EngineErrorReceived -= HandleEngineErrorReceived;
        await _engineClient.DisposeAsync();
    }
}
