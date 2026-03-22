using System.ComponentModel;
using Microsoft.UI.Dispatching;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using WordZ.Windows.Models;
using WordZ.Windows.Pages;
using WordZ.Windows.Services;
using WordZ.Windows.ViewModels;

namespace WordZ.Windows;

public sealed partial class MainWindow : Window
{
    private readonly NativeAnalysisService _analysisService;
    private readonly Dictionary<string, Func<FrameworkElement>> _pageFactory;
    private bool _suppressSelectionChanged;
    private string _currentTag = "library";

    public MainWindowViewModel ViewModel { get; }

    public MainWindow()
    {
        NativeTrace.Write("MainWindow ctor start.");
        InitializeComponent();
        NativeTrace.Write("MainWindow InitializeComponent complete.");
        var dispatcherQueue = DispatcherQueue.GetForCurrentThread()
            ?? throw new InvalidOperationException("A DispatcherQueue is required to start the native shell.");
        var engineClient = new EngineClient();
        ViewModel = new MainWindowViewModel(
            engineClient,
            new NativeShellService(),
            new NativeWorkspaceService(engineClient),
            new UpdateService(),
            dispatcherQueue
        );
        _analysisService = new NativeAnalysisService(ViewModel.EngineClient, ViewModel.LibraryService, ViewModel.Shell);
        NativeTrace.Write("MainWindow ViewModel created.");
        ShellNavigation.DataContext = ViewModel;
        Title = ViewModel.Shell.WindowTitle;
        ViewModel.Shell.PropertyChanged += OnShellPropertyChanged;

        _pageFactory = new Dictionary<string, Func<FrameworkElement>>(StringComparer.OrdinalIgnoreCase)
        {
            ["library"] = () => new LibraryPage
            {
                DataContext = new LibraryPageViewModel(ViewModel)
            },
            ["stats"] = () => new StatsPage
            {
                DataContext = new StatsPageViewModel(ViewModel.Shell, _analysisService, ViewModel.WorkspaceService)
            },
            ["kwic"] = () => new KwicPage
            {
                DataContext = new KwicPageViewModel(
                    ViewModel.Shell,
                    _analysisService,
                    ViewModel.WorkspaceService,
                    NavigateToLocatorAsync
                )
            },
            ["collocate"] = () => new CollocatePage
            {
                DataContext = new CollocatePageViewModel(ViewModel.Shell, _analysisService, ViewModel.WorkspaceService)
            },
            ["compare"] = () => CreatePlaceholderPage(
                "Compare",
                "The native Compare workflow is staged next. The shell preserves this section so navigation stays aligned with WordZ."
            ),
            ["chi-square"] = () => CreatePlaceholderPage(
                "Chi-square",
                "Chi-square analysis will land after the first four native pages are stable."
            ),
            ["word-cloud"] = () => CreatePlaceholderPage(
                "WordCloud",
                "WordCloud will be rebuilt natively after the statistics and query surfaces are connected."
            ),
            ["ngram"] = () => CreatePlaceholderPage(
                "Ngram",
                "Ngram stays visible as a placeholder while Stage 1 focuses on the first connected pages."
            ),
            ["locator"] = () => new LocatorPage
            {
                DataContext = new LocatorPageViewModel(ViewModel.Shell, _analysisService, ViewModel.WorkspaceService)
            }
        };

        Activated += OnActivated;
        Closed += OnClosed;
        _suppressSelectionChanged = true;
        ShellNavigation.SelectedItem = LibraryNavItem;
        _suppressSelectionChanged = false;
        SetPageContent("library");
        NativeTrace.Write("MainWindow initial navigation complete.");
    }

    private async void OnActivated(object sender, WindowActivatedEventArgs args)
    {
        Activated -= OnActivated;
        NativeTrace.Write("MainWindow activated. Initializing ViewModel.");
        await ViewModel.InitializeAsync();
        SetPageContent(_currentTag);
        await RestoreNavigationAsync();
        NativeTrace.Write("MainWindow ViewModel initialization complete.");
    }

    private async void OnNavigationSelectionChanged(NavigationView sender, NavigationViewSelectionChangedEventArgs args)
    {
        if (_suppressSelectionChanged)
        {
            return;
        }

        if (args.SelectedItemContainer?.Tag is string tag)
        {
            await NavigateToAsync(tag);
        }
    }

    private async Task RestoreNavigationAsync()
    {
        var restoredTag = ViewModel.RestoredNavigationTag;
        if (string.IsNullOrWhiteSpace(restoredTag) || string.Equals(restoredTag, _currentTag, StringComparison.OrdinalIgnoreCase))
        {
            return;
        }

        SelectNavigationItem(restoredTag);
        await NavigateToAsync(restoredTag, persistCurrentPageState: false, persistCurrentTab: false);
    }

    private async Task NavigateToLocatorAsync(LocatorNavigationRequest request)
    {
        SelectNavigationItem("locator");
        await NavigateToAsync("locator");

        if (PageHost.Content is FrameworkElement element
            && element.DataContext is LocatorPageViewModel locatorPageViewModel)
        {
            await locatorPageViewModel.LoadRequestAsync(request);
        }
    }

    private PlaceholderPage CreatePlaceholderPage(string title, string description)
    {
        return new PlaceholderPage
        {
            DataContext = new PlaceholderPageViewModel(ViewModel.Shell, title, description)
        };
    }

    private void OnShellPropertyChanged(object? sender, PropertyChangedEventArgs args)
    {
        if (args.PropertyName == nameof(NativeShellState.WindowTitle))
        {
            Title = ViewModel.Shell.WindowTitle;
        }
    }

    private async void OnClosed(object sender, WindowEventArgs args)
    {
        Closed -= OnClosed;
        ViewModel.Shell.PropertyChanged -= OnShellPropertyChanged;
        await ViewModel.SaveCurrentTabAsync(_currentTag);
        await SaveCurrentPageStateAsync();
        NativeTrace.Write("MainWindow closing. Disposing ViewModel.");
        await ViewModel.DisposeAsync();
        NativeTrace.Write("MainWindow dispose complete.");
    }

    private async Task NavigateToAsync(string tag, bool persistCurrentPageState = true, bool persistCurrentTab = true)
    {
        if (string.Equals(_currentTag, tag, StringComparison.OrdinalIgnoreCase))
        {
            if (persistCurrentTab)
            {
                await ViewModel.SaveCurrentTabAsync(tag);
            }
            return;
        }

        NativeTrace.Write($"MainWindow navigating to '{tag}'.");
        if (persistCurrentPageState)
        {
            await SaveCurrentPageStateAsync();
        }

        SetPageContent(tag);

        if (persistCurrentTab)
        {
            await ViewModel.SaveCurrentTabAsync(tag);
        }
    }

    private void SetPageContent(string tag)
    {
        if (_pageFactory.TryGetValue(tag, out var factory))
        {
            PageHost.Content = factory();
            _currentTag = tag;
            NativeTrace.Write($"MainWindow navigation to '{tag}' complete.");
            return;
        }

        PageHost.Content = CreatePlaceholderPage(
            "Unavailable",
            $"No page factory is registered for '{tag}'."
        );
        _currentTag = tag;
        NativeTrace.Write($"MainWindow navigation fallback for '{tag}' complete.");
    }

    private void SelectNavigationItem(string tag)
    {
        var target = ShellNavigation.MenuItems
            .OfType<NavigationViewItem>()
            .FirstOrDefault(item => string.Equals(item.Tag as string, tag, StringComparison.OrdinalIgnoreCase));

        if (target is null)
        {
            return;
        }

        _suppressSelectionChanged = true;
        try
        {
            ShellNavigation.SelectedItem = target;
        }
        finally
        {
            _suppressSelectionChanged = false;
        }
    }

    private async Task SaveCurrentPageStateAsync()
    {
        if (PageHost.Content is not FrameworkElement element)
        {
            return;
        }

        if (element.DataContext is not IWorkspacePersistable persistable)
        {
            return;
        }

        try
        {
            await persistable.SaveWorkspaceStateAsync();
        }
        catch (Exception exception)
        {
            NativeTrace.WriteException("SaveCurrentPageStateAsync failed", exception);
        }
    }
}
