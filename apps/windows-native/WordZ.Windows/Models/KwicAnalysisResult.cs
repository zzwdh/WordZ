namespace WordZ.Windows.Models;

public sealed class KwicAnalysisResult
{
    public string ScopeLabel { get; init; } = "All local corpora";

    public int CorpusCount { get; init; }

    public int HitCount { get; init; }

    public IReadOnlyList<KwicResultRow> Rows { get; init; } = Array.Empty<KwicResultRow>();
}
