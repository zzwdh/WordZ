namespace WordZ.Windows.Models;

public sealed class LocatorAnalysisResult
{
    public string CorpusName { get; init; } = string.Empty;

    public string FolderName { get; init; } = string.Empty;

    public string Keyword { get; init; } = string.Empty;

    public int SentenceId { get; init; }

    public int NodeIndex { get; init; }

    public int SentenceCount { get; init; }

    public IReadOnlyList<LocatorResultRow> Rows { get; init; } = Array.Empty<LocatorResultRow>();
}
