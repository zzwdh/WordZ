namespace WordZ.Windows.Models;

public sealed class CorpusComparisonSummary
{
    public string CorpusName { get; init; } = string.Empty;

    public string FolderName { get; init; } = string.Empty;

    public int TokenCount { get; init; }

    public int TypeCount { get; init; }

    public double Ttr { get; init; }

    public double Sttr { get; init; }

    public string TopWord { get; init; } = string.Empty;

    public int TopWordCount { get; init; }

    public string Summary => string.IsNullOrWhiteSpace(TopWord)
        ? $"{TokenCount} tokens | {TypeCount} types"
        : $"{TokenCount} tokens | {TypeCount} types | Top word: {TopWord} ({TopWordCount})";
}
