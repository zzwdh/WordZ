using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using WordZ.Windows.Models;
using WordZ.Windows.Services;

namespace WordZ.Windows.ViewModels;

public sealed partial class LocatorPageViewModel : ObservableObject, IWorkspacePersistable
{
    private readonly NativeAnalysisService _analysisService;
    private readonly NativeWorkspaceService _workspaceService;
    private LocatorNavigationRequest? _currentRequest;

    public LocatorPageViewModel(
        NativeShellState shell,
        NativeAnalysisService analysisService,
        NativeWorkspaceService workspaceService)
    {
        Shell = shell;
        _analysisService = analysisService;
        _workspaceService = workspaceService;
        LeftContextSize = _workspaceService.GetLocatorLeftWindow();
        RightContextSize = _workspaceService.GetLocatorRightWindow();
        RunLocatorCommand = new AsyncRelayCommand(RunLocatorAsync, CanRunLocator);

        var restoredCorpusId = _workspaceService.GetLocatorCorpusId();
        if (!string.IsNullOrWhiteSpace(restoredCorpusId))
        {
            _currentRequest = new LocatorNavigationRequest
            {
                CorpusId = restoredCorpusId,
                CorpusName = _workspaceService.GetLocatorCorpusName(),
                FolderName = _workspaceService.GetLocatorFolderName(),
                Keyword = _workspaceService.GetLocatorKeyword(),
                SentenceId = _workspaceService.GetLocatorSentenceId(),
                NodeIndex = _workspaceService.GetLocatorNodeIndex(),
                LeftWindowSize = ParseWindowOrDefault(LeftContextSize),
                RightWindowSize = ParseWindowOrDefault(RightContextSize)
            };
            CorpusTitle = _currentRequest.CorpusName;
            FolderTitle = _currentRequest.FolderName;
            Keyword = _currentRequest.Keyword;
            TargetSummary = BuildTargetSummary(_currentRequest);
            RunLocatorCommand.NotifyCanExecuteChanged();

            if (Shell.IsConnected && Shell.TotalCorpusCount > 0)
            {
                _ = RunLocatorAsync();
            }
        }
    }

    public NativeShellState Shell { get; }

    public ObservableCollection<LocatorResultRow> Rows { get; } = new();

    public IAsyncRelayCommand RunLocatorCommand { get; }

    [ObservableProperty]
    private string _corpusTitle = "No corpus selected";

    [ObservableProperty]
    private string _folderTitle = string.Empty;

    [ObservableProperty]
    private string _keyword = string.Empty;

    [ObservableProperty]
    private string _leftContextSize = "5";

    [ObservableProperty]
    private string _rightContextSize = "5";

    [ObservableProperty]
    private string _targetSummary = "Choose a KWIC row to inspect the original sentence context.";

    [ObservableProperty]
    private string _statusText = "Locator is waiting for a KWIC selection.";

    [ObservableProperty]
    private string _resultSummary = "No locator result loaded yet.";

    [ObservableProperty]
    private bool _isRunning;

    partial void OnIsRunningChanged(bool value)
    {
        RunLocatorCommand.NotifyCanExecuteChanged();
    }

    public async Task LoadRequestAsync(LocatorNavigationRequest request)
    {
        _currentRequest = request;
        CorpusTitle = string.IsNullOrWhiteSpace(request.CorpusName) ? "Selected corpus" : request.CorpusName;
        FolderTitle = request.FolderName;
        Keyword = request.Keyword;
        LeftContextSize = request.LeftWindowSize.ToString();
        RightContextSize = request.RightWindowSize.ToString();
        TargetSummary = BuildTargetSummary(request);
        RunLocatorCommand.NotifyCanExecuteChanged();
        await RunLocatorAsync();
    }

    public async Task RunLocatorAsync()
    {
        if (IsRunning || _currentRequest is null)
        {
            return;
        }

        IsRunning = true;
        StatusText = "Locating the selected hit inside the saved corpus...";

        try
        {
            _currentRequest = new LocatorNavigationRequest
            {
                CorpusId = _currentRequest.CorpusId,
                CorpusName = _currentRequest.CorpusName,
                FolderId = _currentRequest.FolderId,
                FolderName = _currentRequest.FolderName,
                Keyword = _currentRequest.Keyword,
                SentenceId = _currentRequest.SentenceId,
                NodeIndex = _currentRequest.NodeIndex,
                LeftWindowSize = ParseWindowOrDefault(LeftContextSize),
                RightWindowSize = ParseWindowOrDefault(RightContextSize)
            };

            var result = await _analysisService.RunLocatorAsync(
                _currentRequest,
                LeftContextSize,
                RightContextSize
            );

            ReplaceCollection(Rows, result.Rows);
            CorpusTitle = result.CorpusName;
            FolderTitle = result.FolderName;
            Keyword = result.Keyword;
            ResultSummary = $"Loaded {result.SentenceCount} sentence row(s) from {result.CorpusName}.";
            StatusText = result.Rows.Count == 0
                ? "Locator completed but no sentence rows were returned."
                : "Locator is focused on the selected KWIC hit.";
            await SaveWorkspaceStateAsync();
        }
        catch (Exception exception)
        {
            StatusText = $"Locator failed: {exception.Message}";
        }
        finally
        {
            IsRunning = false;
        }
    }

    public Task SaveWorkspaceStateAsync(CancellationToken cancellationToken = default)
    {
        return _workspaceService.SaveLocatorStateAsync(
            _currentRequest?.CorpusId ?? string.Empty,
            CorpusTitle,
            FolderTitle,
            Keyword,
            _currentRequest?.SentenceId ?? 0,
            _currentRequest?.NodeIndex ?? 0,
            LeftContextSize,
            RightContextSize,
            cancellationToken
        );
    }

    private bool CanRunLocator()
    {
        return !IsRunning && _currentRequest is not null;
    }

    private static void ReplaceCollection<T>(ObservableCollection<T> target, IEnumerable<T> source)
    {
        target.Clear();
        foreach (var item in source)
        {
            target.Add(item);
        }
    }

    private static string BuildTargetSummary(LocatorNavigationRequest request)
    {
        return $"Target sentence #{request.SentenceId}, token index {request.NodeIndex}, keyword '{request.Keyword}'.";
    }

    private static int ParseWindowOrDefault(string rawValue)
    {
        return int.TryParse(rawValue, out var parsed) && parsed > 0 ? parsed : 5;
    }
}
