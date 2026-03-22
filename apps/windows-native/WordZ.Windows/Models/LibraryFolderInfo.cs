namespace WordZ.Windows.Models;

public sealed class LibraryFolderInfo
{
    public string Id { get; init; } = string.Empty;
    public string Name { get; init; } = string.Empty;
    public string UpdatedAt { get; init; } = string.Empty;
    public int ItemCount { get; init; }
    public bool IsSystem { get; init; }
    public bool CanRename { get; init; }
    public bool CanDelete { get; init; }

    public string UpdatedAtDisplay => DateDisplay.FormatIsoTimestamp(UpdatedAt);

    public string Subtitle
    {
        get
        {
            var countLabel = ItemCount == 1 ? "1 corpus" : $"{ItemCount} corpora";
            if (IsSystem)
            {
                return $"{countLabel} | System folder";
            }

            return $"{countLabel} | Updated {UpdatedAtDisplay}";
        }
    }
}
