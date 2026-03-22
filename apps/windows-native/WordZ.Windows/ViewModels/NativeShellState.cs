using System.Collections.ObjectModel;
using System.Collections.Specialized;
using CommunityToolkit.Mvvm.ComponentModel;
using Microsoft.UI.Xaml.Controls;
using WordZ.Windows.Models;

namespace WordZ.Windows.ViewModels;

public sealed partial class NativeShellState : ObservableObject
{
    public NativeShellState()
    {
        Items.CollectionChanged += OnItemsCollectionChanged;
    }

    public ObservableCollection<LibraryFolderInfo> Folders { get; } = new();
    public ObservableCollection<LibraryCorpusInfo> Items { get; } = new();
    public ObservableCollection<LibraryCorpusInfo> VisibleItems { get; } = new();

    [ObservableProperty]
    private string _windowTitle = "WordZ";

    [ObservableProperty]
    private string _versionText = "Windows Native Preview";

    [ObservableProperty]
    private string _engineStatus = "Connecting to the WordZ engine...";

    [ObservableProperty]
    private InfoBarSeverity _engineSeverity = InfoBarSeverity.Informational;

    [ObservableProperty]
    private string _workspaceSummary = "Waiting for the native shell to load the local library state.";

    [ObservableProperty]
    private string _buildSummary = "WinUI 3 shell with Node.js sidecar.";

    [ObservableProperty]
    private string _userDataDirectory = string.Empty;

    [ObservableProperty]
    private string _selectedFolderId = "all";

    [ObservableProperty]
    private string _selectedFolderLabel = "All local corpora";

    [ObservableProperty]
    private string _librarySummaryText = "Waiting for library.list...";

    [ObservableProperty]
    private string _runtimeSummary = "Node and engine paths will appear after startup.";

    [ObservableProperty]
    private string _workspaceSelectionSummary = "No corpus has been added to the current workspace yet.";

    [ObservableProperty]
    private int _folderCount;

    [ObservableProperty]
    private int _totalCorpusCount;

    [ObservableProperty]
    private int _workspaceCorpusCount;

    [ObservableProperty]
    private bool _isBusy = true;

    [ObservableProperty]
    private bool _isConnected;

    public void ApplyLibrarySnapshot(
        IReadOnlyList<LibraryFolderInfo> folders,
        IReadOnlyList<LibraryCorpusInfo> items,
        string selectedFolderId)
    {
        var selectedWorkspaceIds = GetWorkspaceCorpusIds().ToArray();
        ReplaceCollection(Folders, folders);
        ReplaceCollection(Items, items);

        FolderCount = folders.Count;
        TotalCorpusCount = items.Count;
        ApplyWorkspaceSelection(selectedWorkspaceIds);
        ApplySelectedFolder(selectedFolderId);
    }

    public void ApplySelectedFolder(string selectedFolderId)
    {
        var normalizedSelectedFolderId = NormalizeSelectedFolderId(selectedFolderId);
        SelectedFolderId = normalizedSelectedFolderId;
        SelectedFolderLabel = ResolveSelectedFolderLabel(Folders, normalizedSelectedFolderId);
        ReplaceCollection(VisibleItems, ResolveVisibleItems(normalizedSelectedFolderId));
        RefreshLibrarySummary();
    }

    public void ApplyWorkspaceSelection(IEnumerable<string> selectedCorpusIds)
    {
        var selection = new HashSet<string>(
            selectedCorpusIds.Where(id => !string.IsNullOrWhiteSpace(id)),
            StringComparer.OrdinalIgnoreCase
        );

        foreach (var item in Items)
        {
            item.IsInWorkspace = selection.Contains(item.Id);
        }

        RefreshLibrarySummary();
    }

    public IReadOnlyList<LibraryCorpusInfo> GetWorkspaceItems()
    {
        return Items.Where(item => item.IsInWorkspace).ToArray();
    }

    public IReadOnlyList<string> GetWorkspaceCorpusIds()
    {
        return GetWorkspaceItems()
            .Select(item => item.Id)
            .Where(id => !string.IsNullOrWhiteSpace(id))
            .ToArray();
    }

    private void OnItemsCollectionChanged(object? sender, NotifyCollectionChangedEventArgs eventArgs)
    {
        if (eventArgs.OldItems is not null)
        {
            foreach (var item in eventArgs.OldItems.OfType<LibraryCorpusInfo>())
            {
                item.PropertyChanged -= OnLibraryCorpusPropertyChanged;
            }
        }

        if (eventArgs.NewItems is not null)
        {
            foreach (var item in eventArgs.NewItems.OfType<LibraryCorpusInfo>())
            {
                item.PropertyChanged += OnLibraryCorpusPropertyChanged;
            }
        }
    }

    private void OnLibraryCorpusPropertyChanged(object? sender, System.ComponentModel.PropertyChangedEventArgs eventArgs)
    {
        if (eventArgs.PropertyName == nameof(LibraryCorpusInfo.IsInWorkspace))
        {
            RefreshLibrarySummary();
        }
    }

    private static void ReplaceCollection<T>(ObservableCollection<T> target, IEnumerable<T> source)
    {
        target.Clear();
        foreach (var item in source)
        {
            target.Add(item);
        }
    }

    private static string ResolveSelectedFolderLabel(IEnumerable<LibraryFolderInfo> folders, string selectedFolderId)
    {
        if (string.Equals(selectedFolderId, "all", StringComparison.OrdinalIgnoreCase))
        {
            return "All local corpora";
        }

        var folder = folders.FirstOrDefault(candidate => string.Equals(candidate.Id, selectedFolderId, StringComparison.OrdinalIgnoreCase));
        return folder?.Name ?? "Current folder";
    }

    private IReadOnlyList<LibraryCorpusInfo> ResolveVisibleItems(string selectedFolderId)
    {
        if (string.Equals(selectedFolderId, "all", StringComparison.OrdinalIgnoreCase))
        {
            return Items.ToArray();
        }

        return Items
            .Where(item => string.Equals(item.FolderId, selectedFolderId, StringComparison.OrdinalIgnoreCase))
            .ToArray();
    }

    private string NormalizeSelectedFolderId(string selectedFolderId)
    {
        if (string.IsNullOrWhiteSpace(selectedFolderId)
            || string.Equals(selectedFolderId, "all", StringComparison.OrdinalIgnoreCase))
        {
            return "all";
        }

        return Folders.Any(folder => string.Equals(folder.Id, selectedFolderId, StringComparison.OrdinalIgnoreCase))
            ? selectedFolderId
            : "all";
    }

    private void RefreshLibrarySummary()
    {
        var visibleCount = VisibleItems.Count;
        WorkspaceCorpusCount = Items.Count(item => item.IsInWorkspace);
        WorkspaceSelectionSummary = WorkspaceCorpusCount == 0
            ? "No corpus has been added to the current workspace yet."
            : WorkspaceCorpusCount == 1
                ? "The current workspace contains 1 corpus."
                : $"The current workspace contains {WorkspaceCorpusCount} corpora.";
        LibrarySummaryText = TotalCorpusCount == 0
            ? $"No saved corpora were found yet. {FolderCount} folder entries are available."
            : string.Equals(SelectedFolderId, "all", StringComparison.OrdinalIgnoreCase)
                ? $"{TotalCorpusCount} corpora loaded across {FolderCount} folders. {WorkspaceSelectionSummary}"
                : $"{visibleCount} of {TotalCorpusCount} corpora are currently in scope: {SelectedFolderLabel}. {WorkspaceSelectionSummary}";
        WorkspaceSummary = TotalCorpusCount == 0
            ? $"WordZ is connected to {UserDataDirectory} but the local library is still empty."
            : $"{visibleCount} corpus/corpora available in {SelectedFolderLabel}. {WorkspaceSelectionSummary}";
    }
}
