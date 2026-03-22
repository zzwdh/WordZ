using System.Text.Json;
using WordZ.Windows.Contracts;
using WordZ.Windows.Models;

namespace WordZ.Windows.Services;

public sealed class NativeLibraryService
{
    private readonly EngineClient _engineClient;

    public NativeLibraryService(EngineClient engineClient)
    {
        _engineClient = engineClient;
    }

    public async Task<LibrarySnapshotResult> LoadLibraryAsync(string folderId = "all", CancellationToken cancellationToken = default)
    {
        using var document = await _engineClient.InvokeAsync(
            EngineContracts.Methods.LibraryList,
            new
            {
                folderId = string.IsNullOrWhiteSpace(folderId) ? "all" : folderId
            },
            cancellationToken
        );

        var resultElement = GetSuccessResult(document?.RootElement);
        return new LibrarySnapshotResult
        {
            SelectedFolderId = ReadString(resultElement, "selectedFolderId", "all"),
            Folders = ParseFolders(resultElement),
            Items = ParseItems(resultElement)
        };
    }

    public async Task<LibraryOpenCorpusResult> OpenCorpusAsync(string corpusId, CancellationToken cancellationToken = default)
    {
        using var document = await _engineClient.InvokeAsync(
            EngineContracts.Methods.LibraryOpenSaved,
            new
            {
                corpusId
            },
            cancellationToken
        );

        var resultElement = GetSuccessResult(document?.RootElement);
        return new LibraryOpenCorpusResult
        {
            CorpusId = ReadString(resultElement, "corpusId", string.Empty),
            DisplayName = ReadString(resultElement, "displayName", "Untitled corpus"),
            FolderId = ReadString(resultElement, "folderId", string.Empty),
            FolderName = ReadString(resultElement, "folderName", "Uncategorized"),
            SourceType = ReadString(resultElement, "sourceType", "txt"),
            FilePath = ReadString(resultElement, "filePath", string.Empty),
            Content = ReadString(resultElement, "content", string.Empty)
        };
    }

    public async Task<LibraryImportResult> ImportPathsAsync(
        IReadOnlyList<string> filePaths,
        string folderId,
        bool preserveHierarchy,
        CancellationToken cancellationToken = default)
    {
        using var document = await _engineClient.InvokeAsync(
            EngineContracts.Methods.LibraryImportPaths,
            new
            {
                paths = filePaths,
                folderId = string.Equals(folderId, "all", StringComparison.OrdinalIgnoreCase) ? string.Empty : folderId,
                preserveHierarchy
            },
            cancellationToken
        );

        var resultElement = GetSuccessResult(document?.RootElement);
        var importedItems = resultElement.TryGetProperty("importedItems", out var importedItemsElement)
            && importedItemsElement.ValueKind == JsonValueKind.Array
                ? importedItemsElement.EnumerateArray()
                    .Select(item => new LibraryCorpusInfo
                    {
                        Id = ReadString(item, "id", string.Empty),
                        Name = ReadString(item, "name", "Untitled corpus"),
                        FolderId = ReadString(item, "folderId", string.Empty),
                        FolderName = ReadString(item, "folderName", "Uncategorized"),
                        SourceType = ReadString(item, "sourceType", "txt"),
                        OriginalName = Path.GetFileName(ReadString(item, "sourcePath", string.Empty)),
                        FilePath = ReadString(item, "filePath", string.Empty),
                        UpdatedAt = string.Empty
                    })
                    .Where(item => !string.IsNullOrWhiteSpace(item.Id))
                    .ToArray()
                : Array.Empty<LibraryCorpusInfo>();

        return new LibraryImportResult
        {
            ImportedCount = ReadInt(resultElement, "importedCount"),
            SkippedCount = ReadInt(resultElement, "skippedCount"),
            ImportedItems = importedItems
        };
    }

    public async Task<LibraryFolderInfo> CreateFolderAsync(string folderName, CancellationToken cancellationToken = default)
    {
        using var document = await _engineClient.InvokeAsync(
            EngineContracts.Methods.LibraryCreateFolder,
            new
            {
                folderName
            },
            cancellationToken
        );

        var resultElement = GetSuccessResult(document?.RootElement);
        if (!resultElement.TryGetProperty("folder", out var folderElement))
        {
            return new LibraryFolderInfo
            {
                Name = folderName
            };
        }

        return new LibraryFolderInfo
        {
            Id = ReadString(folderElement, "id", string.Empty),
            Name = ReadString(folderElement, "name", folderName),
            UpdatedAt = ReadString(folderElement, "updatedAt", string.Empty),
            ItemCount = ReadInt(folderElement, "itemCount"),
            IsSystem = ReadBool(folderElement, "system"),
            CanDelete = ReadBool(folderElement, "canDelete"),
            CanRename = ReadBool(folderElement, "canRename")
        };
    }

    public async Task DeleteCorpusAsync(string corpusId, CancellationToken cancellationToken = default)
    {
        using var _ = await _engineClient.InvokeAsync(
            EngineContracts.Methods.LibraryDeleteCorpus,
            new
            {
                corpusId
            },
            cancellationToken
        );
    }

    private static JsonElement GetSuccessResult(JsonElement? payload)
    {
        if (payload is null)
        {
            throw new InvalidOperationException("The engine did not return a response payload.");
        }

        var root = payload.Value;
        if (root.TryGetProperty("error", out var errorElement))
        {
            throw new InvalidOperationException(ReadString(errorElement, "message", "An unknown JSON-RPC error occurred."));
        }

        if (!root.TryGetProperty("result", out var resultElement))
        {
            throw new InvalidOperationException("The engine response is missing the result payload.");
        }

        if (resultElement.TryGetProperty("success", out var successElement)
            && successElement.ValueKind == JsonValueKind.False)
        {
            throw new InvalidOperationException(ReadString(resultElement, "message", "The engine returned an unsuccessful response."));
        }

        return resultElement;
    }

    private static IReadOnlyList<LibraryFolderInfo> ParseFolders(JsonElement resultElement)
    {
        if (!resultElement.TryGetProperty("folders", out var foldersElement) || foldersElement.ValueKind != JsonValueKind.Array)
        {
            return Array.Empty<LibraryFolderInfo>();
        }

        return foldersElement
            .EnumerateArray()
            .Select(folder => new LibraryFolderInfo
            {
                Id = ReadString(folder, "id", string.Empty),
                Name = ReadString(folder, "name", "Unnamed folder"),
                UpdatedAt = ReadString(folder, "updatedAt", string.Empty),
                ItemCount = ReadInt(folder, "itemCount"),
                IsSystem = ReadBool(folder, "system"),
                CanDelete = ReadBool(folder, "canDelete"),
                CanRename = ReadBool(folder, "canRename")
            })
            .OrderBy(folder => folder.IsSystem ? 0 : 1)
            .ThenBy(folder => folder.Name, StringComparer.OrdinalIgnoreCase)
            .ToArray();
    }

    private static IReadOnlyList<LibraryCorpusInfo> ParseItems(JsonElement resultElement)
    {
        if (!resultElement.TryGetProperty("items", out var itemsElement) || itemsElement.ValueKind != JsonValueKind.Array)
        {
            return Array.Empty<LibraryCorpusInfo>();
        }

        return itemsElement
            .EnumerateArray()
            .Select(item => new LibraryCorpusInfo
            {
                Id = ReadString(item, "id", string.Empty),
                Name = ReadString(item, "name", "Untitled corpus"),
                FolderId = ReadString(item, "folderId", string.Empty),
                FolderName = ReadString(item, "folderName", "Uncategorized"),
                SourceType = ReadString(item, "sourceType", "txt"),
                OriginalName = ReadString(item, "originalName", string.Empty),
                FilePath = ReadString(item, "filePath", string.Empty),
                UpdatedAt = ReadString(item, "updatedAt", string.Empty)
            })
            .OrderByDescending(item => item.UpdatedAt, StringComparer.OrdinalIgnoreCase)
            .ThenBy(item => item.Name, StringComparer.OrdinalIgnoreCase)
            .ToArray();
    }

    private static bool ReadBool(JsonElement element, string propertyName)
    {
        if (!element.TryGetProperty(propertyName, out var propertyElement))
        {
            return false;
        }

        return propertyElement.ValueKind == JsonValueKind.True
            || (propertyElement.ValueKind == JsonValueKind.String
                && bool.TryParse(propertyElement.GetString(), out var parsed)
                && parsed);
    }

    private static int ReadInt(JsonElement element, string propertyName)
    {
        if (!element.TryGetProperty(propertyName, out var propertyElement))
        {
            return 0;
        }

        if (propertyElement.ValueKind == JsonValueKind.Number && propertyElement.TryGetInt32(out var number))
        {
            return number;
        }

        return propertyElement.ValueKind == JsonValueKind.String
            && int.TryParse(propertyElement.GetString(), out var parsed)
                ? parsed
                : 0;
    }

    private static string ReadString(JsonElement element, string propertyName, string fallback)
    {
        if (!element.TryGetProperty(propertyName, out var propertyElement))
        {
            return fallback;
        }

        return propertyElement.ValueKind == JsonValueKind.String
            ? propertyElement.GetString() ?? fallback
            : propertyElement.GetRawText();
    }
}
