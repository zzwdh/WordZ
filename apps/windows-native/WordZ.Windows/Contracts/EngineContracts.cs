namespace WordZ.Windows.Contracts;

public static class EngineContracts
{
    public const string JsonRpcVersion = "2.0";

    public static class Methods
    {
        public const string AppGetInfo = "app.getInfo";
        public const string AppGetPendingLaunchFiles = "app.getPendingLaunchFiles";
        public const string AppConsumeCrashRecoveryState = "app.consumeCrashRecoveryState";
        public const string LibraryList = "library.list";
        public const string LibraryOpenQuickPath = "library.openQuickPath";
        public const string LibraryImportPaths = "library.importPaths";
        public const string AnalysisStartTask = "analysis.startTask";
        public const string AnalysisCancelTask = "analysis.cancelTask";
        public const string DiagnosticsGetState = "diagnostics.getState";
        public const string UpdateGetState = "update.getState";
        public const string EngineShutdown = "engine.shutdown";
    }
}
