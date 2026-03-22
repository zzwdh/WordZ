namespace WordZ.Windows.Models;

public sealed class LibraryOpenCorpusResult
{
    public string CorpusId { get; init; } = string.Empty;

    public string DisplayName { get; init; } = string.Empty;

    public string FolderId { get; init; } = string.Empty;

    public string FolderName { get; init; } = string.Empty;

    public string SourceType { get; init; } = string.Empty;

    public string FilePath { get; init; } = string.Empty;

    public string Content { get; init; } = string.Empty;
}
