namespace WordZ.Windows.Services;

public sealed class NativeShellService
{
    public string GetUserDataDirectory()
    {
        var appDataDirectory = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
        return Path.Combine(appDataDirectory, "WordZ");
    }

    public Task<bool> ShowInExplorerAsync(string targetPath, CancellationToken cancellationToken = default)
    {
        cancellationToken.ThrowIfCancellationRequested();
        return Task.FromResult(File.Exists(targetPath) || Directory.Exists(targetPath));
    }
}
