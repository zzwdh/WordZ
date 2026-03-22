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
        public const string LibraryOpenSaved = "library.openSaved";
        public const string LibraryOpenSavedBatch = "library.openSavedBatch";
        public const string LibraryRenameCorpus = "library.renameCorpus";
        public const string LibraryMoveCorpus = "library.moveCorpus";
        public const string LibraryDeleteCorpus = "library.deleteCorpus";
        public const string LibraryCreateFolder = "library.createFolder";
        public const string LibraryRenameFolder = "library.renameFolder";
        public const string LibraryDeleteFolder = "library.deleteFolder";
        public const string LibrarySearchKwic = "library.searchKwic";
        public const string WorkspaceGetState = "workspace.getState";
        public const string WorkspaceSaveState = "workspace.saveState";
        public const string AnalysisStartTask = "analysis.startTask";
        public const string AnalysisCancelTask = "analysis.cancelTask";
        public const string AnalysisGetTaskState = "analysis.getTaskState";
        public const string DiagnosticsGetState = "diagnostics.getState";
        public const string UpdateGetState = "update.getState";
        public const string EngineShutdown = "engine.shutdown";
    }
}
