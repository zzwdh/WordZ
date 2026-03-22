namespace WordZ.Windows.ViewModels;

public sealed class PlaceholderPageViewModel
{
    public PlaceholderPageViewModel(NativeShellState shell, string title, string description)
    {
        Shell = shell;
        Title = title;
        Description = description;
    }

    public NativeShellState Shell { get; }
    public string Title { get; }
    public string Description { get; }
}
