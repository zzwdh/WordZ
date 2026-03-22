using System.Text;

namespace WordZ.Windows.Services;

internal static class NativeTrace
{
    private static readonly object Sync = new();
    private static readonly string LogPath = Path.Combine(
        Path.GetTempPath(),
        "wordz-windows-native.log"
    );

    public static string CurrentLogPath => LogPath;

    public static void Write(string message)
    {
        try
        {
            lock (Sync)
            {
                var line = $"[{DateTimeOffset.Now:O}] {message}{Environment.NewLine}";
                File.AppendAllText(LogPath, line, Encoding.UTF8);
            }
        }
        catch
        {
            // Swallow logging errors to keep diagnostics side-effect free.
        }
    }

    public static void WriteException(string context, Exception exception)
    {
        Write($"{context}: {exception}");
    }
}
