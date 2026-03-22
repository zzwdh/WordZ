function buildOptions(options = [], selectedValue = '') {
  return options
    .map(([value, label]) => `<option value="${value}"${String(value) === String(selectedValue) ? ' selected' : ''}>${label}</option>`)
    .join('')
}

function button(id, label, className = 'button', extra = '') {
  return `<button type="button" id="${id}" class="${className}"${extra ? ` ${extra}` : ''}>${label}</button>`
}

function select(id, options, selectedValue = '', className = '') {
  const classes = className ? ` class="${className}"` : ''
  return `<select id="${id}"${classes}>${buildOptions(options, selectedValue)}</select>`
}

function checkbox(id, label, checked = false, dataAttribute = '') {
  return `
    <label class="toggle-item">
      <input type="checkbox" id="${id}"${checked ? ' checked' : ''}${dataAttribute ? ` ${dataAttribute}` : ''} />
      <span>${label}</span>
    </label>
  `
}

function section(id, title, contentHtml, hidden = true) {
  return `
    <section id="${id}" class="tab-shell panel${hidden ? ' hidden' : ''}">
      <div class="panel-header panel-header-inline">
        <h2>${title}</h2>
      </div>
      <div class="panel-body stack-list">
        ${contentHtml}
      </div>
    </section>
  `
}

const PAGE_SIZE_OPTIONS = [
  ['10', '10'],
  ['20', '20'],
  ['50', '50'],
  ['100', '100'],
  ['all', '全部']
]

const WINDOW_SIZE_OPTIONS = [
  ['1', '1'],
  ['3', '3'],
  ['5', '5'],
  ['7', '7'],
  ['10', '10']
]

const MIN_FREQ_OPTIONS = [
  ['1', '1'],
  ['2', '2'],
  ['3', '3'],
  ['5', '5']
]

const NGRAM_SIZE_OPTIONS = [
  ['2', '2-gram'],
  ['3', '3-gram'],
  ['4', '4-gram'],
  ['5', '5-gram']
]

const KWIC_SORT_OPTIONS = [
  ['original', '原始顺序'],
  ['left-near', '左一词'],
  ['right-near', '右一词'],
  ['left-then-right', '左后右'],
  ['right-then-left', '右后左']
]

const KWIC_SCOPE_OPTIONS = [
  ['current', '当前语料'],
  ['folder', '当前文件夹'],
  ['all', '全部本地语料']
]

export function buildWindowsSafeShellMarkup() {
  return `
    <div class="app-shell windows-safe-shell">
      <header class="topbar">
        <div class="topbar-main">
          <div class="topbar-brand-inline">
            <h1 id="appTitleHeading">WordZ</h1>
            <p id="appSubtitle" class="subtitle compact-subtitle">Windows 工作台</p>
            <span id="topbarVersionBadge" class="topbar-version-badge">轻量模式</span>
          </div>
          <div class="toolbar-actions-group compact-wrap">
            ${button('countButton', '统计')}
            ${button('kwicButton', 'KWIC', 'button gray')}
            ${button('collocateButton', 'Collocate', 'button gray')}
            ${button('ngramButton', 'Ngram', 'button gray')}
            ${button('cancelStatsButton', '取消统计', 'button small gray hidden')}
            ${button('cancelKwicButton', '取消 KWIC', 'button small gray hidden')}
            ${button('cancelCollocateButton', '取消 Collocate', 'button small gray hidden')}
          </div>
        </div>
      </header>

      <div class="toolbar-native-overflow">
        <div class="toolbar-menu">
          ${button('openCorpusMenuButton', '打开语料', 'button menu-trigger')}
          <div id="openCorpusMenuPanel" class="toolbar-menu-panel hidden">
            ${button('quickOpenButton', '快速打开', 'button menu-action')}
            ${button('saveImportButton', '导入并保存', 'button menu-action')}
            ${button('libraryButton', '本地语料库', 'button menu-action')}
            <div class="toolbar-menu-divider"></div>
            <section id="recentOpenSection" class="toolbar-menu-section">
              <div class="toolbar-menu-section-head">
                <strong>最近打开</strong>
                ${button('clearRecentOpenButton', '清空', 'button small gray menu-inline-button')}
              </div>
              <div id="recentOpenList" class="recent-open-list">
                <div class="recent-open-empty">最近打开记录会显示在这里。</div>
              </div>
            </section>
          </div>
        </div>
        ${button('checkUpdateButton', '更新', 'button small gray')}
        ${button('aboutButton', '关于', 'button small gray')}
        ${button('uiSettingsButton', '设置', 'button small gray')}
        ${button('taskCenterButton', '任务', 'button small gray')}
      </div>

      <div id="systemStatus" class="system-status hidden">
        <span class="system-status-spinner" aria-hidden="true"></span>
        <span id="systemStatusText">处理中...</span>
      </div>

      <div id="taskCenterPanel" class="task-center hidden" aria-live="polite">
        <div class="task-center-header">
          <div>
            <strong>任务中心</strong>
            <div id="taskCenterMeta" class="task-center-meta">最近任务会显示在这里。</div>
          </div>
          <div class="toolbar-actions-group compact-wrap">
            ${button('queueToggleButton', '暂停队列', 'button small gray')}
            ${button('cancelQueuedTaskButton', '取消排队', 'button small gray')}
            ${button('retryFailedTaskButton', '重试失败', 'button small gray')}
            ${button('closeTaskCenterButton', '关闭', 'button small gray')}
          </div>
        </div>
        <div id="taskCenterList" class="task-center-list">
          <div class="task-center-empty">暂无任务。</div>
        </div>
      </div>

      <main class="main-layout">
        <aside class="sidebar">
          <section class="panel">
            <div class="panel-header panel-header-inline">
              <h2>当前语料</h2>
              ${button('selectSavedCorporaButton', '选择已保存语料', 'button small gray')}
            </div>
            <div class="panel-body stack-list">
              <div class="meta-item">
                <div class="meta-label">状态</div>
                <div id="fileInfo" class="meta-value">尚未选择文件</div>
              </div>
              <div id="selectedCorporaWrapper" class="table-scroll compact-table-scroll">
                <div class="empty-tip">当前未加入语料。</div>
              </div>
              <div class="toolbar-actions-group compact-wrap">
                ${button('previewToggleButton', '文本预览', 'button small gray')}
                <span id="workspaceCorpusValue" class="chip">未载入</span>
                <span id="workspaceModeValue" class="chip">单语料</span>
              </div>
              <div id="previewPanelBody" class="hidden">
                <div id="previewBox" class="panel-note">预览默认收起。</div>
              </div>
              <div id="workspaceCorpusNote" class="panel-note">支持 Quick Corpus 与本地语料库。</div>
              <div id="workspaceModeNote" class="panel-note">可切到多语料对比。</div>
              <div id="workspaceTokenValue" class="hidden">0</div>
              <div id="workspaceTokenNote" class="hidden">0</div>
              <div id="workspaceMetricValue" class="hidden">等待分析</div>
              <div id="workspaceMetricNote" class="hidden">等待分析</div>
            </div>
          </section>

          <section class="panel">
            <div class="panel-header panel-header-inline">
              <h2>查询设置</h2>
            </div>
            <div class="panel-body stack-list">
              <input id="sharedSearchInput" data-shared-search-input type="text" placeholder="SearchQuery" />
              <div class="toolbar-actions-group compact-wrap">
                ${checkbox('searchOptionWords', 'Words', true, 'data-search-option="words"')}
                ${checkbox('searchOptionCase', 'Case', false, 'data-search-option="case"')}
                ${checkbox('searchOptionRegex', 'Regex', false, 'data-search-option="regex"')}
              </div>
              <input id="kwicInput" type="text" placeholder="KWIC 检索词" />
              <div class="grid-3">
                ${select('kwicScopeSelect', KWIC_SCOPE_OPTIONS, 'current')}
                ${select('leftWindowSelect', WINDOW_SIZE_OPTIONS, '5')}
                ${select('rightWindowSelect', WINDOW_SIZE_OPTIONS, '5')}
              </div>
              <input id="collocateInput" type="text" placeholder="Collocate 检索词" />
              <div class="grid-3">
                ${select('collocateLeftWindowSelect', WINDOW_SIZE_OPTIONS, '5')}
                ${select('collocateRightWindowSelect', WINDOW_SIZE_OPTIONS, '5')}
                ${select('collocateMinFreqSelect', MIN_FREQ_OPTIONS, '2')}
              </div>
              <div class="grid-3">
                ${select('ngramSizeSelect', NGRAM_SIZE_OPTIONS, '2')}
                ${select('pageSizeSelect', PAGE_SIZE_OPTIONS, '20')}
                ${select('kwicSortSelect', KWIC_SORT_OPTIONS, 'original')}
              </div>
              <div class="hidden">
                ${select('comparePageSizeSelect', PAGE_SIZE_OPTIONS, '20')}
                ${select('ngramPageSizeSelect', PAGE_SIZE_OPTIONS, '20')}
                ${select('kwicPageSizeSelect', PAGE_SIZE_OPTIONS, '20')}
                ${select('collocatePageSizeSelect', PAGE_SIZE_OPTIONS, '20')}
              </div>
            </div>
          </section>
        </aside>

        <section class="content">
          <section class="panel">
            <div class="panel-header panel-header-inline">
              <h2>分析结果</h2>
              <div class="toolbar-actions-group compact-wrap">
                <button type="button" class="tab-button active" data-tab="stats">统计</button>
                <button type="button" class="tab-button" data-tab="compare">对比</button>
                <button type="button" class="tab-button" data-tab="chi-square">卡方</button>
                <button type="button" class="tab-button" data-tab="word-cloud">词云</button>
                <button type="button" class="tab-button" data-tab="ngram">Ngram</button>
                <button type="button" class="tab-button" data-tab="kwic">KWIC</button>
                <button type="button" class="tab-button" data-tab="collocate">Collocate</button>
                <button type="button" class="tab-button" data-tab="locator">定位</button>
              </div>
            </div>
            <div class="panel-body stack-list">
              ${section('statsSection', '统计结果', `
                <div id="statsSummaryWrapper" class="stack-list"></div>
                <input id="freqFilterInput" type="text" placeholder="筛选统计结果" />
                <div class="toolbar-actions-group compact-wrap">
                  ${button('prevPageButton', '上一页', 'button small gray')}
                  <span id="pageInfo" class="panel-note">第 1 页</span>
                  ${button('nextPageButton', '下一页', 'button small gray')}
                  <span id="totalRowsInfo" class="panel-note">0 行</span>
                </div>
                <div id="tableWrapper" class="table-scroll"></div>
              `, false)}

              ${section('compareSection', '多语料对比', `
                <div id="compareSummaryWrapper" class="stack-list"></div>
                <input id="compareFilterInput" type="text" placeholder="筛选对比结果" />
                <div id="compareMeta" class="panel-note">等待对比分析。</div>
                <div class="toolbar-actions-group compact-wrap">
                  ${button('comparePrevPageButton', '上一页', 'button small gray')}
                  <span id="comparePageInfo" class="panel-note">第 1 页</span>
                  ${button('compareNextPageButton', '下一页', 'button small gray')}
                  <span id="compareTotalRowsInfo" class="panel-note">0 行</span>
                </div>
                <div id="compareWrapper" class="table-scroll"></div>
              `)}

              ${section('chiSquareSection', '卡方检验', `
                <div class="grid-4">
                  <input id="chiAInput" type="number" inputmode="numeric" placeholder="A" />
                  <input id="chiBInput" type="number" inputmode="numeric" placeholder="B" />
                  <input id="chiCInput" type="number" inputmode="numeric" placeholder="C" />
                  <input id="chiDInput" type="number" inputmode="numeric" placeholder="D" />
                </div>
                <div class="toolbar-actions-group compact-wrap">
                  ${checkbox('chiYatesToggle', 'Yates 校正')}
                  ${button('chiSquareRunButton', '计算')}
                  ${button('chiSquareResetButton', '重置', 'button small gray')}
                </div>
                <div id="chiSquareMeta" class="panel-note">输入 2x2 频数表后即可计算。</div>
                <div id="chiSquareResultWrapper" class="stack-list"></div>
              `)}

              ${section('wordCloudSection', '词云', `
                <div id="wordCloudMeta" class="panel-note">词云会在统计后显示。</div>
                <div id="wordCloudWrapper" class="stack-list"></div>
              `)}

              ${section('ngramSection', 'Ngram', `
                <div id="ngramMeta" class="panel-note">等待 Ngram 分析。</div>
                <div class="toolbar-actions-group compact-wrap">
                  ${button('ngramPrevPageButton', '上一页', 'button small gray')}
                  <span id="ngramPageInfo" class="panel-note">第 1 页</span>
                  ${button('ngramNextPageButton', '下一页', 'button small gray')}
                  <span id="ngramTotalRowsInfo" class="panel-note">0 行</span>
                </div>
                <div id="ngramWrapper" class="table-scroll"></div>
              `)}

              ${section('kwicSection', 'KWIC', `
                <div id="kwicMeta" class="panel-note">等待 KWIC 检索。</div>
                <div class="toolbar-actions-group compact-wrap">
                  ${button('kwicPrevPageButton', '上一页', 'button small gray')}
                  <span id="kwicPageInfo" class="panel-note">第 1 页</span>
                  ${button('kwicNextPageButton', '下一页', 'button small gray')}
                  <span id="kwicTotalRowsInfo" class="panel-note">0 行</span>
                </div>
                <div id="kwicWrapper" class="table-scroll"></div>
              `)}

              ${section('collocateSection', 'Collocate', `
                <div id="collocateMeta" class="panel-note">等待 Collocate 计算。</div>
                <div class="toolbar-actions-group compact-wrap">
                  ${button('collocatePrevPageButton', '上一页', 'button small gray')}
                  <span id="collocatePageInfo" class="panel-note">第 1 页</span>
                  ${button('collocateNextPageButton', '下一页', 'button small gray')}
                  <span id="collocateTotalRowsInfo" class="panel-note">0 行</span>
                </div>
                <div id="collocateWrapper" class="table-scroll"></div>
              `)}

              ${section('locatorSection', '定位', `
                <div id="locatorMeta" class="panel-note">原文定位结果会显示在这里。</div>
                <div id="sentenceViewer" class="panel-note">等待定位结果。</div>
              `)}
            </div>
          </section>
        </section>
      </main>

      <div id="toastViewport" class="toast-viewport"></div>
    </div>
  `
}
