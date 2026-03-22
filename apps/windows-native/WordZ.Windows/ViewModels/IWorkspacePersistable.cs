namespace WordZ.Windows.ViewModels;

public interface IWorkspacePersistable
{
    Task SaveWorkspaceStateAsync(CancellationToken cancellationToken = default);
}
