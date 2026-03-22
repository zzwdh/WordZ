using System.Text.Json;
using Microsoft.UI.Dispatching;
using Microsoft.UI.Xaml;
using WordZ.Windows.Services;
using WordZ.Windows.ViewModels;

namespace WordZ.Windows;

public partial class App : Application
{
    private Window? _window;

    public static Window? MainWindowInstance => (Current as App)?._window;

    public App()
    {
        NativeTrace.Write("App ctor start.");
        InitializeComponent();
        NativeTrace.Write("App ctor InitializeComponent complete.");
        UnhandledException += OnUnhandledException;
        AppDomain.CurrentDomain.UnhandledException += OnCurrentDomainUnhandledException;
        TaskScheduler.UnobservedTaskException += OnUnobservedTaskException;
    }

    protected override async void OnLaunched(LaunchActivatedEventArgs args)
    {
        NativeTrace.Write($"App OnLaunched start. Args='{args.Arguments}'");
        if (IsSelfTestLaunch(args.Arguments))
        {
            NativeTrace.Write("App running self-test mode.");
            await RunSelfTestAsync();
            NativeTrace.Write("App self-test complete. Exiting.");
            Exit();
            return;
        }

        _window = new MainWindow();
        NativeTrace.Write("MainWindow created. Activating.");
        _window.Activate();
        NativeTrace.Write("MainWindow activated.");
    }

    private static bool IsSelfTestLaunch(string arguments)
    {
        return arguments.Contains("--self-test", StringComparison.OrdinalIgnoreCase);
    }

    private static async Task RunSelfTestAsync()
    {
        NativeTrace.Write("RunSelfTestAsync start.");
        var dispatcherQueue = DispatcherQueue.GetForCurrentThread()
            ?? throw new InvalidOperationException("A DispatcherQueue is required to run the native shell self-test.");
        await using var engineClient = new EngineClient();
        var viewModel = new MainWindowViewModel(
            engineClient,
            new NativeShellService(),
            new NativeWorkspaceService(engineClient),
            new UpdateService(),
            dispatcherQueue
        );

        try
        {
            await viewModel.InitializeAsync();
            NativeTrace.Write("RunSelfTestAsync InitializeAsync complete.");
            var outputPath = Environment.GetEnvironmentVariable("WORDZ_NATIVE_SELF_TEST_OUTPUT");
            if (!string.IsNullOrWhiteSpace(outputPath))
            {
                var directory = Path.GetDirectoryName(outputPath);
                if (!string.IsNullOrWhiteSpace(directory))
                {
                    Directory.CreateDirectory(directory);
                }

                var json = JsonSerializer.Serialize(
                    viewModel.CreateProbeResult(),
                    new JsonSerializerOptions { WriteIndented = true }
                );
                await File.WriteAllTextAsync(outputPath, json);
                NativeTrace.Write($"RunSelfTestAsync wrote output to {outputPath}.");
            }
        }
        finally
        {
            await viewModel.DisposeAsync();
            NativeTrace.Write("RunSelfTestAsync dispose complete.");
        }
    }

    private static void OnUnhandledException(object sender, Microsoft.UI.Xaml.UnhandledExceptionEventArgs args)
    {
        NativeTrace.WriteException("Application.UnhandledException", args.Exception);
    }

    private static void OnCurrentDomainUnhandledException(object sender, System.UnhandledExceptionEventArgs args)
    {
        if (args.ExceptionObject is Exception exception)
        {
            NativeTrace.WriteException("AppDomain.CurrentDomain.UnhandledException", exception);
            return;
        }

        NativeTrace.Write($"AppDomain.CurrentDomain.UnhandledException: {args.ExceptionObject}");
    }

    private static void OnUnobservedTaskException(object? sender, UnobservedTaskExceptionEventArgs args)
    {
        NativeTrace.WriteException("TaskScheduler.UnobservedTaskException", args.Exception);
    }
}
