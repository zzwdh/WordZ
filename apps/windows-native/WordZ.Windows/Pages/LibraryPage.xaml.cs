using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Windows.Storage.Pickers;
using WinRT.Interop;
using WordZ.Windows.ViewModels;

namespace WordZ.Windows.Pages;

public sealed partial class LibraryPage : Page
{
    public LibraryPage()
    {
        InitializeComponent();
    }

    private LibraryPageViewModel? ViewModel => DataContext as LibraryPageViewModel;

    private async void OnImportFilesClick(object sender, RoutedEventArgs e)
    {
        if (ViewModel is null)
        {
            return;
        }

        var picker = new FileOpenPicker
        {
            ViewMode = PickerViewMode.List,
            SuggestedStartLocation = PickerLocationId.DocumentsLibrary
        };
        picker.FileTypeFilter.Add(".txt");
        picker.FileTypeFilter.Add(".docx");
        picker.FileTypeFilter.Add(".pdf");
        InitializeWithWindow.Initialize(picker, GetWindowHandle());

        var files = await picker.PickMultipleFilesAsync();
        if (files is null || files.Count == 0)
        {
            return;
        }

        await ViewModel.ImportFilesAsync(files.Select(file => file.Path).Where(path => !string.IsNullOrWhiteSpace(path)).ToArray());
    }

    private async void OnCreateFolderClick(object sender, RoutedEventArgs e)
    {
        if (ViewModel is null)
        {
            return;
        }

        var textBox = new TextBox
        {
            PlaceholderText = "Folder name",
            MinWidth = 280
        };

        var dialog = new ContentDialog
        {
            Title = "Create folder",
            PrimaryButtonText = "Create",
            CloseButtonText = "Cancel",
            DefaultButton = ContentDialogButton.Primary,
            Content = textBox,
            XamlRoot = XamlRoot
        };

        var result = await dialog.ShowAsync();
        if (result == ContentDialogResult.Primary)
        {
            await ViewModel.CreateFolderAsync(textBox.Text);
        }
    }

    private async void OnDeleteSelectedCorpusClick(object sender, RoutedEventArgs e)
    {
        if (ViewModel?.SelectedCorpus is null)
        {
            return;
        }

        var dialog = new ContentDialog
        {
            Title = "Delete corpus",
            PrimaryButtonText = "Delete",
            CloseButtonText = "Cancel",
            DefaultButton = ContentDialogButton.Close,
            Content = $"Move '{ViewModel.SelectedCorpus.Name}' to the recycle bin?",
            XamlRoot = XamlRoot
        };

        if (await dialog.ShowAsync() == ContentDialogResult.Primary)
        {
            await ViewModel.DeleteSelectedCorpusAsync();
        }
    }

    private static nint GetWindowHandle()
    {
        if (App.MainWindowInstance is null)
        {
            throw new InvalidOperationException("The main WordZ window is not available.");
        }

        return WindowNative.GetWindowHandle(App.MainWindowInstance);
    }
}
