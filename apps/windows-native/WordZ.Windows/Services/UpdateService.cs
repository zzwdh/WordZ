namespace WordZ.Windows.Services;

public sealed class UpdateService
{
    public Task<(bool Supported, string Message)> CheckForUpdatesAsync(CancellationToken cancellationToken = default)
    {
        cancellationToken.ThrowIfCancellationRequested();
        return Task.FromResult((false, "MSIX update integration is staged for a later milestone."));
    }
}
