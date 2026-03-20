export const UI_SETTINGS_STORAGE_KEY = 'corpus-ui-settings'
export const LIBRARY_FOLDER_STORAGE_KEY = 'corpus-library-folder'
export const DEFAULT_THEME = 'light'
export const PREVIEW_CHAR_LIMIT = 20000
export const DEFAULT_WINDOW_SIZE = 5
export const DEFAULT_UI_SETTINGS = {
  zoom: 100,
  fontScale: 100,
  fontFamily: 'system'
}

export const UI_FONT_FAMILIES = {
  system: '-apple-system, BlinkMacSystemFont, "Segoe UI", "PingFang SC", "Microsoft YaHei", "Helvetica Neue", Arial, sans-serif',
  modern: '"PingFang SC", "Segoe UI", "Noto Sans SC", "Helvetica Neue", Arial, sans-serif',
  readable: '"Microsoft YaHei", "PingFang SC", "Noto Sans SC", Arial, sans-serif',
  serif: '"Source Han Serif SC", "Songti SC", "STSong", "SimSun", serif'
}

export const BUTTON_ICONS = {
  open: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" aria-hidden="true"><path d="M3 19.5V7.5a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2Z"/><path d="M3 10.5h18"/></svg>',
  import: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" aria-hidden="true"><path d="M12 3v11"/><path d="m7.5 10.5 4.5 4.5 4.5-4.5"/><path d="M4 19h16"/></svg>',
  library: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" aria-hidden="true"><path d="M4.5 5.5h11a2 2 0 0 1 2 2v11h-11a2 2 0 0 0-2 2Z"/><path d="M17.5 7.5h2a2 2 0 0 1 2 2v11h-13"/><path d="M6.5 5.5v15"/></svg>',
  stats: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" aria-hidden="true"><path d="M5 19V9"/><path d="M12 19V5"/><path d="M19 19v-7"/><path d="M3 19h18"/></svg>',
  tasks: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" aria-hidden="true"><path d="M9 6h11"/><path d="M9 12h11"/><path d="M9 18h11"/><circle cx="5" cy="6" r="1.5"/><circle cx="5" cy="12" r="1.5"/><circle cx="5" cy="18" r="1.5"/></svg>',
  spark: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" aria-hidden="true"><path d="m12 3 1.9 4.6L18.5 9.5l-4.6 1.9L12 16l-1.9-4.6L5.5 9.5l4.6-1.9Z"/><path d="m18.5 3 .7 1.8L21 5.5l-1.8.7-.7 1.8-.7-1.8-1.8-.7 1.8-.7Z"/><path d="m18.5 15 .7 1.8 1.8.7-1.8.7-.7 1.8-.7-1.8-1.8-.7 1.8-.7Z"/></svg>',
  about: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" aria-hidden="true"><circle cx="12" cy="12" r="9"/><path d="M12 10v6"/><path d="M12 7.5h.01"/></svg>',
  update: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" aria-hidden="true"><path d="M3 12a9 9 0 1 0 3-6.7"/><path d="M3 4v5h5"/><path d="M12 8v5"/><path d="m9.5 11.5 2.5 2.5 2.5-2.5"/></svg>',
  settings: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" aria-hidden="true"><path d="M4 7h10"/><path d="M18 7h2"/><path d="M10 17h10"/><path d="M4 17h2"/><circle cx="16" cy="7" r="2"/><circle cx="8" cy="17" r="2"/></svg>',
  export: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" aria-hidden="true"><path d="M12 15V4"/><path d="m7.5 8.5 4.5-4.5 4.5 4.5"/><path d="M4 20h16"/></svg>',
  exportAll: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" aria-hidden="true"><path d="M12 13V3"/><path d="m7.5 7.5 4.5-4.5 4.5 4.5"/><path d="M4 18h16"/><path d="M7 21h10"/></svg>',
  folderAdd: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" aria-hidden="true"><path d="M3 19.5V7.5a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2Z"/><path d="M12 10v6"/><path d="M9 13h6"/></svg>',
  backup: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" aria-hidden="true"><path d="M4.5 7.5h15v12h-15z"/><path d="M8 7.5V5h8v2.5"/><path d="M12 11v5"/><path d="M9.5 13.5 12 16l2.5-2.5"/></svg>',
  restore: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" aria-hidden="true"><path d="M4.5 7.5h15v12h-15z"/><path d="M8 7.5V5h8v2.5"/><path d="M12 16v-5"/><path d="m9.5 13.5 2.5-2.5 2.5 2.5"/></svg>',
  repair: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" aria-hidden="true"><path d="M12 3 5.5 6v5.5c0 4.2 2.6 7.9 6.5 9.5 3.9-1.6 6.5-5.3 6.5-9.5V6L12 3Z"/><path d="m9.5 12 1.7 1.7 3.3-3.3"/></svg>',
  stop: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" aria-hidden="true"><rect x="6.5" y="6.5" width="11" height="11" rx="2"/></svg>',
  close: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" aria-hidden="true"><path d="m6 6 12 12"/><path d="M18 6 6 18"/></svg>',
  reset: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" aria-hidden="true"><path d="M3 12a9 9 0 1 0 3-6.7"/><path d="M3 4v5h5"/></svg>',
  sun: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" aria-hidden="true"><circle cx="12" cy="12" r="4"/><path d="M12 2.5v2.5"/><path d="M12 19v2.5"/><path d="m4.9 4.9 1.8 1.8"/><path d="m17.3 17.3 1.8 1.8"/><path d="M2.5 12H5"/><path d="M19 12h2.5"/><path d="m4.9 19.1 1.8-1.8"/><path d="m17.3 6.7 1.8-1.8"/></svg>',
  moon: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" aria-hidden="true"><path d="M20 14.5A8.5 8.5 0 0 1 9.5 4 8.5 8.5 0 1 0 20 14.5Z"/></svg>',
  edit: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" aria-hidden="true"><path d="m4 20 4.5-1 9.2-9.2a2.1 2.1 0 0 0-3-3L5.5 16 4 20Z"/><path d="m13.5 7.5 3 3"/></svg>',
  move: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" aria-hidden="true"><path d="M12 4v16"/><path d="m7.5 8.5 4.5-4.5 4.5 4.5"/><path d="m7.5 15.5 4.5 4.5 4.5-4.5"/></svg>',
  delete: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" aria-hidden="true"><path d="M4 7h16"/><path d="M9 7V4h6v3"/><path d="M7 7l1 13h8l1-13"/><path d="M10 11v5"/><path d="M14 11v5"/></svg>'
}

export const ANALYSIS_TASK_TYPES = {
  loadCorpus: 'load-corpus',
  computeStats: 'compute-stats',
  searchKWIC: 'search-kwic',
  searchLibraryKWIC: 'search-library-kwic',
  searchCollocates: 'search-collocates'
}

export const LARGE_TABLE_THRESHOLD = 400
export const TABLE_RENDER_CHUNK_SIZE = 240
