using System.Collections.Concurrent;
using System.Diagnostics;
using System.Text;
using System.Text.Json;
using WordZ.Windows.Contracts;

namespace WordZ.Windows.Services;

public sealed class EngineNotificationEventArgs(string method, JsonElement? parameters, string rawJson) : EventArgs
{
    public string Method { get; } = method;
    public JsonElement? Parameters { get; } = parameters;
    public string RawJson { get; } = rawJson;
}

public sealed class EngineClient : IAsyncDisposable
{
    private readonly ConcurrentDictionary<string, TaskCompletionSource<JsonDocument?>> _pendingRequests = new();
    private Process? _process;
    private StreamWriter? _stdin;
    private StreamReader? _stdout;
    private CancellationTokenSource? _lifetimeCts;
    private Task? _stdoutPump;
    private Task? _stderrPump;

    public bool IsStarted => _process is { HasExited: false } && _stdin is not null && _stdout is not null;
    public string? ResolvedNodePath { get; private set; }
    public string? ResolvedEngineEntryPath { get; private set; }

    public event EventHandler<EngineNotificationEventArgs>? NotificationReceived;
    public event EventHandler<string>? EngineErrorReceived;

    public async Task StartAsync(string? userDataDir = null, CancellationToken cancellationToken = default)
    {
        if (IsStarted)
        {
            return;
        }

        var engineEntry = ResolveEngineEntryPath();
        var nodeExecutable = ResolveNodeExecutable();
        ResolvedEngineEntryPath = engineEntry;
        ResolvedNodePath = nodeExecutable;

        _process = new Process
        {
            StartInfo = new ProcessStartInfo
            {
                FileName = nodeExecutable,
                RedirectStandardInput = true,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                StandardErrorEncoding = Encoding.UTF8,
                StandardInputEncoding = Encoding.UTF8,
                StandardOutputEncoding = Encoding.UTF8,
                UseShellExecute = false,
                CreateNoWindow = true,
                WorkingDirectory = Path.GetDirectoryName(engineEntry) ?? AppContext.BaseDirectory
            },
            EnableRaisingEvents = true
        };
        _process.StartInfo.ArgumentList.Add(engineEntry);
        if (!string.IsNullOrWhiteSpace(userDataDir))
        {
            _process.StartInfo.ArgumentList.Add($"--user-data-dir={userDataDir}");
        }
        _process.Exited += HandleProcessExited;

        _process.Start();
        _stdin = _process.StandardInput;
        _stdout = _process.StandardOutput;
        _lifetimeCts = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        _stdoutPump = Task.Run(() => ReadStdoutLoopAsync(_stdout, _lifetimeCts.Token), CancellationToken.None);
        _stderrPump = Task.Run(() => DrainErrorsAsync(_process.StandardError, _lifetimeCts.Token), CancellationToken.None);

        await Task.Delay(TimeSpan.FromMilliseconds(150), cancellationToken).ConfigureAwait(false);
        if (_process.HasExited)
        {
            throw new InvalidOperationException(
                $"The WordZ engine exited before initialization completed. Exit code: {_process.ExitCode}."
            );
        }
    }

    public async Task<JsonDocument?> InvokeAsync(string method, object? parameters = null, CancellationToken cancellationToken = default)
    {
        if (_stdin is null || _stdout is null)
        {
            throw new InvalidOperationException("Engine process is not started.");
        }

        var requestId = Guid.NewGuid().ToString("N");
        var completion = new TaskCompletionSource<JsonDocument?>(TaskCreationOptions.RunContinuationsAsynchronously);
        _pendingRequests[requestId] = completion;

        var payload = JsonSerializer.Serialize(new
        {
            jsonrpc = EngineContracts.JsonRpcVersion,
            id = requestId,
            method,
            @params = parameters
        });

        using var cancelRegistration = cancellationToken.Register(() =>
        {
            if (_pendingRequests.TryRemove(requestId, out var pending))
            {
                pending.TrySetCanceled(cancellationToken);
            }
        });

        try
        {
            await _stdin.WriteLineAsync(payload.AsMemory(), cancellationToken);
            await _stdin.FlushAsync(cancellationToken);
            return await completion.Task.WaitAsync(cancellationToken);
        }
        catch
        {
            _pendingRequests.TryRemove(requestId, out _);
            throw;
        }
    }

    private async Task ReadStdoutLoopAsync(StreamReader stdout, CancellationToken cancellationToken)
    {
        try
        {
            while (!cancellationToken.IsCancellationRequested)
            {
                var line = await stdout.ReadLineAsync(cancellationToken);
                if (string.IsNullOrWhiteSpace(line))
                {
                    if (line is null)
                    {
                        break;
                    }

                    continue;
                }

                JsonDocument? message = null;
                try
                {
                    message = JsonDocument.Parse(line);
                    var root = message.RootElement;
                    if (root.TryGetProperty("id", out var idElement))
                    {
                        var responseId = idElement.ValueKind switch
                        {
                            JsonValueKind.String => idElement.GetString(),
                            JsonValueKind.Number => idElement.GetRawText(),
                            JsonValueKind.Null => null,
                            _ => idElement.GetRawText()
                        };

                        if (!string.IsNullOrWhiteSpace(responseId) && _pendingRequests.TryRemove(responseId, out var pending))
                        {
                            pending.TrySetResult(message);
                            message = null;
                            continue;
                        }
                    }

                    if (root.TryGetProperty("method", out var methodElement))
                    {
                        var methodName = methodElement.GetString() ?? string.Empty;
                        JsonElement? parameters = null;
                        if (root.TryGetProperty("params", out var paramsElement))
                        {
                            parameters = paramsElement.Clone();
                        }

                        NotificationReceived?.Invoke(this, new EngineNotificationEventArgs(methodName, parameters, line));
                    }
                }
                catch (Exception exception)
                {
                    EngineErrorReceived?.Invoke(this, $"Failed to parse engine output: {exception.Message}");
                }
                finally
                {
                    message?.Dispose();
                }
            }
        }
        finally
        {
            CompletePendingRequests(new IOException("WordZ engine connection closed."));
        }
    }

    private async Task DrainErrorsAsync(StreamReader stderr, CancellationToken cancellationToken)
    {
        while (!stderr.EndOfStream && !cancellationToken.IsCancellationRequested)
        {
            var line = await stderr.ReadLineAsync(cancellationToken);
            if (!string.IsNullOrWhiteSpace(line))
            {
                EngineErrorReceived?.Invoke(this, line);
            }
        }
    }

    private void HandleProcessExited(object? sender, EventArgs args)
    {
        if (_process is null)
        {
            return;
        }

        EngineErrorReceived?.Invoke(this, $"Engine process exited with code {_process.ExitCode}.");
        CompletePendingRequests(new IOException($"WordZ engine exited with code {_process.ExitCode}."));
    }

    private static string ResolveEngineEntryPath()
    {
        foreach (var searchRoot in EnumerateSearchRoots(AppContext.BaseDirectory))
        {
            var candidate = Path.Combine(searchRoot, "packages", "wordz-engine-js", "src", "index.mjs");
            if (File.Exists(candidate))
            {
                return candidate;
            }
        }

        throw new FileNotFoundException(
            "WordZ engine entry was not found under the native shell output or repository root.",
            Path.Combine(AppContext.BaseDirectory, "packages", "wordz-engine-js", "src", "index.mjs")
        );
    }

    private static IEnumerable<string> EnumerateSearchRoots(string baseDirectory)
    {
        var current = new DirectoryInfo(baseDirectory);
        for (var depth = 0; current is not null && depth < 8; depth++, current = current.Parent)
        {
            yield return current.FullName;
        }
    }

    private static string ResolveNodeExecutable()
    {
        var overridePath = Environment.GetEnvironmentVariable("WORDZ_NODE_EXE");
        if (!string.IsNullOrWhiteSpace(overridePath))
        {
            var fullOverridePath = Path.GetFullPath(overridePath.Trim('"'));
            if (File.Exists(fullOverridePath))
            {
                return fullOverridePath;
            }
        }

        foreach (var candidate in BuildNodeCandidatePaths())
        {
            if (File.Exists(candidate))
            {
                return candidate;
            }
        }

        var pathCandidate = ResolveFromPath("node.exe");
        if (!string.IsNullOrWhiteSpace(pathCandidate))
        {
            return pathCandidate;
        }

        throw new FileNotFoundException(
            "Node.js was not found. Install Node.js 24.x or set WORDZ_NODE_EXE to node.exe.",
            "node.exe"
        );
    }

    private static IEnumerable<string> BuildNodeCandidatePaths()
    {
        yield return Path.Combine(AppContext.BaseDirectory, "node.exe");

        var programFiles = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles);
        if (!string.IsNullOrWhiteSpace(programFiles))
        {
            yield return Path.Combine(programFiles, "nodejs", "node.exe");
        }

        var programFilesX86 = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86);
        if (!string.IsNullOrWhiteSpace(programFilesX86))
        {
            yield return Path.Combine(programFilesX86, "nodejs", "node.exe");
        }

        var localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        if (!string.IsNullOrWhiteSpace(localAppData))
        {
            yield return Path.Combine(localAppData, "Programs", "nodejs", "node.exe");
        }
    }

    private static string? ResolveFromPath(string fileName)
    {
        var pathValue = Environment.GetEnvironmentVariable("PATH");
        if (string.IsNullOrWhiteSpace(pathValue))
        {
            return null;
        }

        foreach (var rawSegment in pathValue.Split(Path.PathSeparator, StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
        {
            var segment = rawSegment.Trim('"');
            if (string.IsNullOrWhiteSpace(segment))
            {
                continue;
            }

            var candidate = Path.Combine(segment, fileName);
            if (File.Exists(candidate))
            {
                return candidate;
            }
        }

        return null;
    }

    private void CompletePendingRequests(Exception exception)
    {
        foreach (var entry in _pendingRequests)
        {
            if (_pendingRequests.TryRemove(entry.Key, out var pending))
            {
                pending.TrySetException(exception);
            }
        }
    }

    public async ValueTask DisposeAsync()
    {
        _lifetimeCts?.Cancel();

        try
        {
            if (_stdin is not null)
            {
                await _stdin.DisposeAsync();
            }
        }
        catch
        {
            // ignore shutdown errors
        }

        try
        {
            if (_stdoutPump is not null)
            {
                await _stdoutPump.ConfigureAwait(false);
            }
        }
        catch
        {
            // ignore shutdown errors
        }

        if (_process is not null && !_process.HasExited)
        {
            _process.Kill(entireProcessTree: true);
        }

        if (_process is not null)
        {
            _process.Exited -= HandleProcessExited;
        }

        _process?.Dispose();
        _lifetimeCts?.Dispose();
    }
}
