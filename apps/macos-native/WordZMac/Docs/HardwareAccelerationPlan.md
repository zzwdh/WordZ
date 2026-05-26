# Mac 硬件优化项目

日期：2026-05-26  
范围：WordZMac 原生 macOS 分析运行时、Core ML 情感模型、Topics 向量计算、后续 GPU/ANE 专项

## 1. 当前结论

WordZMac 当前最适合按三层推进 Mac 硬件优化：

1. CPU：继续承接文本解析、索引、SQLite、规则型分析和 UI scene build。这里的重点是减少重复计算、保持后台任务和缓存命中。
2. GPU：只适合向量矩阵、聚类大批量相似度、未来可批处理的可视化/数值计算。当前项目没有 Metal compute 管线，不能把普通文本算法硬迁到 GPU。
3. ANE / NPU：通过 Core ML 间接使用，适合 Transformer 或可由 Core ML 编译器下沉的模型。业务代码不应直接调用 ANE。

第一轮已落地一个低风险切片：新增 `HardwareAccelerationPolicy`，让 Core ML 情感模型按硬件和模型家族选择计算单元；同时把 Topics 热路径中的向量归一化、点积和质心计算收敛到 Accelerate/vDSP/CBLAS。第二轮补齐 Topics benchmark 报告，把硬件摘要、Core ML compute policy 和耗时结果写入 `.build/reports/topic-benchmark-report.json`。

## 2. 已落地的优化边界

### Core ML 计算单元策略

位置：`Sources/WordZMac/Analysis/Support/HardwareAccelerationPolicy.swift`

- Apple Silicon + Transformer Core ML：使用 `.all`，允许 Core ML 在 CPU/GPU/ANE 之间调度。
- Apple Silicon + 较小文本/稠密特征模型：使用 `.cpuAndNeuralEngine`，避免把轻量分类器挤占到 GPU。
- Intel + Metal GPU：使用 `.cpuAndGPU`。
- 无 Metal GPU：回退 `.cpuOnly`。

接入点：`Sources/WordZMac/Analysis/Services/SentimentModelManager.swift`

模型加载现在通过 `MLModelConfiguration.computeUnits` 显式表达硬件策略，而不是使用 Core ML 默认策略。

### Topics 向量数学热路径

位置：`Sources/WordZMac/Analysis/Services/Topics/NativeTopicEngine+VectorMath.swift`

- `cosineSimilarity` 使用 CBLAS 点积。
- `normalize` 使用 CBLAS norm + vDSP scale。
- `centroid` 使用 vDSP 向量加法和缩放。

这保持算法行为不变，但让 Apple Silicon/Intel 上的 Accelerate 后端负责底层 SIMD 调度。

## 3. 下一阶段优化项目

### P1：建立硬件性能基准

状态：已完成第一版。

目标：让优化有可比较数字，而不是凭体感判断。

范围：

- Topics benchmark 已增加硬件摘要：CPU 架构、Metal GPU 是否可用、ANE 是否可用、Core ML computeUnits。
- 报告输出已统一进入 `.build/reports/`，避免混入发布 artifact。
- 大语料词频/KWIC smoke benchmark 留到下一轮独立补齐，避免和 Topics 硬件基线混在一个改动里。

验收：

- `Scripts/run-topic-benchmark.sh` 输出包含硬件策略摘要，并写出 `topic-benchmark-report.json`。
- `TopicBenchmarkTests` 继续守住 Topics 策略、纯度、召回和耗时预算。

### P2：Topics 相似度矩阵专项

目标：优化目前最接近 GPU/Accelerate 适配的计算热点。

范围：

- 先用 Accelerate 批量矩阵乘法构建 normalized embedding 的相似度矩阵。
- 当文档片段数超过阈值时，避免 Swift 双层循环逐对计算。
- 只在没有 lexical hybrid similarity 时使用批量路径；混合相似度继续走现有逻辑。

验收：

- 结果矩阵与当前实现数值误差在固定容忍范围内。
- approximate / exact topic benchmark 不降质。

### P3：Core ML 模型分层

目标：真正让 ANE/NPU 发挥价值，而不是只打开开关。

范围：

- 区分当前 `embeddingLogReg` 与未来 `transformerCoreML` provider。
- Transformer provider 必须提供 tokenized input schema、tokenizer resource、模型大小提示和 benchmark fixture。
- UI 只暴露“本地模型”能力，不暴露硬件细节；诊断里记录 provider family 和 compute policy。

验收：

- `SentimentModelManagerTests` 覆盖 provider family -> computeUnits 策略。
- benchmark 显示 Transformer provider 的准确率/耗时/模型大小权衡。

### P4：Metal Compute 可行性验证

目标：只在明确收益大于维护成本时引入 Metal。

候选：

- 大规模 pairwise similarity。
- 大批量二维投影或距离计算。
- 不适合：tokenization、SQLite、NLTagger、规则型情感、短文本逐条分类。

准入条件：

- Accelerate 批量路径仍不能满足目标。
- 有可重复 benchmark 证明收益。
- Metal kernel 有独立测试和 CPU fallback。

## 4. 工程规则

- 不直接在 UI 或 ViewModel 中判断 CPU/GPU/ANE。
- 硬件策略只放在 `Analysis` 或更窄的运行时 support 中。
- Core ML 通过 `MLModelConfiguration` 使用硬件；业务代码不直接访问 ANE。
- Metal 只能作为有 CPU fallback 的可选加速层。
- 每个硬件优化必须同时说明：适用输入规模、fallback、数值误差范围、验证命令。
