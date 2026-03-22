namespace WordZ.Windows.Services;

public sealed class UpdateService
{
    public Task<(bool Supported, string Message)> CheckForUpdatesAsync(CancellationToken cancellationToken = default)
    {
        cancellationToken.ThrowIfCancellationRequested();
        return Task.FromResult((false, "MSIX 更新链尚未接入。"));
    }
}
