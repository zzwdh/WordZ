using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using WordZ.Windows.Models;
using WordZ.Windows.Services;

namespace WordZ.Windows.ViewModels;

public sealed partial class CollocatePageViewModel : ObservableObject
    , IWorkspacePersistable
{
    private readonly NativeAnalysisService _analysisService;
    private readonly NativeWorkspaceService _workspaceService;

    public CollocatePageViewModel(
        NativeShellState shell,
        NativeAnalysisService analysisService,
        NativeWorkspaceService workspaceService)
    {
        Shell = shell;
        _analysisService = analysisService;
        _workspaceService = workspaceService;
        ScopeOptions = new ObservableCollection<AnalysisScopeOption>(_analysisService.BuildScopeOptions());
        Query = _workspaceService.GetSearchQuery();
        SelectedScope = ResolveScope(_workspaceService.GetCollocateScopeId());
        WindowSize = _workspaceService.GetCollocateWindow();
        MinimumFrequency = _workspaceService.GetCollocateMinimumFrequency();
        RunAnalysisCommand = new AsyncRelayCommand(RunAnalysisAsync, () => !IsRunning);

        if (Shell.IsConnected && Shell.TotalCorpusCount > 0 && !string.IsNullOrWhiteSpace(Query))
        {
            _ = RunAnalysisAsync();
        }
    }

    public NativeShellState Shell { get; }

    public ObservableCollection<AnalysisScopeOption> ScopeOptions { get; }

    public ObservableCollection<CollocateResultRow> Rows { get; } = new();

    public IAsyncRelayCommand RunAnalysisCommand { get; }

    [ObservableProperty]
    private string _query = string.Empty;

    [ObservableProperty]
    private AnalysisScopeOption? _selectedScope;

    [ObservableProperty]
    private string _windowSize = "5";

    [ObservableProperty]
    private string _minimumFrequency = "2";

    [ObservableProperty]
    private bool _isRunning;

    [ObservableProperty]
    private string _statusText = "Enter a node word and run Collocate.";

    [ObservableProperty]
    private string _resultSummary = "No collocate results yet.";

    public string StageSummary => string.IsNullOrWhiteSpace(StatusText)
        ? "The Collocate page is ready."
        : StatusText;

    partial void OnIsRunningChanged(bool value)
    {
        RunAnalysisCommand.NotifyCanExecuteChanged();
    }

    private async Task RunAnalysisAsync()
    {
        if (IsRunning)
        {
            return;
        }

        IsRunning = true;
        StatusText = "Running Collocate through the shared analysis task runner...";

        try
        {
            await SaveWorkspaceStateAsync();
            var result = await _analysisService.RunCollocateAsync(
                SelectedScope,
                Query,
                WindowSize,
                MinimumFrequency
            );

            ReplaceCollection(Rows, result.Rows);
            ResultSummary = $"Found {result.RowCount} collocates across {result.CorpusCount} corpus/corpora in {result.ScopeLabel}.";
            StatusText = result.RowCount == 0
                ? "Collocate completed but no results matched the current threshold."
                : "Collocate results are ready.";
        }
        catch (Exception exception)
        {
            StatusText = $"Collocate failed: {exception.Message}";
        }
        finally
        {
            IsRunning = false;
        }
    }

    public Task SaveWorkspaceStateAsync(CancellationToken cancellationToken = default)
    {
        return _workspaceService.SaveCollocateStateAsync(
            Query,
            SelectedScope?.Id ?? "current",
            WindowSize,
            MinimumFrequency,
            cancellationToken
        );
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
}
