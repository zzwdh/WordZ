namespace WordZ.Windows.Models;

public sealed class LibrarySnapshotResult
{
    public string SelectedFolderId { get; init; } = "all";

    public IReadOnlyList<LibraryFolderInfo> Folders { get; init; } = Array.Empty<LibraryFolderInfo>();

    public IReadOnlyList<LibraryCorpusInfo> Items { get; init; } = Array.Empty<LibraryCorpusInfo>();
}
