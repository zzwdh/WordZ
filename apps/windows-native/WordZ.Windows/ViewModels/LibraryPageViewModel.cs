using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using WordZ.Windows.Models;

namespace WordZ.Windows.ViewModels;

public sealed partial class LibraryPageViewModel : ObservableObject
{
    private readonly MainWindowViewModel _mainWindowViewModel;
    private bool _isSynchronizingSelection;

    public LibraryPageViewModel(MainWindowViewModel mainWindowViewModel)
    {
        _mainWindowViewModel = mainWindowViewModel;
        Shell = mainWindowViewModel.Shell;
        ApplyWorkspaceSelectionCommand = new AsyncRelayCommand(ApplyWorkspaceSelectionAsync);
        UseVisibleAsWorkspaceCommand = new RelayCommand(UseVisibleAsWorkspace);
        UseAllAsWorkspaceCommand = new RelayCommand(UseAllAsWorkspace);
        ClearWorkspaceSelectionCommand = new RelayCommand(ClearWorkspaceSelection);
        RefreshLibraryCommand = new AsyncRelayCommand(RefreshLibraryAsync);
        OpenSelectedCorpusCommand = new AsyncRelayCommand(OpenSelectedCorpusAsync, () => SelectedCorpus is not null);
        DeleteSelectedCorpusCommand = new AsyncRelayCommand(DeleteSelectedCorpusAsync, () => SelectedCorpus is not null);
        StatusText = "The native library page is bound to %APPDATA%\\WordZ and can now import, open, delete, and scope corpora.";
        PreviewTitle = "Select a corpus";
        PreviewMetadata = "Choose a saved corpus to inspect its metadata and preview text.";
        PreviewText = string.Empty;
        RefreshFolderOptions();
    }

    public NativeShellState Shell { get; }

    public ObservableCollection<AnalysisScopeOption> FolderOptions { get; } = new();

    public IAsyncRelayCommand ApplyWorkspaceSelectionCommand { get; }

    public IRelayCommand UseVisibleAsWorkspaceCommand { get; }

    public IRelayCommand UseAllAsWorkspaceCommand { get; }

    public IRelayCommand ClearWorkspaceSelectionCommand { get; }

    public IAsyncRelayCommand RefreshLibraryCommand { get; }

    public IAsyncRelayCommand OpenSelectedCorpusCommand { get; }

    public IAsyncRelayCommand DeleteSelectedCorpusCommand { get; }

    [ObservableProperty]
    private AnalysisScopeOption? _selectedFolderOption;

    [ObservableProperty]
    private LibraryCorpusInfo? _selectedCorpus;

    [ObservableProperty]
    private string _statusText = string.Empty;

    [ObservableProperty]
    private string _previewTitle = string.Empty;

    [ObservableProperty]
    private string _previewMetadata = string.Empty;

    [ObservableProperty]
    private string _previewText = string.Empty;

    public string FolderScopeSummary => $"{Shell.SelectedFolderLabel} | {Shell.VisibleItems.Count} visible corpus/corpora";

    partial void OnSelectedFolderOptionChanged(AnalysisScopeOption? value)
    {
        if (_isSynchronizingSelection || value is null)
        {
            return;
        }

        _ = ApplyFolderSelectionAsync(value);
    }

    partial void OnSelectedCorpusChanged(LibraryCorpusInfo? value)
    {
        OpenSelectedCorpusCommand.NotifyCanExecuteChanged();
        DeleteSelectedCorpusCommand.NotifyCanExecuteChanged();

        if (value is null)
        {
            PreviewTitle = "Select a corpus";
            PreviewMetadata = "Choose a saved corpus to inspect its metadata and preview text.";
            PreviewText = string.Empty;
            return;
        }

        PreviewTitle = value.Name;
        PreviewMetadata = $"{value.FolderName} | {value.SourceTypeLabel} | Updated {value.UpdatedAtDisplay}";
        PreviewText = "Select Open Selected to load the saved corpus preview.";
    }

    public async Task ImportFilesAsync(IReadOnlyList<string> filePaths, bool preserveHierarchy = false)
    {
        if (filePaths.Count == 0)
        {
            return;
        }

        try
        {
            StatusText = $"Importing {filePaths.Count} file(s) into {Shell.SelectedFolderLabel}...";
            var importResult = await _mainWindowViewModel.LibraryService.ImportPathsAsync(
                filePaths,
                Shell.SelectedFolderId,
                preserveHierarchy
            );

            await RefreshLibraryAsync();
            if (importResult.ImportedItems.Count > 0)
            {
                SelectedCorpus = Shell.Items.FirstOrDefault(item =>
                    string.Equals(item.Id, importResult.ImportedItems[0].Id, StringComparison.OrdinalIgnoreCase));

                if (SelectedCorpus is not null)
                {
                    await OpenSelectedCorpusAsync();
                }
            }

            StatusText = importResult.SkippedCount == 0
                ? $"Imported {importResult.ImportedCount} file(s) into the local library."
                : $"Imported {importResult.ImportedCount} file(s); skipped {importResult.SkippedCount}.";
        }
        catch (Exception exception)
        {
            StatusText = $"Import failed: {exception.Message}";
        }
    }

    public async Task CreateFolderAsync(string folderName)
    {
        if (string.IsNullOrWhiteSpace(folderName))
        {
            return;
        }

        try
        {
            StatusText = $"Creating folder '{folderName}'...";
            var folder = await _mainWindowViewModel.LibraryService.CreateFolderAsync(folderName.Trim());
            await RefreshLibraryAsync();

            if (!string.IsNullOrWhiteSpace(folder.Id))
            {
                await _mainWindowViewModel.SetSelectedFolderAsync(folder.Id);
            }

            RefreshFolderOptions();
            StatusText = $"Folder '{folder.Name}' is ready.";
        }
        catch (Exception exception)
        {
            StatusText = $"Could not create the folder: {exception.Message}";
        }
    }

    public async Task OpenSelectedCorpusAsync()
    {
        if (SelectedCorpus is null)
        {
            return;
        }

        try
        {
            StatusText = $"Opening '{SelectedCorpus.Name}'...";
            var openedCorpus = await _mainWindowViewModel.LibraryService.OpenCorpusAsync(SelectedCorpus.Id);
            PreviewTitle = openedCorpus.DisplayName;
            PreviewMetadata = $"{openedCorpus.FolderName} | {openedCorpus.SourceType.ToUpperInvariant()} | {openedCorpus.FilePath}";
            PreviewText = string.IsNullOrWhiteSpace(openedCorpus.Content)
                ? string.Empty
                : openedCorpus.Content.Length > 6000
                    ? $"{openedCorpus.Content[..6000]}{Environment.NewLine}{Environment.NewLine}..."
                    : openedCorpus.Content;
            StatusText = $"Opened '{openedCorpus.DisplayName}'.";
        }
        catch (Exception exception)
        {
            StatusText = $"Open failed: {exception.Message}";
        }
    }

    public async Task DeleteSelectedCorpusAsync()
    {
        if (SelectedCorpus is null)
        {
            return;
        }

        var deletedName = SelectedCorpus.Name;
        try
        {
            StatusText = $"Deleting '{deletedName}' to the recycle bin...";
            await _mainWindowViewModel.LibraryService.DeleteCorpusAsync(SelectedCorpus.Id);
            SelectedCorpus = null;
            await RefreshLibraryAsync();
            StatusText = $"Deleted '{deletedName}' to the recycle bin.";
        }
        catch (Exception exception)
        {
            StatusText = $"Delete failed: {exception.Message}";
        }
    }

    public async Task RefreshLibraryAsync()
    {
        var previouslySelectedCorpusId = SelectedCorpus?.Id;
        await _mainWindowViewModel.RefreshLibraryAsync();
        RefreshFolderOptions();
        SelectedCorpus = Shell.Items.FirstOrDefault(item =>
            string.Equals(item.Id, previouslySelectedCorpusId, StringComparison.OrdinalIgnoreCase));
    }

    private void RefreshFolderOptions()
    {
        var options = new List<AnalysisScopeOption>
        {
            new()
            {
                Id = "all",
                Label = "All local corpora"
            }
        };

        options.AddRange(Shell.Folders.Select(folder => new AnalysisScopeOption
        {
            Id = folder.Id,
            Label = $"{folder.Name} ({folder.ItemCount})"
        }));

        FolderOptions.Clear();
        foreach (var option in options)
        {
            FolderOptions.Add(option);
        }

        _isSynchronizingSelection = true;
        try
        {
            SelectedFolderOption = FolderOptions.FirstOrDefault(option =>
                string.Equals(option.Id, Shell.SelectedFolderId, StringComparison.OrdinalIgnoreCase))
                ?? FolderOptions.FirstOrDefault();
        }
        finally
        {
            _isSynchronizingSelection = false;
        }
    }

    private async Task ApplyFolderSelectionAsync(AnalysisScopeOption selectedOption)
    {
        try
        {
            StatusText = $"Switching the library scope to {selectedOption.Label}...";
            await _mainWindowViewModel.SetSelectedFolderAsync(selectedOption.Id);
            StatusText = $"Current library scope: {Shell.SelectedFolderLabel}.";
        }
        catch (Exception exception)
        {
            StatusText = $"Failed to change the library scope: {exception.Message}";
            RefreshFolderOptions();
        }
    }

    private async Task ApplyWorkspaceSelectionAsync()
    {
        try
        {
            StatusText = "Saving the current workspace selection...";
            await _mainWindowViewModel.SaveWorkspaceSelectionAsync();
            StatusText = Shell.WorkspaceCorpusCount == 0
                ? "Workspace selection cleared."
                : $"Workspace saved with {Shell.WorkspaceCorpusCount} corpus/corpora.";
        }
        catch (Exception exception)
        {
            StatusText = $"Failed to save the workspace selection: {exception.Message}";
        }
    }

    private void UseVisibleAsWorkspace()
    {
        var visibleIds = Shell.VisibleItems.Select(item => item.Id).ToArray();
        Shell.ApplyWorkspaceSelection(visibleIds);
        StatusText = Shell.VisibleItems.Count == 0
            ? "No visible corpora are available for the workspace."
            : $"Visible corpora prepared as the current workspace ({Shell.VisibleItems.Count}).";
    }

    private void UseAllAsWorkspace()
    {
        Shell.ApplyWorkspaceSelection(Shell.Items.Select(item => item.Id));
        StatusText = Shell.TotalCorpusCount == 0
            ? "No saved corpora are available yet."
            : $"All {Shell.TotalCorpusCount} corpora are staged as the current workspace.";
    }

    private void ClearWorkspaceSelection()
    {
        Shell.ApplyWorkspaceSelection(Array.Empty<string>());
        StatusText = "Workspace selection cleared locally. Click Apply to persist it.";
    }
}
