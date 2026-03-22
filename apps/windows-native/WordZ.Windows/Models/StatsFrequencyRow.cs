namespace WordZ.Windows.Models;

public sealed class StatsFrequencyRow
{
    public int Rank { get; init; }

    public string Word { get; init; } = string.Empty;

    public int Count { get; init; }
}
