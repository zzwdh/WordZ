namespace WordZ.Windows.Models;

public sealed class LocatorNavigationRequest
{
    public string CorpusId { get; init; } = string.Empty;

    public string CorpusName { get; init; } = string.Empty;

    public string FolderId { get; init; } = string.Empty;

    public string FolderName { get; init; } = string.Empty;

    public string Keyword { get; init; } = string.Empty;

    public int SentenceId { get; init; }

    public int NodeIndex { get; init; }

    public int LeftWindowSize { get; init; } = 5;

    public int RightWindowSize { get; init; } = 5;
}
