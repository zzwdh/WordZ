namespace WordZ.Windows.Models;

public sealed class CollocateAnalysisResult
{
    public string ScopeLabel { get; init; } = "All local corpora";

    public int CorpusCount { get; init; }

    public int RowCount { get; init; }

    public IReadOnlyList<CollocateResultRow> Rows { get; init; } = Array.Empty<CollocateResultRow>();
}
