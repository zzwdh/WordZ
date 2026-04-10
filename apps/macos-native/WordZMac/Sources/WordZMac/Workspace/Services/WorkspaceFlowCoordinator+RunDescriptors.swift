import Foundation

extension WorkspaceFlowCoordinator.WorkspaceRunTaskDescriptor {
    static var stats: Self {
        Self(
            titleZh: "统计分析",
            titleEn: "Run Stats",
            detailZh: "正在统计词频与基础指标…",
            detailEn: "Calculating frequencies and core metrics…",
            successZh: "统计结果已生成。",
            successEn: "Stats results are ready."
        )
    }

    static var word: Self {
        Self(
            titleZh: "词表分析",
            titleEn: "Run Word List",
            detailZh: "正在整理词项与频次…",
            detailEn: "Preparing lexical items and counts…",
            successZh: "词表结果已生成。",
            successEn: "Word list results are ready."
        )
    }

    static var tokenize: Self {
        Self(
            titleZh: "分词分析",
            titleEn: "Run Tokenize",
            detailZh: "正在切分文本并生成词元…",
            detailEn: "Tokenizing the corpus text…",
            successZh: "分词结果已生成。",
            successEn: "Tokenization results are ready."
        )
    }

    static var compare: Self {
        Self(
            titleZh: "多语料对比",
            titleEn: "Run Compare",
            detailZh: "正在汇总多语料频次差异…",
            detailEn: "Comparing frequencies across corpora…",
            successZh: "对比结果已生成。",
            successEn: "Comparison results are ready."
        )
    }

    static var keyword: Self {
        Self(
            titleZh: "关键词分析",
            titleEn: "Run Keyword Analysis",
            detailZh: "正在对比 Target 与 Reference 语料…",
            detailEn: "Comparing the target and reference corpora…",
            successZh: "关键词结果已生成。",
            successEn: "Keyword results are ready."
        )
    }

    static var chiSquare: Self {
        Self(
            titleZh: "卡方检验",
            titleEn: "Run Chi-Square",
            detailZh: "正在计算列联表统计量…",
            detailEn: "Calculating contingency table statistics…",
            successZh: "卡方结果已生成。",
            successEn: "Chi-square results are ready."
        )
    }

    static var kwic: Self {
        Self(
            titleZh: "KWIC 索引行",
            titleEn: "Run KWIC",
            detailZh: "正在定位节点词上下文…",
            detailEn: "Locating keyword-in-context rows…",
            successZh: "KWIC 结果已生成。",
            successEn: "KWIC results are ready."
        )
    }

    static var ngram: Self {
        Self(
            titleZh: "N-Gram 分析",
            titleEn: "Run N-Gram",
            detailZh: "正在统计连续词串…",
            detailEn: "Counting contiguous token sequences…",
            successZh: "N-Gram 结果已生成。",
            successEn: "N-gram results are ready."
        )
    }

    static var collocate: Self {
        Self(
            titleZh: "搭配分析",
            titleEn: "Run Collocate",
            detailZh: "正在计算搭配词与窗口统计…",
            detailEn: "Calculating collocates and window statistics…",
            successZh: "搭配结果已生成。",
            successEn: "Collocate results are ready."
        )
    }

    static var locator: Self {
        Self(
            titleZh: "句子定位",
            titleEn: "Run Locator",
            detailZh: "正在定位索引行所在上下文…",
            detailEn: "Locating the surrounding sentence context…",
            successZh: "定位结果已生成。",
            successEn: "Locator results are ready."
        )
    }
}
