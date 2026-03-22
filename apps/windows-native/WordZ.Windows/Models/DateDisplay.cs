namespace WordZ.Windows.Models;

internal static class DateDisplay
{
    public static string FormatIsoTimestamp(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return "Time unavailable";
        }

        return DateTimeOffset.TryParse(value, out var parsed)
            ? parsed.ToLocalTime().ToString("yyyy-MM-dd HH:mm")
            : value;
    }
}
