namespace WordZ.Windows.Models;

public sealed class AnalysisScopeOption
{
    public string Id { get; init; } = "all";

    public string Label { get; init; } = "All local corpora";

    public override string ToString()
    {
        return Label;
    }
}
