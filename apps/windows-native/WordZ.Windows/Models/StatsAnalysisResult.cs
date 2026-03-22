namespace WordZ.Windows.Models;

public sealed class StatsAnalysisResult
{
    public string ScopeLabel { get; init; } = "All local corpora";

    public int CorpusCount { get; init; }

    public int TokenCount { get; init; }

    public int TypeCount { get; init; }

    public double Ttr { get; init; }

    public double Sttr { get; init; }

    public IReadOnlyList<StatsFrequencyRow> FrequencyRows { get; init; } = Array.Empty<StatsFrequencyRow>();

    public IReadOnlyList<CorpusComparisonSummary> CorpusSummaries { get; init; } = Array.Empty<CorpusComparisonSummary>();
}
