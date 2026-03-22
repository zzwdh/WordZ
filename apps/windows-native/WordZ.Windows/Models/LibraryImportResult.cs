namespace WordZ.Windows.Models;

public sealed class LibraryImportResult
{
    public int ImportedCount { get; init; }

    public int SkippedCount { get; init; }

    public IReadOnlyList<LibraryCorpusInfo> ImportedItems { get; init; } = Array.Empty<LibraryCorpusInfo>();
}
