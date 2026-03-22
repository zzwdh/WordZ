using System.Text.Json;
using WordZ.Windows.Contracts;
using WordZ.Windows.Services;

var tempUserDataDir = Path.Combine(Path.GetTempPath(), $"wordz-native-smoke-{Guid.NewGuid():N}");
var tempCorpusPath = Path.Combine(tempUserDataDir, "sample-corpus.txt");

try
{
    Directory.CreateDirectory(tempUserDataDir);
    await File.WriteAllTextAsync(
        tempCorpusPath,
        """
        cyber analysis helps cyber defense.
        corpus analysis keeps cyber context visible.
        cyber corpora help collocate analysis stay honest.
        """
    );

    await using var engineClient = new EngineClient();
    await engineClient.StartAsync(tempUserDataDir);

    using var appInfoDocument = await engineClient.InvokeAsync(EngineContracts.Methods.AppGetInfo);
    using var createFolderDocument = await engineClient.InvokeAsync(
        EngineContracts.Methods.LibraryCreateFolder,
        new
        {
            folderName = "Smoke Imports"
        }
    );
    var createFolderResult = GetSuccessResult(createFolderDocument);
    var createdFolderId = createFolderResult.TryGetProperty("folder", out var folderElement)
        ? ReadString(folderElement, "id", string.Empty)
        : string.Empty;
    using var importDocument = await engineClient.InvokeAsync(
        EngineContracts.Methods.LibraryImportPaths,
        new
        {
            paths = new[] { tempCorpusPath },
            folderId = createdFolderId,
            preserveHierarchy = false
        }
    );
    using var libraryDocument = await engineClient.InvokeAsync(
        EngineContracts.Methods.LibraryList,
        new
        {
            folderId = "all"
        }
    );

    var appInfoResult = GetSuccessResult(appInfoDocument);
    var importResult = GetSuccessResult(importDocument);
    var libraryResult = GetSuccessResult(libraryDocument);
    var libraryItems = libraryResult.TryGetProperty("items", out var itemsElement) && itemsElement.ValueKind == JsonValueKind.Array
        ? itemsElement.EnumerateArray()
            .Select(item => (
                Id: ReadString(item, "id", string.Empty),
                Name: ReadString(item, "name", "Untitled corpus")
            ))
            .Where(item => !string.IsNullOrWhiteSpace(item.Id))
            .ToArray()
        : Array.Empty<(string Id, string Name)>();
    var corpusIds = libraryItems.Select(item => item.Id).ToArray();
    var corpusNames = libraryItems.Select(item => item.Name).ToArray();
    var importedCorpusId = corpusIds.FirstOrDefault() ?? string.Empty;

    using var openSavedDocument = await engineClient.InvokeAsync(
        EngineContracts.Methods.LibraryOpenSaved,
        new
        {
            corpusId = importedCorpusId
        }
    );
    var openSavedResult = GetSuccessResult(openSavedDocument);

    using var workspaceSaveDocument = await engineClient.InvokeAsync(
        EngineContracts.Methods.WorkspaceSaveState,
        new
        {
            snapshot = new
            {
                currentTab = "collocate",
                currentLibraryFolderId = "uncategorized",
                workspace = new
                {
                    corpusIds,
                    corpusNames
                },
                search = new
                {
                    query = "cyber",
                    options = new
                    {
                        words = true,
                        caseSensitive = false,
                        regex = false
                    }
                },
                kwic = new
                {
                    pageSize = "10",
                    scope = "workspace",
                    sortMode = "original",
                    leftWindow = "3",
                    rightWindow = "3"
                },
                collocate = new
                {
                    pageSize = "10",
                    scope = "workspace",
                    leftWindow = "3",
                    rightWindow = "3",
                    minFreq = "2"
                }
            }
        }
    );
    using var workspaceStateDocument = await engineClient.InvokeAsync(EngineContracts.Methods.WorkspaceGetState);
    var workspaceSaveResult = GetSuccessResult(workspaceSaveDocument);
    var workspaceStateResult = GetSuccessResult(workspaceStateDocument);

    using var openBatchDocument = await engineClient.InvokeAsync(
        EngineContracts.Methods.LibraryOpenSavedBatch,
        new
        {
            corpusIds
        }
    );
    var openBatchResult = GetSuccessResult(openBatchDocument);
    var comparisonEntries = BuildComparisonEntries(openBatchResult);
    var combinedText = string.Join(
        Environment.NewLine + Environment.NewLine,
        comparisonEntries.Select(entry => entry.Content)
    );

    var statsResult = await StartAndWaitForTaskResultAsync(
        engineClient,
        "stats",
        new
        {
            text = combinedText,
            comparisonEntries = comparisonEntries
        }
    );
    var kwicResult = await StartAndWaitForTaskResultAsync(
        engineClient,
        "library-kwic",
        new
        {
            corpusEntries = comparisonEntries.Select(entry => new
            {
                corpusId = entry.CorpusId,
                corpusName = entry.CorpusName,
                folderId = entry.FolderId,
                folderName = entry.FolderName,
                sourceType = entry.SourceType,
                content = entry.Content
            }).ToArray(),
            keyword = "cyber",
            leftWindowSize = 3,
            rightWindowSize = 3,
            sortMode = "original",
            searchOptions = new
            {
                words = true,
                caseSensitive = false,
                regex = false
            }
        }
    );
    var firstKwicRow = kwicResult.TryGetProperty("rows", out var kwicRowsElement)
        && kwicRowsElement.ValueKind == JsonValueKind.Array
        && kwicRowsElement.GetArrayLength() > 0
            ? kwicRowsElement[0]
            : default;
    var locatorResult = await StartAndWaitForTaskResultAsync(
        engineClient,
        "locator",
        new
        {
            text = ReadString(openSavedResult, "content", string.Empty),
            sentenceId = firstKwicRow.ValueKind == JsonValueKind.Object ? ReadInt(firstKwicRow, "sentenceId") : 0,
            nodeIndex = firstKwicRow.ValueKind == JsonValueKind.Object ? ReadInt(firstKwicRow, "sentenceTokenIndex") : 0,
            leftWindowSize = 3,
            rightWindowSize = 3
        }
    );
    var collocateResult = await StartAndWaitForTaskResultAsync(
        engineClient,
        "collocate",
        new
        {
            text = combinedText,
            keyword = "cyber",
            leftWindowSize = 3,
            rightWindowSize = 3,
            minFreq = 1,
            searchOptions = new
            {
                words = true,
                caseSensitive = false,
                regex = false
            }
        }
    );
    using var deleteCorpusDocument = await engineClient.InvokeAsync(
        EngineContracts.Methods.LibraryDeleteCorpus,
        new
        {
            corpusId = importedCorpusId
        }
    );
    var deleteCorpusResult = GetSuccessResult(deleteCorpusDocument);
    using var postDeleteLibraryDocument = await engineClient.InvokeAsync(
        EngineContracts.Methods.LibraryList,
        new
        {
            folderId = "all"
        }
    );
    var postDeleteLibraryResult = GetSuccessResult(postDeleteLibraryDocument);

    var payload = new
    {
        userDataDir = tempUserDataDir,
        nodePath = engineClient.ResolvedNodePath,
        engineEntry = engineClient.ResolvedEngineEntryPath,
        appInfoVersion = appInfoResult.TryGetProperty("appInfo", out var appInfoElement)
            ? ReadString(appInfoElement, "version", string.Empty)
            : string.Empty,
        createdFolderId,
        importedCount = ReadInt(importResult, "importedCount"),
        libraryCorpusCount = ReadInt(libraryResult, "totalCount"),
        openedCorpus = new
        {
            corpusId = ReadString(openSavedResult, "corpusId", string.Empty),
            displayName = ReadString(openSavedResult, "displayName", string.Empty),
            folderName = ReadString(openSavedResult, "folderName", string.Empty)
        },
        workspace = new
        {
            savedTab = workspaceSaveResult.TryGetProperty("snapshot", out var savedSnapshot)
                ? ReadString(savedSnapshot, "currentTab", string.Empty)
                : string.Empty,
            savedFolderId = workspaceSaveResult.TryGetProperty("snapshot", out var savedFolderSnapshot)
                ? ReadString(savedFolderSnapshot, "currentLibraryFolderId", string.Empty)
                : string.Empty,
            savedWorkspaceCorpusCount = workspaceSaveResult.TryGetProperty("snapshot", out var savedWorkspaceSnapshot)
                && savedWorkspaceSnapshot.TryGetProperty("workspace", out var savedWorkspaceElement)
                && savedWorkspaceElement.TryGetProperty("corpusIds", out var savedCorpusIdsElement)
                && savedCorpusIdsElement.ValueKind == JsonValueKind.Array
                    ? savedCorpusIdsElement.GetArrayLength()
                    : 0,
            restoredTab = workspaceStateResult.TryGetProperty("snapshot", out var restoredSnapshot)
                ? ReadString(restoredSnapshot, "currentTab", string.Empty)
                : string.Empty,
            restoredFolderId = workspaceStateResult.TryGetProperty("snapshot", out var restoredFolderSnapshot)
                ? ReadString(restoredFolderSnapshot, "currentLibraryFolderId", string.Empty)
                : string.Empty,
            restoredWorkspaceCorpusCount = workspaceStateResult.TryGetProperty("snapshot", out var restoredWorkspaceSnapshot)
                && restoredWorkspaceSnapshot.TryGetProperty("workspace", out var restoredWorkspaceElement)
                && restoredWorkspaceElement.TryGetProperty("corpusIds", out var restoredCorpusIdsElement)
                && restoredCorpusIdsElement.ValueKind == JsonValueKind.Array
                    ? restoredCorpusIdsElement.GetArrayLength()
                    : 0,
            restoredQuery = workspaceStateResult.TryGetProperty("snapshot", out var snapshotElement)
                && snapshotElement.TryGetProperty("search", out var searchElement)
                    ? ReadString(searchElement, "query", string.Empty)
                    : string.Empty
        },
        stats = new
        {
            tokenCount = ReadInt(statsResult, "tokenCount"),
            typeCount = ReadInt(statsResult, "typeCount"),
            freqRowCount = statsResult.TryGetProperty("freqRows", out var statsRows) && statsRows.ValueKind == JsonValueKind.Array
                ? statsRows.GetArrayLength()
                : 0
        },
        kwic = new
        {
            hitCount = kwicResult.TryGetProperty("rows", out var kwicRows) && kwicRows.ValueKind == JsonValueKind.Array
                ? kwicRows.GetArrayLength()
                : 0
        },
        locator = new
        {
            rowCount = locatorResult.TryGetProperty("rows", out var locatorRows) && locatorRows.ValueKind == JsonValueKind.Array
                ? locatorRows.GetArrayLength()
                : 0,
            focusStatus = locatorResult.TryGetProperty("rows", out var locatorStatusRows)
                && locatorStatusRows.ValueKind == JsonValueKind.Array
                && locatorStatusRows.EnumerateArray().Any(row => ReadString(row, "status", string.Empty).Length > 0)
                    ? "found"
                    : string.Empty
        },
        collocate = new
        {
            rowCount = collocateResult.TryGetProperty("rows", out var collocateRows) && collocateRows.ValueKind == JsonValueKind.Array
                ? collocateRows.GetArrayLength()
                : 0,
            topWord = collocateResult.TryGetProperty("rows", out var topRows)
                && topRows.ValueKind == JsonValueKind.Array
                && topRows.GetArrayLength() > 0
                    ? ReadString(topRows[0], "word", string.Empty)
                    : string.Empty
        },
        delete = new
        {
            recycleEntryId = ReadString(deleteCorpusResult, "recycleEntryId", string.Empty),
            remainingCorpusCount = ReadInt(postDeleteLibraryResult, "totalCount")
        }
    };

    Console.WriteLine(JsonSerializer.Serialize(payload, new JsonSerializerOptions
    {
        WriteIndented = true
    }));
}
catch (Exception exception)
{
    Console.Error.WriteLine(exception);
    Environment.ExitCode = 1;
}
finally
{
    try
    {
        Directory.Delete(tempUserDataDir, recursive: true);
    }
    catch
    {
        // Ignore cleanup failures.
    }
}

static JsonElement GetSuccessResult(JsonDocument? document)
{
    if (document is null)
    {
        throw new InvalidOperationException("The engine returned no response.");
    }

    var root = document.RootElement;
    if (root.TryGetProperty("error", out var errorElement))
    {
        throw new InvalidOperationException(ReadString(errorElement, "message", "Unknown JSON-RPC error."));
    }

    if (!root.TryGetProperty("result", out var resultElement))
    {
        throw new InvalidOperationException("The engine response is missing the result payload.");
    }

    if (resultElement.TryGetProperty("success", out var successElement)
        && successElement.ValueKind == JsonValueKind.False)
    {
        throw new InvalidOperationException(ReadString(resultElement, "message", "The engine returned an unsuccessful result."));
    }

    return resultElement.Clone();
}

static async Task<JsonElement> StartAndWaitForTaskResultAsync(EngineClient engineClient, string taskType, object payload)
{
    using var startDocument = await engineClient.InvokeAsync(
        EngineContracts.Methods.AnalysisStartTask,
        new
        {
            taskType,
            payload
        }
    );
    var startResult = GetSuccessResult(startDocument);
    var taskId = ReadString(startResult, "taskId", string.Empty);
    if (string.IsNullOrWhiteSpace(taskId))
    {
        throw new InvalidOperationException("The engine did not return a task id.");
    }

    for (var attempt = 0; attempt < 100; attempt += 1)
    {
        await Task.Delay(100);
        using var taskDocument = await engineClient.InvokeAsync(
            EngineContracts.Methods.AnalysisGetTaskState,
            new
            {
                taskId
            }
        );

        var taskResult = GetSuccessResult(taskDocument);
        if (!taskResult.TryGetProperty("task", out var taskElement))
        {
            throw new InvalidOperationException("Task state payload is missing the task object.");
        }

        var status = ReadString(taskElement, "status", "running");
        if (string.Equals(status, "completed", StringComparison.OrdinalIgnoreCase))
        {
            if (!taskElement.TryGetProperty("result", out var resultElement))
            {
                throw new InvalidOperationException("Completed task payload is missing the result object.");
            }

            return resultElement.Clone();
        }

        if (string.Equals(status, "failed", StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidOperationException(ReadString(taskElement, "error", "Task failed."));
        }
    }

    throw new TimeoutException($"Timed out while waiting for {taskType}.");
}

static CorpusEntry[] BuildComparisonEntries(JsonElement openBatchResult)
{
    if (openBatchResult.TryGetProperty("comparisonEntries", out var comparisonEntriesElement)
        && comparisonEntriesElement.ValueKind == JsonValueKind.Array
        && comparisonEntriesElement.GetArrayLength() > 0)
    {
        return comparisonEntriesElement
            .EnumerateArray()
            .Select(entry => new CorpusEntry(
                CorpusId: ReadString(entry, "corpusId", string.Empty),
                CorpusName: ReadString(entry, "corpusName", "Untitled corpus"),
                FolderId: ReadString(entry, "folderId", string.Empty),
                FolderName: ReadString(entry, "folderName", "Uncategorized"),
                SourceType: ReadString(entry, "sourceType", "txt"),
                ContentLength: ReadInt(entry, "contentLength"),
                ContentFingerprint: ReadString(entry, "contentFingerprint", string.Empty),
                Content: ReadString(entry, "content", string.Empty)
            ))
            .ToArray();
    }

    var content = ReadString(openBatchResult, "content", string.Empty);
    if (string.IsNullOrWhiteSpace(content))
    {
        return Array.Empty<CorpusEntry>();
    }

    return new[]
    {
        new CorpusEntry(
            CorpusId: ReadString(openBatchResult, "corpusId", string.Empty),
            CorpusName: ReadString(openBatchResult, "displayName", "Untitled corpus"),
            FolderId: ReadString(openBatchResult, "folderId", string.Empty),
            FolderName: ReadString(openBatchResult, "folderName", "Uncategorized"),
            SourceType: ReadString(openBatchResult, "sourceType", "txt"),
            ContentLength: content.Length,
            ContentFingerprint: string.Empty,
            Content: content
        )
    };
}

static string ReadString(JsonElement element, string propertyName, string fallback)
{
    if (!element.TryGetProperty(propertyName, out var propertyElement))
    {
        return fallback;
    }

    return propertyElement.ValueKind == JsonValueKind.String
        ? propertyElement.GetString() ?? fallback
        : propertyElement.GetRawText();
}

static int ReadInt(JsonElement element, string propertyName)
{
    if (!element.TryGetProperty(propertyName, out var propertyElement))
    {
        return 0;
    }

    if (propertyElement.TryGetInt32(out var value))
    {
        return value;
    }

    return propertyElement.ValueKind == JsonValueKind.String && int.TryParse(propertyElement.GetString(), out var parsed)
        ? parsed
        : 0;
}

internal sealed record CorpusEntry(
    string CorpusId,
    string CorpusName,
    string FolderId,
    string FolderName,
    string SourceType,
    int ContentLength,
    string ContentFingerprint,
    string Content
);
