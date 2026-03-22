namespace WordZ.Windows.Models;

public sealed class KwicResultRow
{
    public int Rank { get; init; }

    public string CorpusId { get; init; } = string.Empty;

    public string CorpusName { get; init; } = string.Empty;

    public string FolderId { get; init; } = string.Empty;

    public string FolderName { get; init; } = string.Empty;

    public string SourceType { get; init; } = string.Empty;

    public string Left { get; init; } = string.Empty;

    public string Node { get; init; } = string.Empty;

    public string Right { get; init; } = string.Empty;

    public int SentenceId { get; init; }

    public int SentenceTokenIndex { get; init; }

    public int OriginalIndex { get; init; }

    public string CorpusLabel => string.IsNullOrWhiteSpace(FolderName)
        ? CorpusName
        : $"{CorpusName} / {FolderName}";

    public string ContextLine => $"{Left} [{Node}] {Right}".Trim();
}
