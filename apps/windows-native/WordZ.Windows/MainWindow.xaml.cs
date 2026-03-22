using Microsoft.UI.Xaml;
using WordZ.Windows.ViewModels;
using WordZ.Windows.Services;

namespace WordZ.Windows;

public sealed partial class MainWindow : Window
{
    public MainWindowViewModel ViewModel { get; }

    public MainWindow()
    {
        InitializeComponent();
        var engineClient = new EngineClient();
        ViewModel = new MainWindowViewModel(
            engineClient,
            new NativeShellService(),
            new UpdateService()
        );
        DataContext = ViewModel;
        Activated += OnActivated;
        Closed += OnClosed;
    }

    private async void OnActivated(object sender, WindowActivatedEventArgs args)
    {
        Activated -= OnActivated;
        await ViewModel.InitializeAsync();
    }

    private async void OnClosed(object sender, WindowEventArgs args)
    {
        Closed -= OnClosed;
        await ViewModel.DisposeAsync();
    }
}
