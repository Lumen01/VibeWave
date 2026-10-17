# VibeWave 性能审查报告

> 审查日期：2026-07-11  
> 审查范围：数据库查询、同步与聚合、SwiftUI 渲染、启动流程、后台任务与构建配置  
> 结论性质：静态性能审查，未修改业务代码

## 修复进度（2026-07-11）

本轮已完成以下低风险、高收益修复：

- `2.1`：迁移移出工具循环；首次同步最多聚合一次，无导入时跳过聚合。
- `2.2`：定时同步无导入时跳过聚合和数据更新通知。
- `2.4`：全量聚合的范围读取、删除和重建改为同一写事务。
- `2.5`：Session 文件统计改为批量读取并复用更新语句，消除逐 Session 的 `diff_files` 查询。
- `3.1`：目录同步一次预载工具 metadata，消除逐文件 metadata 查询。
- `3.2`：稳定性检查改为单次读取，读取前后比较文件属性，仅对保留数据计算一次哈希。
- `3.3`：排除目录会停止递归；文件计数仅包含 JSON；跳过路径样本设置上限。
- `4.4`：项目列表使用 `projectRoot` 作为稳定 ID，并在刷新后恢复选择对象。
- `4.5`：菜单栏弹窗和统计数据延迟到首次点击创建，隐藏期间只标记数据过期。
- `5.2`：FileWatcher 改为事件触发的一次性 debounce timer，并使用 utility QoS。
- `5.3`：同步和备份定时器增加 leeway/tolerance。
- `5.4`：日志级别改为缓存并支持延迟消息构造；Release 默认 `.info`。
- `6.1`：构建脚本新增 `--release`，并从实际配置的 bin path 打包。
- `6.2`：构建不再改写受版本控制的 `AppConfiguration.swift`。

仍需后续架构改造的项目：`2.3` 同步 actor/请求合并、`3.4` 页面级数据库 snapshot、`3.6` OpenCode 一次性历史修复、`3.7` 精确脏桶、`3.8` 聚合 generation/覆盖元数据、`3.9` session 粒度聚合、`4.1-4.3` Chart render model 与细粒度观察、`4.6` Insights 后台缓存处理、`5.1` 统一维护任务协调器、`5.5` 基于基准测试的 SQLite 内存调优。

## 1. 总体结论

当前最明显的性能问题不在单个 SwiftUI 控件，而在同步流程重复执行全量工作、数据库查询次数过多，以及后台任务缺少串行化。随着数据量增长，启动、定时同步、项目详情和 History 页面会最先出现明显延迟。

优先优化方向：

1. 消除首次同步和定时同步中的重复全量聚合。
2. 将同步、文件监听和备份任务串行化并合并重复请求。
3. 消除 Session 重建中的 N+1 查询。
4. 将页面所需的多个查询合并为单个数据库快照。
5. 减少目录扫描、文件读取和哈希计算。
6. 降低 SwiftUI Chart 在 hover 和状态更新时的重绘范围。
7. 使用 Release 构建进行真实性能测试和分发。

## 2. 严重问题

### 2.1 首次同步可能重复全量聚合最多 6 次

相关位置：

- `Sources/VibeWave/Services/SyncCoordinator.swift:257-300`
- `Sources/VibeWave/Services/DatabaseMigrationService.swift:14-20`

数据库迁移和 `rebuildAllAggregations()` 都在工具循环内部执行。三个工具可能触发三次迁移聚合和三次显式聚合，每次都会扫描完整消息表。

建议：

- 将迁移移到工具循环之前，只执行一次。
- 所有工具完成同步后最多聚合一次。
- 没有导入数据时跳过聚合。
- 增量同步时仅重建受影响的时间桶。

### 2.2 定时同步无变化时仍执行全量工作

相关位置：

- `Sources/VibeWave/Services/SyncCoordinator.swift:318-355`

每个定时周期都会扫描所有工具目录，随后无条件调用 `rebuildAllAggregations()`。即使数据源没有变化，也会产生完整历史数据扫描和聚合表写入。

建议：

- 让 `SyncProgress` 返回受影响的 session 或时间桶。
- 导入数量为 0 时跳过聚合。
- 有变化时仅重新计算受影响的聚合桶。

### 2.3 同步任务可能并发重叠

相关位置：

- `Sources/VibeWave/Services/SyncCoordinator.swift:16-40`
- `Sources/VibeWave/Services/SyncCoordinator.swift:480-523`

手动同步、定时同步、文件监听同步和首次同步使用多个非结构化 `Task`。`isSyncing` 的检查与修改不是原子操作，可能导致同一文件被重复解析、重复写库和重叠聚合。

建议：

- 使用专用 actor 或串行任务队列执行所有同步工作。
- 同步期间将新文件事件合并为一个待处理集合。
- 使用结构化并发和取消机制处理数据源或同步策略变化。
- UI 状态统一通过 `@MainActor` 发布。

### 2.4 聚合重建不是原子操作

相关位置：

- `Sources/VibeWave/Services/AggregationService.swift:16-56`

当前实现先提交聚合表删除，再分别执行范围查询和重建。重建期间界面可能读到空聚合表；中途失败会留下空表或部分聚合数据。

建议：

- 在同一个写事务中完成范围查询、删除和重建。
- 对大数据量使用临时表构建，并在完成后原子替换正式表。
- 注入聚合失败测试，确保失败时旧聚合数据仍然可用。

### 2.5 Session 重建存在 N+1 查询

相关位置：

- `Sources/VibeWave/Services/SessionService.swift:59-93`
- `Sources/VibeWave/Services/SessionService.swift:140-178`
- `Sources/VibeWave/Repositories/SessionRepository.swift:58-92`

每个 session 都会单独查询 `diff_files`，并执行一到两次更新。一万个 session 可能产生数万条 SQL，并长时间占用写事务。

建议：

- 一次读取全部目标 session 的消息。
- 在 Swift 中按 session 聚合项目名和文件列表。
- 复用 prepared statement 批量更新 session。
- 移除重复的 Session 重建实现，避免优化逻辑分叉。

## 3. 高优先级问题

### 3.1 目录同步完整读取和哈希所有 JSON 文件

相关位置：

- `Sources/VibeWave/Services/IncrementalSyncService.swift:215-287`
- `Sources/VibeWave/Repositories/SyncMetadataRepository.swift:48-59`

即使文件没有变化，也会执行完整读取、SHA-256 计算和单独 metadata 查询。

建议：

- 在 metadata 中保存文件大小和高精度修改时间。
- 先比较廉价文件属性，仅在属性变化时计算哈希。
- 一次读取当前工具的全部 metadata，并按规范化路径建立字典。
- 对仅追加的数据格式考虑记录字节偏移量。

### 3.2 文件稳定性检查重复读取和哈希

相关位置：

- `Sources/VibeWave/Services/IncrementalSyncService.swift:329-355`

每次尝试会完整读取两遍并计算两遍 SHA-256，最多可能执行六次完整读取。

建议：

- 读取前后比较文件大小和修改时间。
- 文件属性未变化时接受当前读取结果。
- 仅对最终保留的数据计算一次哈希。

### 3.3 排除目录没有停止递归遍历

相关位置：

- `Sources/VibeWave/Services/IncrementalSyncService.swift:215-247`

遇到 `.git`、`node_modules`、`build` 等目录时只执行 `continue`，并未调用 `skipDescendants()`，因此仍会遍历整个子树。

建议：

- 请求 `.isDirectoryKey`。
- 对排除目录调用 `enumerator.skipDescendants()`。
- 在确认是 JSON 文件后再增加文件计数。
- 跳过路径仅保留计数和少量示例，避免无限增长的字符串数组。

### 3.4 页面刷新包含大量重复数据库查询

相关位置：

- `Sources/VibeWave/ViewModels/HistoryViewModel.swift:175-240`
- `Sources/VibeWave/ViewModels/ProjectsViewModel.swift:149-171`
- `Sources/VibeWave/ViewModels/OverviewViewModel.swift:79-112`

History 每次刷新约执行六次查询，项目详情约执行八次，Overview 也会针对相同时间范围执行多个独立查询。

建议：

- 引入 `HistorySnapshot`、`ProjectDetailSnapshot` 和 `OverviewSnapshot`。
- 在一个 `dbPool.read` 快照中返回页面所需数据。
- 尽可能在同一 SQL 中返回同一时间粒度的多个指标。
- 用单个不可变 snapshot 替代连续多个 `@Published` 赋值。

### 3.5 聚合表缺少项目维度索引

相关位置：

- `Sources/VibeWave/Repositories/DatabaseRepository.swift:88-96`
- `Sources/VibeWave/Repositories/StatisticsRepository.swift:2232-2524`

聚合表主键以 `time_bucket_ms` 开头，不能高效支持仅使用 `project_id` 过滤的项目详情查询。

候选索引：

```sql
CREATE INDEX idx_daily_stats_project_time
ON daily_stats(project_id, time_bucket_ms);

CREATE INDEX idx_monthly_stats_project_time
ON monthly_stats(project_id, time_bucket_ms);
```

添加前应使用 `EXPLAIN QUERY PLAN` 和真实数据验证，避免无依据地增加写入成本。

### 3.6 OpenCode 重复扫描历史缺失记录

相关位置：

- `Sources/VibeWave/Services/OpenCodeDatabaseSyncService.swift:154-161`
- `Sources/VibeWave/Services/OpenCodeDatabaseSyncService.swift:200-290`

每次同步都会扫描所有缺失 provider/model 的历史 assistant 消息。无法修复的记录会被永久重复尝试。

建议：

- 仅处理本次导入或变化的 message ID。
- 将历史修复改为一次性版本迁移。
- 对不可修复的记录保存尝试状态。
- 没有新消息时完全跳过修复。

### 3.7 增量聚合可能重建过宽时间范围

相关位置：

- `Sources/VibeWave/Services/AggregationService.swift:62-124`

所有受影响 session 被合并成一个全局最小和最大时间范围。如果两个 session 相隔几年，中间所有聚合桶都会被删除和重建。

建议：

- 记录精确的小时、日期和月份脏桶。
- 同时保留消息变更前后的旧桶和新桶。
- 仅合并相邻的脏区间。
- 对大量 session ID 进行分块，避免 SQLite 参数上限。

### 3.8 聚合数据覆盖判断过于宽松

相关位置：

- `Sources/VibeWave/Repositories/StatisticsRepository.swift:3450-3463`

当前只要聚合表存在任意一行，就认为聚合数据可用，无法判断请求范围是否完整、是否存在缺口以及当前时间桶是否已经聚合。

建议：

- 为每种聚合粒度保存覆盖起点、覆盖终点、源数据版本和完成 generation。
- 请求范围完全覆盖时才使用聚合表。
- 缺失范围明确回退到原始表。
- 缓存 schema 和表存在性，避免每次查询重复探测。

### 3.9 多维聚合中的 session_count 不可直接相加

相关位置：

- `Sources/VibeWave/Services/AggregationService.swift:157-198`
- `Sources/VibeWave/Repositories/StatisticsRepository.swift:833-848`
- `Sources/VibeWave/Repositories/StatisticsRepository.swift:915-946`

同一个 session 可能同时出现在多个项目、模型、角色、agent 和时间桶中。直接 `SUM(session_count)` 会重复计算。

建议：

- 全局会话数继续使用 `COUNT(DISTINCT session_id)`。
- 或建立独立的 session 粒度聚合表。
- 仅对 token、message、cost 等可加指标进行跨维度汇总。

## 4. SwiftUI 与交互性能

### 4.1 Chart hover 以指针事件频率重建完整图表

相关位置：

- `Sources/VibeWave/Views/InputTokensChartContentView.swift:150-165`
- `Sources/VibeWave/Views/SingleMetricChartContentView.swift:163-178`
- `Sources/VibeWave/Views/OutputReasoningChartContentView.swift:157-172`

每次鼠标移动都会同时更新 tooltip 内容和位置，进而重新计算 Chart marks、坐标轴和统计值。

建议：

- 状态只保存选中的 bucket index。
- bucket 未变化时不更新状态。
- tooltip 拆分为独立子视图。
- 如需跟随像素移动，将更新频率限制到显示刷新周期。

### 4.2 Chart body 重复创建 Formatter 和遍历数据

相关位置：

- `Sources/VibeWave/Views/InputTokensChartContentView.swift:49-90`
- `Sources/VibeWave/Views/SingleMetricChartContentView.swift:58-104`
- `Sources/VibeWave/Views/OutputReasoningChartContentView.swift:51-98`

每次刷新都会重新计算最大值、平均值、坐标域、网格和标签，并创建 `DateFormatter`。

建议：

- 数据或时间范围变化时生成一次 `ChartRenderModel`。
- 单次遍历同时计算总和与最大值。
- 使用缓存 formatter 或 `Date.FormatStyle`。
- 将三个 Chart 中重复的渲染计算收敛为共享模型。

### 4.3 ViewModel 失效范围过大

相关位置：

- `Sources/VibeWave/ViewModels/HistoryViewModel.swift:18-89`
- `Sources/VibeWave/ViewModels/InsightsViewModel.swift:33-58`
- `Sources/VibeWave/ViewModels/OverviewViewModel.swift:8-21`

单个 `ObservableObject` 包含大量 `@Published` 属性，一项变化会通知观察该对象的所有子视图。

建议：

- macOS 14 下迁移到 `@Observable`，利用属性级依赖跟踪。
- 或按页面区域拆分 ViewModel。
- 发布不可变 snapshot，避免连续多次属性赋值。
- 叶子视图只接收所需的值，不传入整个 ViewModel。

### 4.4 项目列表缺少稳定 ID

相关位置：

- `Sources/VibeWave/ViewModels/ProjectsViewModel.swift:93-109`

`ProjectStats` 每次加载都生成新 UUID，SwiftUI 会将所有项目卡片视为删除后重新插入，破坏 `LazyVGrid` 复用并可能重复动画。

建议：

- 使用 `projectRoot` 或持久化项目 ID 作为稳定 identity。
- 刷新后按稳定 ID 恢复当前选择。

### 4.5 菜单栏弹窗和统计数据被提前加载

相关位置：

- `Sources/VibeWave/StatusItemManager.swift:24-44`
- `Sources/VibeWave/MenuBarPopupWindow.swift:36-63`
- `Sources/VibeWave/ViewModels/MenuBarViewModel.swift:35-63`

启动时创建状态图标会同时创建弹窗、HostingController、ViewModel 并执行多条数据库查询，即使用户从不打开弹窗。

建议：

- 启动时仅创建 `NSStatusItem`。
- 第一次点击时再创建弹窗和 ViewModel。
- 弹窗隐藏期间只标记数据过期，不立即刷新。
- 对 `.appDataDidUpdate` 事件进行 debounce 和合并。

### 4.6 Insights 在主线程执行缓存解码和持久化

相关位置：

- `Sources/VibeWave/ViewModels/InsightsViewModel.swift:78-84`
- `Sources/VibeWave/ViewModels/InsightsViewModel.swift:311-370`
- `Sources/VibeWave/ViewModels/InsightsViewModel.swift:395-429`

持久化热力图 JSON 的解码、render model 构建、编码和 `UserDefaults` 写入都可能发生在主 actor。

建议：

- 在后台任务中读取、解码、生成和编码。
- 主 actor 只负责最终状态赋值。
- 较大缓存改用原子文件存储，不使用 `UserDefaults`。
- 限制 render cache 的容量。

## 5. 启动与能耗

### 5.1 首次同步与自动备份可能同时运行

相关位置：

- `Sources/VibeWave/LocalizedRootView.swift:17-27`
- `Sources/VibeWave/Services/BackupCoordinator.swift:47-74`

应用启动时可能同时执行同步、聚合和完整数据库备份，争用 SQLite、磁盘和 CPU。

建议：

- 使用统一维护任务协调器。
- 首次同步完成后再检查补偿备份。
- 自动备份请求串行化并合并重复请求。

### 5.2 FileWatcher 使用永久重复定时器

相关位置：

- `Sources/VibeWave/Services/FileWatcher.swift:87-96`

即使没有文件事件，也会每五秒唤醒一次。

建议：

- 第一个事件到达时创建一次性 debounce timer。
- flush 后取消 timer。
- FSEvents 使用 utility QoS，并移除与五秒缓冲策略矛盾的 `NoDefer`。

### 5.3 定时任务缺少 leeway

相关位置：

- `Sources/VibeWave/Services/SyncScheduler.swift:13-19`
- `Sources/VibeWave/Services/BackupScheduler.swift:41-48`

精确定时会降低 macOS 合并系统唤醒的能力。

建议：

- 使用 `schedule(deadline:repeating:leeway:)`。
- 同步任务设置约 5% 至 10% 的容差。
- 每日备份可设置数分钟容差。

### 5.4 日志默认 debug 且每次访问 UserDefaults

相关位置：

- `Sources/VibeWave/Services/AppLogger.swift:48-67`
- `Sources/VibeWave/Services/FileWatcher.swift:175`

每条日志都会查询 `UserDefaults` 并创建字符串，文件事件密集时会增加额外开销。

建议：

- 缓存日志级别，仅在设置变化时更新。
- Release 默认使用 `.info` 或 `.warn`。
- 日志消息使用延迟构造。
- 非诊断模式下避免逐文件事件日志。

### 5.5 SQLite 每个连接可能使用较大缓存

相关位置：

- `Sources/VibeWave/Repositories/DatabaseRepository.swift:59-69`

`PRAGMA cache_size = -20000` 约等于每个 SQLite 连接 20 MiB。`DatabasePool` 存在多个 reader 时，内存占用可能被放大。

建议：

- 记录 DatabasePool 实际连接数和常驻内存。
- 根据基准测试降低 cache size 或限制 reader 数量。
- 评估大聚合查询是否应使用磁盘临时存储。

## 6. 构建配置

### 6.1 当前脚本打包 Debug 可执行文件

相关位置：

- `run-app.sh:72-84`

脚本使用普通 `swift build` 并从 `.build/debug` 打包。如果发布版本也使用该脚本，用户运行的是未优化 Debug 二进制文件。

建议：

```bash
swift build -c release
```

- 本地开发保留 Debug 模式。
- 发布与性能测试默认使用 Release 模式。
- 从 `.build/release` 复制 executable 和资源 bundle。

### 6.2 每次构建都会修改受版本控制的 Swift 文件

相关位置：

- `run-app.sh:37-69`
- `Sources/VibeWave/AppConfiguration.swift:16-20`

每次构建都会改写日期、提交和 build number，使 Swift 增量编译失效并产生工作区噪音。

建议：

- 将构建信息生成到 derived source 目录。
- 或通过编译参数和生成的 Info.plist 注入。
- 普通构建不要修改受版本控制的源码。

## 7. 推荐实施顺序

1. 将迁移和全量聚合移出工具循环。
2. 无数据变化时跳过聚合，改为脏时间桶增量聚合。
3. 使用 actor 串行执行同步、文件监听和备份任务。
4. 消除 Session 重建中的 N+1 查询。
5. 为 History、Projects 和 Overview 提供页面级 snapshot 查询。
6. 优化目录遍历、metadata 批量读取和文件稳定性检查。
7. 使用查询计划验证并补充项目聚合索引。
8. 限制 Chart hover 更新并缓存 Chart render model。
9. 懒加载菜单栏弹窗和隐藏页面数据。
10. 使用 Release 构建进行真实性能测试。

## 8. 性能验证方案

建议准备以下数据规模：

- 10 万条 messages
- 100 万条 messages
- 1000 万条 messages
- 1 万至 50 万条 sessions
- 1 至 5 年的 hourly、daily 和 monthly 聚合数据

每个热点路径记录：

1. p50、p95 和 p99 耗时。
2. 单次页面刷新执行的 SQL 数量。
3. SQLite VM steps 和 full-scan steps。
4. 写事务持续时间和 WAL 增长。
5. CPU、常驻内存和磁盘读取量。
6. SwiftUI 页面帧率和主线程卡顿时间。

重点场景：

- 冷启动和已有缓存启动。
- 无变化定时同步。
- 单个文件变化和大量文件变化。
- 全量同步和聚合重建。
- History 时间范围切换。
- 快速切换项目详情。
- 菜单栏弹窗首次打开和重复打开。
- Chart 高频 hover。

对热点 SQL 执行：

```sql
EXPLAIN QUERY PLAN <query>;
```

重点检查：

- `SCAN messages`
- `SCAN daily_stats`
- `SCAN monthly_stats`
- `CORRELATED SCALAR SUBQUERY`
- `USE TEMP B-TREE FOR GROUP BY`
- `USE TEMP B-TREE FOR ORDER BY`
- 目标复合索引是否被实际使用

所有聚合优化都应使用直接查询原始 `messages` 的结果作为正确性基准，避免以性能换取错误的 session 去重、时间范围或项目统计。
