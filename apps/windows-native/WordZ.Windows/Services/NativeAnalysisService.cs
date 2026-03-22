using System.Text.Json;
using WordZ.Windows.Contracts;
using WordZ.Windows.Models;
using WordZ.Windows.ViewModels;

namespace WordZ.Windows.Services;

public sealed class NativeAnalysisService
{
    private readonly EngineClient _engineClient;
    private readonly NativeLibraryService _libraryService;
    private readonly NativeShellState _shell;

    public NativeAnalysisService(EngineClient engineClient, NativeLibraryService libraryService, NativeShellState shell)
    {
        _engineClient = engineClient;
        _libraryService = libraryService;
        _shell = shell;
    }

    public IReadOnlyList<AnalysisScopeOption> BuildScopeOptions()
    {
        var options = new List<AnalysisScopeOption>
        {
            new()
            {
                Id = "all",
                Label = "All local corpora"
            }
        };

        if (_shell.WorkspaceCorpusCount > 0)
        {
            options.Add(new AnalysisScopeOption
            {
                Id = "workspace",
                Label = _shell.WorkspaceCorpusCount == 1
                    ? "Current workspace (1 corpus)"
                    : $"Current workspace ({_shell.WorkspaceCorpusCount} corpora)"
            });
        }

        if (!string.IsNullOrWhiteSpace(_shell.SelectedFolderId)
            && !string.Equals(_shell.SelectedFolderId, "all", StringComparison.OrdinalIgnoreCase))
        {
            options.Add(new AnalysisScopeOption
            {
                Id = "current",
                Label = $"Current folder ({_shell.SelectedFolderLabel})"
            });
        }

        foreach (var folder in _shell.Folders)
        {
            options.Add(new AnalysisScopeOption
            {
                Id = $"folder:{folder.Id}",
                Label = $"Folder: {folder.Name}"
            });
        }

        foreach (var item in _shell.Items
            .OrderBy(item => item.FolderName, StringComparer.OrdinalIgnoreCase)
            .ThenBy(item => item.Name, StringComparer.OrdinalIgnoreCase))
        {
            options.Add(new AnalysisScopeOption
            {
                Id = $"corpus:{item.Id}",
                Label = $"Corpus: {item.Name} ({item.FolderName})"
            });
        }

        return options
            .GroupBy(option => option.Id, StringComparer.OrdinalIgnoreCase)
            .Select(group => group.First())
            .ToArray();
    }

    public async Task<StatsAnalysisResult> RunStatsAsync(AnalysisScopeOption? scopeOption, CancellationToken cancellationToken = default)
    {
        var batch = await LoadCorpusBatchAsync(scopeOption, cancellationToken);
        var payload = new
        {
            text = batch.CombinedText,
            comparisonEntries = batch.Entries.Count >= 2
                ? batch.Entries.Select(entry => new
                {
                    corpusId = entry.CorpusId,
                    corpusName = entry.CorpusName,
                    folderId = entry.FolderId,
                    folderName = entry.FolderName,
                    sourceType = entry.SourceType,
                    contentLength = entry.ContentLength,
                    contentFingerprint = entry.ContentFingerprint,
                    content = entry.Content
                }).ToArray()
                : Array.Empty<object>()
        };

        var resultElement = await StartAndWaitForTaskResultAsync("stats", payload, cancellationToken);
        var frequencyRows = ParseFrequencyRows(resultElement);
        var corpusSummaries = ParseCorpusSummaries(resultElement);

        return new StatsAnalysisResult
        {
            ScopeLabel = batch.ScopeLabel,
            CorpusCount = batch.Entries.Count,
            TokenCount = ReadInt(resultElement, "tokenCount"),
            TypeCount = ReadInt(resultElement, "typeCount"),
            Ttr = ReadDouble(resultElement, "ttr"),
            Sttr = ReadDouble(resultElement, "sttr"),
            FrequencyRows = frequencyRows,
            CorpusSummaries = corpusSummaries
        };
    }

    public async Task<KwicAnalysisResult> RunKwicAsync(
        AnalysisScopeOption? scopeOption,
        string keyword,
        string leftWindowSize,
        string rightWindowSize,
        string sortMode,
        CancellationToken cancellationToken = default)
    {
        var cleanKeyword = StringValue(keyword);
        if (string.IsNullOrWhiteSpace(cleanKeyword))
        {
            throw new InvalidOperationException("Enter a keyword before running KWIC.");
        }

        var batch = await LoadCorpusBatchAsync(scopeOption, cancellationToken);
        var payload = new
        {
            corpusEntries = batch.Entries.Select(entry => new
            {
                corpusId = entry.CorpusId,
                corpusName = entry.CorpusName,
                folderId = entry.FolderId,
                folderName = entry.FolderName,
                sourceType = entry.SourceType,
                content = entry.Content
            }).ToArray(),
            keyword = cleanKeyword,
            leftWindowSize = ParsePositiveInt(leftWindowSize, 5, "Left context size"),
            rightWindowSize = ParsePositiveInt(rightWindowSize, 5, "Right context size"),
            sortMode = StringValue(sortMode, "original"),
            searchOptions = new
            {
                words = true,
                caseSensitive = false,
                regex = false
            }
        };

        var resultElement = await StartAndWaitForTaskResultAsync("library-kwic", payload, cancellationToken);
        var rows = ParseKwicRows(resultElement);

        return new KwicAnalysisResult
        {
            ScopeLabel = batch.ScopeLabel,
            CorpusCount = batch.Entries.Count,
            HitCount = rows.Count,
            Rows = rows
        };
    }

    public async Task<CollocateAnalysisResult> RunCollocateAsync(
        AnalysisScopeOption? scopeOption,
        string keyword,
        string windowSize,
        string minimumFrequency,
        CancellationToken cancellationToken = default)
    {
        var cleanKeyword = StringValue(keyword);
        if (string.IsNullOrWhiteSpace(cleanKeyword))
        {
            throw new InvalidOperationException("Enter a node word before running Collocate.");
        }

        var batch = await LoadCorpusBatchAsync(scopeOption, cancellationToken);
        var window = ParsePositiveInt(windowSize, 5, "Window size");
        var minFreq = ParsePositiveInt(minimumFrequency, 1, "Minimum frequency");

        var resultElement = await StartAndWaitForTaskResultAsync(
            "collocate",
            new
            {
                text = batch.CombinedText,
                keyword = cleanKeyword,
                leftWindowSize = window,
                rightWindowSize = window,
                minFreq,
                searchOptions = new
                {
                    words = true,
                    caseSensitive = false,
                    regex = false
                }
            },
            cancellationToken
        );
        var rows = ParseCollocateRows(resultElement);

        return new CollocateAnalysisResult
        {
            ScopeLabel = batch.ScopeLabel,
            CorpusCount = batch.Entries.Count,
            RowCount = rows.Count,
            Rows = rows
        };
    }

    public async Task<LocatorAnalysisResult> RunLocatorAsync(
        LocatorNavigationRequest request,
        string leftWindowSize,
        string rightWindowSize,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(request.CorpusId))
        {
            throw new InvalidOperationException("Choose a corpus before opening Locator.");
        }

        var openedCorpus = await _libraryService.OpenCorpusAsync(request.CorpusId, cancellationToken);
        if (string.IsNullOrWhiteSpace(openedCorpus.Content))
        {
            throw new InvalidOperationException("The selected corpus could not be opened for Locator.");
        }

        var leftWindow = ParsePositiveInt(leftWindowSize, request.LeftWindowSize, "Left context size");
        var rightWindow = ParsePositiveInt(rightWindowSize, request.RightWindowSize, "Right context size");
        var resultElement = await StartAndWaitForTaskResultAsync(
            "locator",
            new
            {
                text = openedCorpus.Content,
                sentenceId = request.SentenceId,
                nodeIndex = request.NodeIndex,
                leftWindowSize = leftWindow,
                rightWindowSize = rightWindow
            },
            cancellationToken
        );

        var rows = ParseLocatorRows(resultElement);
        return new LocatorAnalysisResult
        {
            CorpusName = string.IsNullOrWhiteSpace(request.CorpusName) ? openedCorpus.DisplayName : request.CorpusName,
            FolderName = string.IsNullOrWhiteSpace(request.FolderName) ? openedCorpus.FolderName : request.FolderName,
            Keyword = request.Keyword,
            SentenceId = request.SentenceId,
            NodeIndex = request.NodeIndex,
            SentenceCount = rows.Count,
            Rows = rows
        };
    }

    private async Task<CorpusBatch> LoadCorpusBatchAsync(AnalysisScopeOption? scopeOption, CancellationToken cancellationToken)
    {
        var resolvedScope = ResolveScope(scopeOption);
        if (resolvedScope.CorpusIds.Count == 0)
        {
            throw new InvalidOperationException($"No saved corpora are available in {resolvedScope.ScopeLabel}.");
        }

        using var document = await _engineClient.InvokeAsync(
            EngineContracts.Methods.LibraryOpenSavedBatch,
            new
            {
                corpusIds = resolvedScope.CorpusIds
            },
            cancellationToken
        );
        var resultElement = GetSuccessResult(document?.RootElement);
        var entries = ParseBatchEntries(resultElement);
        if (entries.Count == 0)
        {
            throw new InvalidOperationException($"The selected corpora in {resolvedScope.ScopeLabel} could not be opened.");
        }

        return new CorpusBatch(
            resolvedScope.ScopeLabel,
            entries,
            string.Join(Environment.NewLine + Environment.NewLine, entries.Select(entry => entry.Content))
        );
    }

    private ScopeResolution ResolveScope(AnalysisScopeOption? scopeOption)
    {
        var selectedOption = scopeOption ?? BuildScopeOptions().First();
        var scopeId = StringValue(selectedOption.Id, "all");
        var scopeLabel = StringValue(selectedOption.Label, "All local corpora");

        IEnumerable<LibraryCorpusInfo> selectedItems = ResolveScopeItems(scopeId);

        return new ScopeResolution(
            scopeLabel,
            selectedItems
                .Select(item => item.Id)
                .Where(item => !string.IsNullOrWhiteSpace(item))
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .ToArray()
        );
    }

    private IEnumerable<LibraryCorpusInfo> ResolveCurrentFolderItems()
    {
        if (string.IsNullOrWhiteSpace(_shell.SelectedFolderId)
            || string.Equals(_shell.SelectedFolderId, "all", StringComparison.OrdinalIgnoreCase))
        {
            return _shell.Items;
        }

        return _shell.Items.Where(item => string.Equals(item.FolderId, _shell.SelectedFolderId, StringComparison.OrdinalIgnoreCase));
    }

    private IEnumerable<LibraryCorpusInfo> ResolveScopeItems(string scopeId)
    {
        if (string.Equals(scopeId, "all", StringComparison.OrdinalIgnoreCase))
        {
            return _shell.Items;
        }

        if (string.Equals(scopeId, "workspace", StringComparison.OrdinalIgnoreCase))
        {
            return _shell.GetWorkspaceItems();
        }

        if (string.Equals(scopeId, "current", StringComparison.OrdinalIgnoreCase))
        {
            return ResolveCurrentFolderItems();
        }

        if (scopeId.StartsWith("folder:", StringComparison.OrdinalIgnoreCase))
        {
            var folderId = scopeId["folder:".Length..];
            return _shell.Items.Where(item => string.Equals(item.FolderId, folderId, StringComparison.OrdinalIgnoreCase));
        }

        if (scopeId.StartsWith("corpus:", StringComparison.OrdinalIgnoreCase))
        {
            var corpusId = scopeId["corpus:".Length..];
            return _shell.Items.Where(item => string.Equals(item.Id, corpusId, StringComparison.OrdinalIgnoreCase));
        }

        return _shell.Items.Where(item => string.Equals(item.FolderId, scopeId, StringComparison.OrdinalIgnoreCase));
    }

    private async Task<JsonElement> StartAndWaitForTaskResultAsync(string taskType, object payload, CancellationToken cancellationToken)
    {
        string? taskId = null;

        try
        {
            using var startDocument = await _engineClient.InvokeAsync(
                EngineContracts.Methods.AnalysisStartTask,
                new
                {
                    taskType,
                    payload
                },
                cancellationToken
            );

            var startResult = GetSuccessResult(startDocument?.RootElement);
            taskId = ReadString(startResult, "taskId", string.Empty);
            if (string.IsNullOrWhiteSpace(taskId))
            {
                throw new InvalidOperationException("The engine did not return a task id.");
            }

            for (var attempt = 0; attempt < 200; attempt += 1)
            {
                cancellationToken.ThrowIfCancellationRequested();
                await Task.Delay(100, cancellationToken);

                using var stateDocument = await _engineClient.InvokeAsync(
                    EngineContracts.Methods.AnalysisGetTaskState,
                    new
                    {
                        taskId
                    },
                    cancellationToken
                );

                var stateResult = GetSuccessResult(stateDocument?.RootElement);
                if (!stateResult.TryGetProperty("task", out var taskElement))
                {
                    throw new InvalidOperationException("The engine task state payload is missing the task object.");
                }

                var status = ReadString(taskElement, "status", "running");
                if (string.Equals(status, "completed", StringComparison.OrdinalIgnoreCase))
                {
                    if (!taskElement.TryGetProperty("result", out var resultElement))
                    {
                        throw new InvalidOperationException("The engine task completed without a result payload.");
                    }

                    return resultElement.Clone();
                }

                if (string.Equals(status, "failed", StringComparison.OrdinalIgnoreCase))
                {
                    throw new InvalidOperationException(ReadString(taskElement, "error", "The engine task failed."));
                }

                if (string.Equals(status, "cancelled", StringComparison.OrdinalIgnoreCase))
                {
                    throw new InvalidOperationException("The engine task was cancelled.");
                }
            }

            throw new TimeoutException($"Timed out while waiting for '{taskType}' to finish.");
        }
        catch (OperationCanceledException)
        {
            if (!string.IsNullOrWhiteSpace(taskId))
            {
                await TryCancelTaskAsync(taskId);
            }

            throw;
        }
    }

    private async Task TryCancelTaskAsync(string taskId)
    {
        try
        {
            using var _ = await _engineClient.InvokeAsync(
                EngineContracts.Methods.AnalysisCancelTask,
                new
                {
                    taskId
                }
            );
        }
        catch
        {
            // Ignore cleanup failures.
        }
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

    private static IReadOnlyList<CorpusBatchEntry> ParseBatchEntries(JsonElement resultElement)
    {
        if (resultElement.TryGetProperty("comparisonEntries", out var comparisonEntriesElement)
            && comparisonEntriesElement.ValueKind == JsonValueKind.Array
            && comparisonEntriesElement.GetArrayLength() > 0)
        {
            return comparisonEntriesElement
                .EnumerateArray()
                .Select(entry => new CorpusBatchEntry(
                    CorpusId: ReadString(entry, "corpusId", string.Empty),
                    CorpusName: ReadString(entry, "corpusName", "Untitled corpus"),
                    FolderId: ReadString(entry, "folderId", string.Empty),
                    FolderName: ReadString(entry, "folderName", "Uncategorized"),
                    SourceType: ReadString(entry, "sourceType", "txt"),
                    Content: ReadString(entry, "content", string.Empty),
                    ContentLength: ReadInt(entry, "contentLength"),
                    ContentFingerprint: ReadString(entry, "contentFingerprint", string.Empty)
                ))
                .Where(entry => !string.IsNullOrWhiteSpace(entry.Content))
                .ToArray();
        }

        var singleContent = ReadString(resultElement, "content", string.Empty);
        if (!string.IsNullOrWhiteSpace(singleContent))
        {
            return new[]
            {
                new CorpusBatchEntry(
                    CorpusId: ReadString(resultElement, "corpusId", string.Empty),
                    CorpusName: ReadString(resultElement, "displayName", "Untitled corpus"),
                    FolderId: ReadString(resultElement, "folderId", string.Empty),
                    FolderName: ReadString(resultElement, "folderName", "Uncategorized"),
                    SourceType: ReadString(resultElement, "sourceType", "txt"),
                    Content: singleContent,
                    ContentLength: singleContent.Length,
                    ContentFingerprint: string.Empty
                )
            };
        }

        return Array.Empty<CorpusBatchEntry>();
    }

    private static IReadOnlyList<StatsFrequencyRow> ParseFrequencyRows(JsonElement resultElement)
    {
        if (!resultElement.TryGetProperty("freqRows", out var rowsElement) || rowsElement.ValueKind != JsonValueKind.Array)
        {
            return Array.Empty<StatsFrequencyRow>();
        }

        var rows = new List<StatsFrequencyRow>();
        var rank = 1;
        foreach (var rowElement in rowsElement.EnumerateArray().Take(100))
        {
            if (rowElement.ValueKind != JsonValueKind.Array || rowElement.GetArrayLength() < 2)
            {
                continue;
            }

            var values = rowElement.EnumerateArray().ToArray();
            rows.Add(new StatsFrequencyRow
            {
                Rank = rank++,
                Word = values[0].ValueKind == JsonValueKind.String ? values[0].GetString() ?? string.Empty : values[0].GetRawText(),
                Count = values[1].TryGetInt32(out var count) ? count : 0
            });
        }

        return rows;
    }

    private static IReadOnlyList<CorpusComparisonSummary> ParseCorpusSummaries(JsonElement resultElement)
    {
        if (!resultElement.TryGetProperty("compareCorpora", out var corporaElement) || corporaElement.ValueKind != JsonValueKind.Array)
        {
            return Array.Empty<CorpusComparisonSummary>();
        }

        return corporaElement
            .EnumerateArray()
            .Select(entry => new CorpusComparisonSummary
            {
                CorpusName = ReadString(entry, "corpusName", "Untitled corpus"),
                FolderName = ReadString(entry, "folderName", "Uncategorized"),
                TokenCount = ReadInt(entry, "tokenCount"),
                TypeCount = ReadInt(entry, "typeCount"),
                Ttr = ReadDouble(entry, "ttr"),
                Sttr = ReadDouble(entry, "sttr"),
                TopWord = ReadString(entry, "topWord", string.Empty),
                TopWordCount = ReadInt(entry, "topWordCount")
            })
            .ToArray();
    }

    private static IReadOnlyList<KwicResultRow> ParseKwicRows(JsonElement resultElement)
    {
        if (!resultElement.TryGetProperty("rows", out var rowsElement) || rowsElement.ValueKind != JsonValueKind.Array)
        {
            return Array.Empty<KwicResultRow>();
        }

        var rows = new List<KwicResultRow>();
        var rank = 1;
        foreach (var entry in rowsElement.EnumerateArray())
        {
            rows.Add(new KwicResultRow
            {
                Rank = rank++,
                CorpusId = ReadString(entry, "corpusId", string.Empty),
                CorpusName = ReadString(entry, "corpusName", string.Empty),
                FolderId = ReadString(entry, "folderId", string.Empty),
                FolderName = ReadString(entry, "folderName", string.Empty),
                SourceType = ReadString(entry, "sourceType", "txt"),
                Left = ReadString(entry, "left", string.Empty),
                Node = ReadString(entry, "node", string.Empty),
                Right = ReadString(entry, "right", string.Empty),
                SentenceId = ReadInt(entry, "sentenceId"),
                SentenceTokenIndex = ReadInt(entry, "sentenceTokenIndex"),
                OriginalIndex = ReadInt(entry, "originalIndex")
            });
        }

        return rows;
    }

    private static IReadOnlyList<LocatorResultRow> ParseLocatorRows(JsonElement resultElement)
    {
        if (!resultElement.TryGetProperty("rows", out var rowsElement) || rowsElement.ValueKind != JsonValueKind.Array)
        {
            return Array.Empty<LocatorResultRow>();
        }

        return rowsElement
            .EnumerateArray()
            .Select(entry => new LocatorResultRow
            {
                SentenceId = ReadInt(entry, "sentenceId"),
                LeftWords = ReadString(entry, "leftWords", string.Empty),
                NodeWord = ReadString(entry, "nodeWord", string.Empty),
                RightWords = ReadString(entry, "rightWords", string.Empty),
                Text = ReadString(entry, "text", string.Empty),
                Status = ReadString(entry, "status", string.Empty)
            })
            .ToArray();
    }

    private static IReadOnlyList<CollocateResultRow> ParseCollocateRows(JsonElement resultElement)
    {
        if (!resultElement.TryGetProperty("rows", out var rowsElement) || rowsElement.ValueKind != JsonValueKind.Array)
        {
            return Array.Empty<CollocateResultRow>();
        }

        var rows = new List<CollocateResultRow>();
        var rank = 1;
        foreach (var entry in rowsElement.EnumerateArray())
        {
            rows.Add(new CollocateResultRow
            {
                Rank = rank++,
                Word = ReadString(entry, "word", string.Empty),
                Total = ReadInt(entry, "total"),
                Left = ReadInt(entry, "left"),
                Right = ReadInt(entry, "right"),
                Rate = ReadDouble(entry, "rate")
            });
        }

        return rows;
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

    private static int ReadInt(JsonElement element, string propertyName)
    {
        if (!element.TryGetProperty(propertyName, out var propertyElement))
        {
            return 0;
        }

        if (propertyElement.TryGetInt32(out var value))
        {
            return value;
        }

        if (propertyElement.ValueKind == JsonValueKind.String
            && int.TryParse(propertyElement.GetString(), out var parsed))
        {
            return parsed;
        }

        return 0;
    }

    private static double ReadDouble(JsonElement element, string propertyName)
    {
        if (!element.TryGetProperty(propertyName, out var propertyElement))
        {
            return 0;
        }

        if (propertyElement.TryGetDouble(out var value))
        {
            return value;
        }

        if (propertyElement.ValueKind == JsonValueKind.String
            && double.TryParse(propertyElement.GetString(), out var parsed))
        {
            return parsed;
        }

        return 0;
    }

    private static int ParsePositiveInt(string rawValue, int fallbackValue, string fieldName)
    {
        if (!int.TryParse(StringValue(rawValue), out var parsed) || parsed <= 0)
        {
            throw new InvalidOperationException($"{fieldName} must be a positive integer.");
        }

        return parsed > 2000 ? fallbackValue : parsed;
    }

    private static string StringValue(string? value, string fallbackValue = "")
    {
        var normalized = (value ?? string.Empty).Trim();
        return string.IsNullOrWhiteSpace(normalized) ? fallbackValue : normalized;
    }

    private sealed record ScopeResolution(string ScopeLabel, IReadOnlyList<string> CorpusIds);

    private sealed record CorpusBatch(string ScopeLabel, IReadOnlyList<CorpusBatchEntry> Entries, string CombinedText);

    private sealed record CorpusBatchEntry(
        string CorpusId,
        string CorpusName,
        string FolderId,
        string FolderName,
        string SourceType,
        string Content,
        int ContentLength,
        string ContentFingerprint
    );
}
