using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml;
using WordZ.Windows.Models;
using WordZ.Windows.ViewModels;

namespace WordZ.Windows.Pages;

public sealed partial class KwicPage : Page
{
    public KwicPage()
    {
        InitializeComponent();
    }

    private async void OnLocateClick(object sender, RoutedEventArgs e)
    {
        if (DataContext is not KwicPageViewModel viewModel)
        {
            return;
        }

        if (sender is not FrameworkElement element || element.Tag is not KwicResultRow row)
        {
            return;
        }

        await viewModel.OpenInLocatorAsync(row);
    }
}
