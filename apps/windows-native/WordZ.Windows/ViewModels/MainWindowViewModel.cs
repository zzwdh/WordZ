using System.Text.Json;
using CommunityToolkit.Mvvm.ComponentModel;
using Microsoft.UI.Dispatching;
using Microsoft.UI.Xaml.Controls;
using WordZ.Windows.Contracts;
using WordZ.Windows.Models;
using WordZ.Windows.Services;

namespace WordZ.Windows.ViewModels;

public sealed class MainWindowViewModel : ObservableObject, IAsyncDisposable
{
    private readonly DispatcherQueue _dispatcherQueue;
    private readonly EngineClient _engineClient;
    private readonly NativeLibraryService _libraryService;
    private readonly NativeShellService _nativeShellService;
    private readonly NativeWorkspaceService _workspaceService;
    private readonly UpdateService _updateService;
    private bool _initialized;

    public MainWindowViewModel(
        EngineClient engineClient,
        NativeShellService nativeShellService,
        NativeWorkspaceService workspaceService,
        UpdateService updateService,
        DispatcherQueue dispatcherQueue)
    {
        _dispatcherQueue = dispatcherQueue;
        _engineClient = engineClient;
        _libraryService = new NativeLibraryService(engineClient);
        _nativeShellService = nativeShellService;
        _workspaceService = workspaceService;
        _updateService = updateService;
        _engineClient.NotificationReceived += HandleNotificationReceived;
        _engineClient.EngineErrorReceived += HandleEngineErrorReceived;
        Shell = new NativeShellState();
    }

    public NativeShellState Shell { get; }

    public EngineClient EngineClient => _engineClient;

    public NativeLibraryService LibraryService => _libraryService;

    public NativeWorkspaceService WorkspaceService => _workspaceService;

    public string RestoredNavigationTag { get; private set; } = "library";

    public async Task InitializeAsync(CancellationToken cancellationToken = default)
    {
        if (_initialized)
        {
            return;
        }

        _initialized = true;

        try
        {
            var userDataDir = _nativeShellService.GetUserDataDirectory();
            NativeTrace.Write($"MainWindowViewModel InitializeAsync start. UserDataDir='{userDataDir}'");
            Shell.IsBusy = true;
            Shell.EngineStatus = "Connecting to the WordZ Node sidecar...";
            Shell.EngineSeverity = InfoBarSeverity.Informational;
            await _engineClient.StartAsync(userDataDir, cancellationToken);
            NativeTrace.Write(
                $"EngineClient started. Node='{_engineClient.ResolvedNodePath}' Engine='{_engineClient.ResolvedEngineEntryPath}'"
            );

            using var appInfoDocument = await _engineClient.InvokeAsync(
                EngineContracts.Methods.AppGetInfo,
                cancellationToken: cancellationToken
            );
            if (appInfoDocument is not null)
            {
                ApplyAppInfo(appInfoDocument.RootElement);
                NativeTrace.Write($"app.getInfo succeeded. Version='{Shell.VersionText}' UserDataDir='{Shell.UserDataDirectory}'");
            }

            await RefreshLibraryAsync(cancellationToken);

            try
            {
                await _workspaceService.InitializeAsync(cancellationToken);
                RestoredNavigationTag = _workspaceService.GetCurrentTab();
                Shell.ApplySelectedFolder(_workspaceService.GetCurrentLibraryFolderId());
                Shell.ApplyWorkspaceSelection(_workspaceService.GetWorkspaceCorpusIds());
                NativeTrace.Write(
                    $"workspace scope restored. SelectedFolderId='{Shell.SelectedFolderId}' SelectedFolderLabel='{Shell.SelectedFolderLabel}'"
                );
                NativeTrace.Write($"workspace.getState succeeded. RestoredNavigationTag='{RestoredNavigationTag}'");
            }
            catch (Exception workspaceException)
            {
                RestoredNavigationTag = "library";
                NativeTrace.WriteException("workspace.getState failed", workspaceException);
            }

            var updateState = await _updateService.CheckForUpdatesAsync(cancellationToken);
            Shell.BuildSummary = updateState.Supported
                ? "WinUI 3 shell with Node.js sidecar and MSIX updates."
                : "WinUI 3 shell with Node.js sidecar. MSIX update wiring is staged next.";
            Shell.EngineStatus = $"Connected to the WordZ engine via {Path.GetFileName(_engineClient.ResolvedNodePath) ?? "node.exe"}.";
            Shell.EngineSeverity = InfoBarSeverity.Success;
            Shell.IsConnected = true;
            Shell.RuntimeSummary = BuildRuntimeSummary();
            NativeTrace.Write($"MainWindowViewModel InitializeAsync complete. EngineStatus='{Shell.EngineStatus}'");
        }
        catch (Exception exception)
        {
            NativeTrace.WriteException("MainWindowViewModel InitializeAsync failed", exception);
            Shell.EngineStatus = $"Failed to start the WordZ engine: {exception.Message}";
            Shell.EngineSeverity = InfoBarSeverity.Error;
            Shell.WorkspaceSummary = "Check the Node.js installation, the mirrored engine files, and the %APPDATA%\\WordZ user-data directory.";
            Shell.RuntimeSummary = BuildRuntimeSummary();
        }
        finally
        {
            Shell.IsBusy = false;
        }
    }

    private void ApplyAppInfo(JsonElement payload)
    {
        var resultElement = GetResultElement(payload);
        if (!resultElement.TryGetProperty("appInfo", out var appInfoElement))
        {
            return;
        }

        var name = ReadString(appInfoElement, "name", "WordZ");
        var version = ReadString(appInfoElement, "version", string.Empty);
        var userDataDir = ReadString(appInfoElement, "userDataDir", _nativeShellService.GetUserDataDirectory());
        var releaseNotesCount = appInfoElement.TryGetProperty("releaseNotes", out var releaseNotesElement)
            && releaseNotesElement.ValueKind == JsonValueKind.Array
                ? releaseNotesElement.GetArrayLength()
                : 0;

        Shell.WindowTitle = string.IsNullOrWhiteSpace(name) ? "WordZ" : name;
        Shell.VersionText = string.IsNullOrWhiteSpace(version) ? "Windows Native Preview" : $"Version {version}";
        Shell.UserDataDirectory = userDataDir;
        Shell.WorkspaceSummary = $"WordZ user data is rooted at {userDataDir}.";
        Shell.BuildSummary = releaseNotesCount > 0
            ? $"WinUI 3 shell with Node.js sidecar. {releaseNotesCount} release-note highlights are available from the shared manifest."
            : "WinUI 3 shell with Node.js sidecar.";
    }

    public async Task RefreshLibraryAsync(CancellationToken cancellationToken = default)
    {
        var previousSelectedFolderId = Shell.SelectedFolderId;
        var snapshot = await _libraryService.LoadLibraryAsync("all", cancellationToken);
        Shell.ApplyLibrarySnapshot(snapshot.Folders, snapshot.Items, snapshot.SelectedFolderId);
        Shell.ApplySelectedFolder(previousSelectedFolderId);
        NativeTrace.Write(
            $"library.list succeeded. FolderCount={Shell.FolderCount} TotalCorpusCount={Shell.TotalCorpusCount} SelectedFolder='{Shell.SelectedFolderLabel}'"
        );
    }

    private void HandleNotificationReceived(object? sender, EngineNotificationEventArgs eventArgs)
    {
        RunOnUiThread(() =>
        {
            if (eventArgs.Method.StartsWith("task.", StringComparison.Ordinal))
            {
                Shell.EngineStatus = $"Engine event received: {eventArgs.Method}";
                Shell.EngineSeverity = InfoBarSeverity.Informational;
                return;
            }

            if (eventArgs.Method == "diagnostics.log")
            {
                Shell.EngineStatus = "Engine diagnostics log received.";
                Shell.EngineSeverity = InfoBarSeverity.Informational;
            }
        });
    }

    private void HandleEngineErrorReceived(object? sender, string message)
    {
        RunOnUiThread(() =>
        {
            Shell.EngineStatus = $"Engine stderr: {message}";
            if (!Shell.IsConnected)
            {
                Shell.EngineSeverity = InfoBarSeverity.Error;
            }
        });
    }

    private void RunOnUiThread(Action action)
    {
        if (_dispatcherQueue.HasThreadAccess)
        {
            action();
            return;
        }

        _dispatcherQueue.TryEnqueue(() => action());
    }

    private string BuildRuntimeSummary()
    {
        var nodePath = string.IsNullOrWhiteSpace(_engineClient.ResolvedNodePath)
            ? "Node unresolved"
            : _engineClient.ResolvedNodePath;
        var engineEntry = string.IsNullOrWhiteSpace(_engineClient.ResolvedEngineEntryPath)
            ? "Engine entry unresolved"
            : _engineClient.ResolvedEngineEntryPath;

        return $"Node: {nodePath} | Engine: {engineEntry}";
    }

    private static JsonElement GetResultElement(JsonElement payload)
    {
        if (payload.TryGetProperty("error", out var errorElement))
        {
            throw new InvalidOperationException(ReadRpcError(errorElement));
        }

        if (!payload.TryGetProperty("result", out var resultElement))
        {
            throw new InvalidOperationException("The engine response did not contain a result payload.");
        }

        if (resultElement.TryGetProperty("success", out var successElement)
            && successElement.ValueKind == JsonValueKind.False)
        {
            throw new InvalidOperationException(ReadString(resultElement, "message", "The engine returned an unsuccessful result."));
        }

        return resultElement;
    }

    private static string ReadRpcError(JsonElement errorElement)
    {
        var message = ReadString(errorElement, "message", "An unknown JSON-RPC error occurred.");
        if (errorElement.TryGetProperty("code", out var codeElement))
        {
            return $"[{codeElement.GetRawText()}] {message}";
        }

        return message;
    }

    private static string ReadString(JsonElement element, string propertyName, string fallback)
    {
        if (!element.TryGetProperty(propertyName, out var propertyElement))
        {
            return fallback;
        }

        return propertyElement.ValueKind == JsonValueKind.String
            ? propertyElement.GetString() ?? fallback
            : propertyElement.GetRawText();
    }

    public ShellProbeResult CreateProbeResult()
    {
        return new ShellProbeResult
        {
            Connected = Shell.IsConnected,
            WindowTitle = Shell.WindowTitle,
            VersionText = Shell.VersionText,
            EngineStatus = Shell.EngineStatus,
            WorkspaceSummary = Shell.WorkspaceSummary,
            UserDataDirectory = Shell.UserDataDirectory,
            SelectedFolderLabel = Shell.SelectedFolderLabel,
            FolderCount = Shell.FolderCount,
            TotalCorpusCount = Shell.TotalCorpusCount,
            RuntimeSummary = Shell.RuntimeSummary
        };
    }

    public Task SaveCurrentTabAsync(string tag, CancellationToken cancellationToken = default)
    {
        return _workspaceService.SaveCurrentTabAsync(tag, cancellationToken);
    }

    public async Task SetSelectedFolderAsync(string folderId, CancellationToken cancellationToken = default)
    {
        Shell.ApplySelectedFolder(folderId);
        await _workspaceService.SaveCurrentLibraryFolderIdAsync(Shell.SelectedFolderId, cancellationToken);
        NativeTrace.Write(
            $"Current library folder updated. SelectedFolderId='{Shell.SelectedFolderId}' SelectedFolderLabel='{Shell.SelectedFolderLabel}'"
        );
    }

    public async Task SaveWorkspaceSelectionAsync(CancellationToken cancellationToken = default)
    {
        var workspaceItems = Shell.GetWorkspaceItems();
        await _workspaceService.SaveWorkspaceSelectionAsync(
            workspaceItems.Select(item => item.Id).ToArray(),
            workspaceItems.Select(item => item.Name).ToArray(),
            cancellationToken
        );
        NativeTrace.Write($"Workspace corpus selection saved. CorpusCount={workspaceItems.Count}");
    }

    public async ValueTask DisposeAsync()
    {
        _engineClient.NotificationReceived -= HandleNotificationReceived;
        _engineClient.EngineErrorReceived -= HandleEngineErrorReceived;
        await _engineClient.DisposeAsync();
    }
}
