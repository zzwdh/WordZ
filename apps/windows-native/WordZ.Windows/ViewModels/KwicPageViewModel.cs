using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using WordZ.Windows.Models;
using WordZ.Windows.Services;

namespace WordZ.Windows.ViewModels;

public sealed partial class KwicPageViewModel : ObservableObject
    , IWorkspacePersistable
{
    private readonly NativeAnalysisService _analysisService;
    private readonly Func<LocatorNavigationRequest, Task> _navigateToLocatorAsync;
    private readonly NativeWorkspaceService _workspaceService;

    public KwicPageViewModel(
        NativeShellState shell,
        NativeAnalysisService analysisService,
        NativeWorkspaceService workspaceService,
        Func<LocatorNavigationRequest, Task> navigateToLocatorAsync)
    {
        Shell = shell;
        _analysisService = analysisService;
        _workspaceService = workspaceService;
        _navigateToLocatorAsync = navigateToLocatorAsync;
        ScopeOptions = new ObservableCollection<AnalysisScopeOption>(_analysisService.BuildScopeOptions());
        Query = _workspaceService.GetSearchQuery();
        SelectedScope = ResolveScope(_workspaceService.GetKwicScopeId());
        SelectedSortMode = _workspaceService.GetKwicSortMode();
        LeftContextSize = _workspaceService.GetKwicLeftWindow();
        RightContextSize = _workspaceService.GetKwicRightWindow();
        RunSearchCommand = new AsyncRelayCommand(RunSearchAsync, () => !IsRunning);

        if (Shell.IsConnected && Shell.TotalCorpusCount > 0 && !string.IsNullOrWhiteSpace(Query))
        {
            _ = RunSearchAsync();
        }
    }

    public NativeShellState Shell { get; }

    public ObservableCollection<AnalysisScopeOption> ScopeOptions { get; }

    public ObservableCollection<KwicResultRow> Rows { get; } = new();

    public IReadOnlyList<string> SortModeOptions { get; } = new[]
    {
        "original",
        "left-near",
        "right-near",
        "left-then-right",
        "right-then-left"
    };

    public IAsyncRelayCommand RunSearchCommand { get; }

    [ObservableProperty]
    private string _query = string.Empty;

    [ObservableProperty]
    private AnalysisScopeOption? _selectedScope;

    [ObservableProperty]
    private string _selectedSortMode = "original";

    [ObservableProperty]
    private string _leftContextSize = "5";

    [ObservableProperty]
    private string _rightContextSize = "5";

    [ObservableProperty]
    private bool _isRunning;

    [ObservableProperty]
    private string _statusText = "Enter a keyword and run KWIC.";

    [ObservableProperty]
    private string _resultSummary = "No KWIC results yet.";

    public string StageSummary => string.IsNullOrWhiteSpace(StatusText)
        ? "The KWIC page is ready."
        : StatusText;

    partial void OnIsRunningChanged(bool value)
    {
        RunSearchCommand.NotifyCanExecuteChanged();
    }

    private async Task RunSearchAsync()
    {
        if (IsRunning)
        {
            return;
        }

        IsRunning = true;
        StatusText = "Running KWIC through the shared analysis task runner...";

        try
        {
            await SaveWorkspaceStateAsync();
            var result = await _analysisService.RunKwicAsync(
                SelectedScope,
                Query,
                LeftContextSize,
                RightContextSize,
                SelectedSortMode
            );

            ReplaceCollection(Rows, result.Rows);
            ResultSummary = $"Found {result.HitCount} KWIC matches across {result.CorpusCount} corpus/corpora in {result.ScopeLabel}.";
            StatusText = result.HitCount == 0
                ? "KWIC completed but no matches were found."
                : "KWIC results are ready.";
        }
        catch (Exception exception)
        {
            StatusText = $"KWIC failed: {exception.Message}";
        }
        finally
        {
            IsRunning = false;
        }
    }

    public Task SaveWorkspaceStateAsync(CancellationToken cancellationToken = default)
    {
        return _workspaceService.SaveKwicStateAsync(
            Query,
            SelectedScope?.Id ?? "current",
            SelectedSortMode,
            LeftContextSize,
            RightContextSize,
            cancellationToken
        );
    }

    public async Task OpenInLocatorAsync(KwicResultRow? row)
    {
        if (row is null)
        {
            return;
        }

        await _navigateToLocatorAsync(new LocatorNavigationRequest
        {
            CorpusId = row.CorpusId,
            CorpusName = row.CorpusName,
            FolderId = row.FolderId,
            FolderName = row.FolderName,
            Keyword = Query,
            SentenceId = row.SentenceId,
            NodeIndex = row.SentenceTokenIndex,
            LeftWindowSize = ParseWindowOrDefault(LeftContextSize),
            RightWindowSize = ParseWindowOrDefault(RightContextSize)
        });
    }

    private static void ReplaceCollection<T>(ObservableCollection<T> target, IEnumerable<T> source)
    {
        target.Clear();
        foreach (var item in source)
        {
            target.Add(item);
        }
    }

    private AnalysisScopeOption? ResolveScope(string scopeId)
    {
        return ScopeOptions.FirstOrDefault(option => string.Equals(option.Id, scopeId, StringComparison.OrdinalIgnoreCase))
            ?? ScopeOptions.FirstOrDefault();
    }

    private static int ParseWindowOrDefault(string rawValue)
    {
        return int.TryParse(rawValue, out var parsed) && parsed > 0 ? parsed : 5;
    }
}
