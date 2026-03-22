namespace WordZ.Windows.Models;

public sealed class LocatorResultRow
{
    public int SentenceId { get; init; }

    public string LeftWords { get; init; } = string.Empty;

    public string NodeWord { get; init; } = string.Empty;

    public string RightWords { get; init; } = string.Empty;

    public string Text { get; init; } = string.Empty;

    public string Status { get; init; } = string.Empty;

    public bool IsTarget => !string.IsNullOrWhiteSpace(Status);
}
