namespace WordZ.Windows.Models;

public sealed class CollocateResultRow
{
    public int Rank { get; init; }

    public string Word { get; init; } = string.Empty;

    public int Total { get; init; }

    public int Left { get; init; }

    public int Right { get; init; }

    public double Rate { get; init; }

    public string RateDisplay => Rate.ToString("0.###");
}
