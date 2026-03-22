using System.Diagnostics;
using System.Collections.Concurrent;
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

    public event EventHandler<EngineNotificationEventArgs>? NotificationReceived;
    public event EventHandler<string>? EngineErrorReceived;

    public async Task StartAsync(string? userDataDir = null, CancellationToken cancellationToken = default)
    {
        if (IsStarted)
        {
            return;
        }

        var engineEntry = Path.Combine(
            AppContext.BaseDirectory,
            "packages",
            "wordz-engine-js",
            "src",
            "index.mjs"
        );
        if (!File.Exists(engineEntry))
        {
            throw new FileNotFoundException("WordZ engine entry was not found.", engineEntry);
        }

        var args = new StringBuilder();
        args.Append('"').Append(engineEntry).Append('"');

        if (!string.IsNullOrWhiteSpace(userDataDir))
        {
            args.Append(" --user-data-dir=").Append('"').Append(userDataDir).Append('"');
        }

        _process = new Process
        {
            StartInfo = new ProcessStartInfo
            {
                FileName = "node",
                Arguments = args.ToString(),
                RedirectStandardInput = true,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false,
                CreateNoWindow = true
            },
            EnableRaisingEvents = true
        };

        _process.Start();
        _stdin = _process.StandardInput;
        _stdout = _process.StandardOutput;
        _lifetimeCts = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        _stdoutPump = Task.Run(() => ReadStdoutLoopAsync(_stdout, _lifetimeCts.Token), CancellationToken.None);
        _stderrPump = Task.Run(() => DrainErrorsAsync(_process.StandardError, _lifetimeCts.Token), CancellationToken.None);

        await Task.CompletedTask.ConfigureAwait(false);
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
                    if (line is null) break;
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
        _process?.Dispose();
        _lifetimeCts?.Dispose();
    }
}
