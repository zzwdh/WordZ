using CommunityToolkit.Mvvm.ComponentModel;
using System.IO;

namespace WordZ.Windows.Models;

public sealed partial class LibraryCorpusInfo : ObservableObject
{
    public string Id { get; init; } = string.Empty;
    public string Name { get; init; } = string.Empty;
    public string FolderId { get; init; } = string.Empty;
    public string FolderName { get; init; } = string.Empty;
    public string SourceType { get; init; } = string.Empty;
    public string OriginalName { get; init; } = string.Empty;
    public string FilePath { get; init; } = string.Empty;
    public string UpdatedAt { get; init; } = string.Empty;

    [ObservableProperty]
    private bool _isInWorkspace;

    public string SourceTypeLabel => string.IsNullOrWhiteSpace(SourceType)
        ? "TXT"
        : SourceType.ToUpperInvariant();

    public string UpdatedAtDisplay => DateDisplay.FormatIsoTimestamp(UpdatedAt);

    public string Subtitle
    {
        get
        {
            var sourceName = string.IsNullOrWhiteSpace(OriginalName)
                ? Path.GetFileName(FilePath)
                : OriginalName;
            return string.IsNullOrWhiteSpace(sourceName)
                ? FolderName
                : $"{FolderName} | {sourceName}";
        }
    }
}
