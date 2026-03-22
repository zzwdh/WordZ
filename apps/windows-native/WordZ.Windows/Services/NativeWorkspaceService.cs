using System.Text.Json;
using System.Text.Json.Nodes;
using WordZ.Windows.Contracts;

namespace WordZ.Windows.Services;

public sealed class NativeWorkspaceService
{
    private readonly EngineClient _engineClient;
    private readonly SemaphoreSlim _gate = new(1, 1);
    private JsonObject _snapshot = CreateDefaultSnapshot();
    private bool _initialized;

    public NativeWorkspaceService(EngineClient engineClient)
    {
        _engineClient = engineClient;
    }

    public async Task InitializeAsync(CancellationToken cancellationToken = default)
    {
        if (_initialized)
        {
            return;
        }

        await _gate.WaitAsync(cancellationToken);
        try
        {
            if (_initialized)
            {
                return;
            }

            using var document = await _engineClient.InvokeAsync(
                EngineContracts.Methods.WorkspaceGetState,
                cancellationToken: cancellationToken
            );
            if (document is not null
                && document.RootElement.TryGetProperty("result", out var resultElement)
                && resultElement.TryGetProperty("snapshot", out var snapshotElement)
                && snapshotElement.ValueKind == JsonValueKind.Object)
            {
                _snapshot = JsonNode.Parse(snapshotElement.GetRawText()) as JsonObject ?? CreateDefaultSnapshot();
            }
            else
            {
                _snapshot = CreateDefaultSnapshot();
            }

            _initialized = true;
            NativeTrace.Write($"Workspace initialized. CurrentTab='{GetCurrentTab()}'");
        }
        finally
        {
            _gate.Release();
        }
    }

    public string GetCurrentTab()
    {
        return GetString("currentTab", "stats");
    }

    public string GetCurrentLibraryFolderId()
    {
        return GetString("currentLibraryFolderId", "all");
    }

    public IReadOnlyList<string> GetWorkspaceCorpusIds()
    {
        if (_snapshot["workspace"] is not JsonObject workspace
            || workspace["corpusIds"] is not JsonArray corpusIds)
        {
            return Array.Empty<string>();
        }

        return corpusIds
            .Select(node => node?.GetValue<string>()?.Trim() ?? string.Empty)
            .Where(value => !string.IsNullOrWhiteSpace(value))
            .ToArray();
    }

    public string GetStatsScopeId()
    {
        return GetString("stats", "scope", "all");
    }

    public string GetStatsProfile()
    {
        return GetString("stats", "profile", "Frequencies / lengths / overview");
    }

    public string GetStatsNotes()
    {
        return GetString("stats", "notes", string.Empty);
    }

    public string GetSearchQuery()
    {
        return GetString("search", "query", string.Empty);
    }

    public string GetKwicScopeId()
    {
        return GetString("kwic", "scope", "current");
    }

    public string GetKwicSortMode()
    {
        return GetString("kwic", "sortMode", "original");
    }

    public string GetKwicLeftWindow()
    {
        return GetString("kwic", "leftWindow", "5");
    }

    public string GetKwicRightWindow()
    {
        return GetString("kwic", "rightWindow", "5");
    }

    public string GetCollocateScopeId()
    {
        return GetString("collocate", "scope", "current");
    }

    public string GetCollocateWindow()
    {
        return GetString("collocate", "leftWindow", "5");
    }

    public string GetCollocateMinimumFrequency()
    {
        return GetString("collocate", "minFreq", "1");
    }

    public string GetLocatorCorpusId()
    {
        return GetString("locator", "corpusId", string.Empty);
    }

    public string GetLocatorCorpusName()
    {
        return GetString("locator", "corpusName", string.Empty);
    }

    public string GetLocatorFolderName()
    {
        return GetString("locator", "folderName", string.Empty);
    }

    public string GetLocatorKeyword()
    {
        return GetString("locator", "keyword", string.Empty);
    }

    public int GetLocatorSentenceId()
    {
        return GetInt("locator", "sentenceId", 0);
    }

    public int GetLocatorNodeIndex()
    {
        return GetInt("locator", "nodeIndex", 0);
    }

    public string GetLocatorLeftWindow()
    {
        return GetString("locator", "leftWindow", "5");
    }

    public string GetLocatorRightWindow()
    {
        return GetString("locator", "rightWindow", "5");
    }

    public Task SaveCurrentTabAsync(string tag, CancellationToken cancellationToken = default)
    {
        return UpdateSnapshotAsync(snapshot =>
        {
            snapshot["currentTab"] = tag;
        }, cancellationToken);
    }

    public Task SaveCurrentLibraryFolderIdAsync(string folderId, CancellationToken cancellationToken = default)
    {
        return UpdateSnapshotAsync(snapshot =>
        {
            snapshot["currentLibraryFolderId"] = string.IsNullOrWhiteSpace(folderId) ? "all" : folderId;
        }, cancellationToken);
    }

    public Task SaveWorkspaceSelectionAsync(
        IReadOnlyList<string> corpusIds,
        IReadOnlyList<string> corpusNames,
        CancellationToken cancellationToken = default)
    {
        return UpdateSnapshotAsync(snapshot =>
        {
            var workspace = EnsureObject(snapshot, "workspace");
            workspace["corpusIds"] = new JsonArray(corpusIds.Select(id => JsonValue.Create(id)).ToArray());
            workspace["corpusNames"] = new JsonArray(corpusNames.Select(name => JsonValue.Create(name)).ToArray());
        }, cancellationToken);
    }

    public Task SaveStatsStateAsync(string scopeId, string profile, string notes, CancellationToken cancellationToken = default)
    {
        return UpdateSnapshotAsync(snapshot =>
        {
            var stats = EnsureObject(snapshot, "stats");
            stats["scope"] = string.IsNullOrWhiteSpace(scopeId) ? "all" : scopeId;
            stats["profile"] = profile ?? string.Empty;
            stats["notes"] = notes ?? string.Empty;
        }, cancellationToken);
    }

    public Task SaveKwicStateAsync(
        string query,
        string scopeId,
        string sortMode,
        string leftWindow,
        string rightWindow,
        CancellationToken cancellationToken = default)
    {
        return UpdateSnapshotAsync(snapshot =>
        {
            var search = EnsureObject(snapshot, "search");
            search["query"] = query ?? string.Empty;

            var kwic = EnsureObject(snapshot, "kwic");
            kwic["scope"] = string.IsNullOrWhiteSpace(scopeId) ? "current" : scopeId;
            kwic["sortMode"] = string.IsNullOrWhiteSpace(sortMode) ? "original" : sortMode;
            kwic["leftWindow"] = string.IsNullOrWhiteSpace(leftWindow) ? "5" : leftWindow;
            kwic["rightWindow"] = string.IsNullOrWhiteSpace(rightWindow) ? "5" : rightWindow;
        }, cancellationToken);
    }

    public Task SaveCollocateStateAsync(
        string query,
        string scopeId,
        string windowSize,
        string minFreq,
        CancellationToken cancellationToken = default)
    {
        return UpdateSnapshotAsync(snapshot =>
        {
            var search = EnsureObject(snapshot, "search");
            search["query"] = query ?? string.Empty;

            var collocate = EnsureObject(snapshot, "collocate");
            collocate["scope"] = string.IsNullOrWhiteSpace(scopeId) ? "current" : scopeId;
            collocate["leftWindow"] = string.IsNullOrWhiteSpace(windowSize) ? "5" : windowSize;
            collocate["rightWindow"] = string.IsNullOrWhiteSpace(windowSize) ? "5" : windowSize;
            collocate["minFreq"] = string.IsNullOrWhiteSpace(minFreq) ? "1" : minFreq;
        }, cancellationToken);
    }

    public Task SaveLocatorStateAsync(
        string corpusId,
        string corpusName,
        string folderName,
        string keyword,
        int sentenceId,
        int nodeIndex,
        string leftWindow,
        string rightWindow,
        CancellationToken cancellationToken = default)
    {
        return UpdateSnapshotAsync(snapshot =>
        {
            var locator = EnsureObject(snapshot, "locator");
            locator["corpusId"] = corpusId ?? string.Empty;
            locator["corpusName"] = corpusName ?? string.Empty;
            locator["folderName"] = folderName ?? string.Empty;
            locator["keyword"] = keyword ?? string.Empty;
            locator["sentenceId"] = sentenceId;
            locator["nodeIndex"] = nodeIndex;
            locator["leftWindow"] = string.IsNullOrWhiteSpace(leftWindow) ? "5" : leftWindow;
            locator["rightWindow"] = string.IsNullOrWhiteSpace(rightWindow) ? "5" : rightWindow;
        }, cancellationToken);
    }

    private async Task UpdateSnapshotAsync(Action<JsonObject> mutate, CancellationToken cancellationToken)
    {
        await InitializeAsync(cancellationToken);

        await _gate.WaitAsync(cancellationToken);
        try
        {
            mutate(_snapshot);
            using var _ = await _engineClient.InvokeAsync(
                EngineContracts.Methods.WorkspaceSaveState,
                new
                {
                    snapshot = _snapshot
                },
                cancellationToken
            );
        }
        finally
        {
            _gate.Release();
        }
    }

    private string GetString(string propertyName, string fallback)
    {
        if (_snapshot[propertyName] is JsonValue value)
        {
            return value.TryGetValue<string>(out var stringValue) && !string.IsNullOrWhiteSpace(stringValue)
                ? stringValue
                : fallback;
        }

        return fallback;
    }

    private string GetString(string sectionName, string propertyName, string fallback)
    {
        if (_snapshot[sectionName] is not JsonObject section)
        {
            return fallback;
        }

        if (section[propertyName] is JsonValue value)
        {
            return value.TryGetValue<string>(out var stringValue) && !string.IsNullOrWhiteSpace(stringValue)
                ? stringValue
                : fallback;
        }

        return fallback;
    }

    private int GetInt(string sectionName, string propertyName, int fallback)
    {
        if (_snapshot[sectionName] is not JsonObject section)
        {
            return fallback;
        }

        if (section[propertyName] is JsonValue value)
        {
            if (value.TryGetValue<int>(out var number))
            {
                return number;
            }

            if (value.TryGetValue<string>(out var text)
                && int.TryParse(text, out var parsed))
            {
                return parsed;
            }
        }

        return fallback;
    }

    private static JsonObject EnsureObject(JsonObject root, string propertyName)
    {
        if (root[propertyName] is JsonObject objectValue)
        {
            return objectValue;
        }

        var created = new JsonObject();
        root[propertyName] = created;
        return created;
    }

    private static JsonObject CreateDefaultSnapshot()
    {
        return new JsonObject
        {
            ["version"] = 1,
            ["currentTab"] = "stats",
            ["currentLibraryFolderId"] = "all",
            ["previewCollapsed"] = true,
            ["workspace"] = new JsonObject
            {
                ["corpusIds"] = new JsonArray(),
                ["corpusNames"] = new JsonArray()
            },
            ["search"] = new JsonObject
            {
                ["query"] = string.Empty,
                ["options"] = new JsonObject
                {
                    ["words"] = true,
                    ["caseSensitive"] = false,
                    ["regex"] = false
                }
            },
            ["stats"] = new JsonObject
            {
                ["pageSize"] = "10"
            },
            ["compare"] = new JsonObject
            {
                ["pageSize"] = "10"
            },
            ["ngram"] = new JsonObject
            {
                ["pageSize"] = "10",
                ["size"] = "2"
            },
            ["kwic"] = new JsonObject
            {
                ["pageSize"] = "10",
                ["scope"] = "current",
                ["sortMode"] = "original",
                ["leftWindow"] = "5",
                ["rightWindow"] = "5"
            },
            ["collocate"] = new JsonObject
            {
                ["pageSize"] = "10",
                ["leftWindow"] = "5",
                ["rightWindow"] = "5",
                ["minFreq"] = "1",
                ["scope"] = "current"
            },
            ["locator"] = new JsonObject
            {
                ["corpusId"] = string.Empty,
                ["corpusName"] = string.Empty,
                ["folderName"] = string.Empty,
                ["keyword"] = string.Empty,
                ["sentenceId"] = 0,
                ["nodeIndex"] = 0,
                ["leftWindow"] = "5",
                ["rightWindow"] = "5"
            },
            ["chiSquare"] = new JsonObject
            {
                ["a"] = string.Empty,
                ["b"] = string.Empty,
                ["c"] = string.Empty,
                ["d"] = string.Empty,
                ["yates"] = false
            }
        };
    }
}
