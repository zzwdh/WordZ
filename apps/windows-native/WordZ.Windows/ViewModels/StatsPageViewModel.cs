using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using WordZ.Windows.Models;
using WordZ.Windows.Services;

namespace WordZ.Windows.ViewModels;

public sealed partial class StatsPageViewModel : ObservableObject
    , IWorkspacePersistable
{
    private readonly NativeAnalysisService _analysisService;
    private readonly NativeWorkspaceService _workspaceService;

    public StatsPageViewModel(
        NativeShellState shell,
        NativeAnalysisService analysisService,
        NativeWorkspaceService workspaceService)
    {
        Shell = shell;
        _analysisService = analysisService;
        _workspaceService = workspaceService;
        ScopeOptions = new ObservableCollection<AnalysisScopeOption>(_analysisService.BuildScopeOptions());
        SelectedScope = ResolveScope(_workspaceService.GetStatsScopeId());
        SelectedProfile = _workspaceService.GetStatsProfile();
        Notes = _workspaceService.GetStatsNotes();
        RunAnalysisCommand = new AsyncRelayCommand(RunAnalysisAsync, () => !IsRunning);

        if (Shell.IsConnected && Shell.TotalCorpusCount > 0)
        {
            _ = RunAnalysisAsync();
        }
    }

    public NativeShellState Shell { get; }

    public ObservableCollection<AnalysisScopeOption> ScopeOptions { get; }

    public ObservableCollection<StatsFrequencyRow> FrequencyRows { get; } = new();

    public ObservableCollection<CorpusComparisonSummary> CorpusSummaries { get; } = new();

    public IReadOnlyList<string> ProfileOptions { get; } = new[]
    {
        "Frequencies / lengths / overview",
        "Type-token ratios",
        "Vocabulary prep"
    };

    public IAsyncRelayCommand RunAnalysisCommand { get; }

    [ObservableProperty]
    private AnalysisScopeOption? _selectedScope;

    [ObservableProperty]
    private string _selectedProfile = "Frequencies / lengths / overview";

    [ObservableProperty]
    private string _notes = string.Empty;

    [ObservableProperty]
    private bool _isRunning;

    [ObservableProperty]
    private string _statusText = "Run statistics to load the first native analysis result.";

    [ObservableProperty]
    private string _resultSummary = "No statistics have been run yet.";

    [ObservableProperty]
    private int _corpusCount;

    [ObservableProperty]
    private int _tokenCount;

    [ObservableProperty]
    private int _typeCount;

    [ObservableProperty]
    private string _ttrDisplay = "0.000";

    [ObservableProperty]
    private string _sttrDisplay = "0.000";

    public string StageSummary => string.IsNullOrWhiteSpace(StatusText)
        ? "The statistics page is ready."
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
        StatusText = "Running the statistics task through the Node sidecar...";

        try
        {
            await SaveWorkspaceStateAsync();
            var result = await _analysisService.RunStatsAsync(SelectedScope);
            CorpusCount = result.CorpusCount;
            TokenCount = result.TokenCount;
            TypeCount = result.TypeCount;
            TtrDisplay = result.Ttr.ToString("0.000");
            SttrDisplay = result.Sttr.ToString("0.000");
            ReplaceCollection(FrequencyRows, result.FrequencyRows);
            ReplaceCollection(CorpusSummaries, result.CorpusSummaries);
            ResultSummary = $"Loaded {result.TokenCount} tokens and {result.TypeCount} types from {result.CorpusCount} corpus/corpora in {result.ScopeLabel}.";
            StatusText = result.CorpusSummaries.Count > 1
                ? "Statistics and comparison summaries are ready."
                : "Statistics are ready.";
        }
        catch (Exception exception)
        {
            StatusText = $"Statistics failed: {exception.Message}";
        }
        finally
        {
            IsRunning = false;
        }
    }

    public Task SaveWorkspaceStateAsync(CancellationToken cancellationToken = default)
    {
        return _workspaceService.SaveStatsStateAsync(
            SelectedScope?.Id ?? "all",
            SelectedProfile,
            Notes,
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
