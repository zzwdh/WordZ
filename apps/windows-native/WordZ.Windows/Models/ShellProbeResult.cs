namespace WordZ.Windows.Models;

public sealed class ShellProbeResult
{
    public bool Connected { get; init; }
    public string WindowTitle { get; init; } = string.Empty;
    public string VersionText { get; init; } = string.Empty;
    public string EngineStatus { get; init; } = string.Empty;
    public string WorkspaceSummary { get; init; } = string.Empty;
    public string UserDataDirectory { get; init; } = string.Empty;
    public string SelectedFolderLabel { get; init; } = string.Empty;
    public int FolderCount { get; init; }
    public int TotalCorpusCount { get; init; }
    public string RuntimeSummary { get; init; } = string.Empty;
}
