<div align="center">
<h1>VibeWave</h1>
一款 macOS 原生应用，让你洞察自己的 Vibe Coding 节奏。

> **注意**: 目前仅支持 OpenCode

<img src="art/VibeWave.png" width="60%">

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Swift](https://img.shields.io/badge/Swift-5.10-orange.svg)](https://swift.org)
[![macOS](https://img.shields.io/badge/macOS-14.0%2B-blue.svg)](https://www.apple.com/macos)

[中文](README.zh_CN.md)  |  [English](README.md)

[功能特性](#功能特性) • [快速开始](#快速开始) • [贡献指南](#贡献指南)

</div>

---

## 功能特性

VibeWave 提供了一套完整的 OpenCode AI 使用统计和分析功能：

### 统计指标
- **用量统计**: Token 消耗、会话数量、总成本
- **模型分析**: Top 5 模型使用排名
- **项目分析**: Top 5 项目使用排名
- **时间趋势**: 按天/周/月查看使用趋势
- **效率指标**: Token 输出比、推理 Token 占比等

### 国际化
- **多语言支持**: 中文、英文
- **双语界面**: 完整的国际化支持

---

## 快速开始

### 系统要求
- macOS 14.0 或更高版本
- Xcode 15.0 或更高版本（开发）
- Swift 5.10 或更高版本

### 安装

```bash
# 克隆仓库
git clone https://github.com/lumenvibewave/vibewave.git
cd vibewave

# 构建并运行（默认）
./run-app.sh

# 或仅构建
./run-app.sh --build

# 或显式构建并运行
./run-app.sh --run
```

### 配置

首次运行后，在 Settings 页面配置 OpenCode 数据源路径：

1. 打开 VibeWave 应用
2. 点击 Settings 标签
3. 选择同步策略（推荐：自动同步）

### OpenCode v2 接入（1.3.1）

- 在启动、回到前台和同步时识别所选数据库；v1 的空占位表不会被误判为 v2。
- 已支持的数据自动接续；未知格式暂停同步并提示更新，已有统计仍可查看。
- 数据转换进行中会等待；历史覆盖或消耗核对未完成时显示缺失会话数量。
- v2 从只读源读取，会话、统计和同步进度在本地事务中一起更新。
- 分叉复制的上下文不重复计入活动和消耗；撤回后的已发生消耗、标题生成和压缩费用保留。
- 持久消耗事件没有记录模型时，模型归属保持未知，不根据当前模型猜测。
- 转换后仅使用源数据库保留的 v1 历史记录核对隐藏摘要消耗；本地过期缓存不会额外累计。
- v2 默认不持久化事件日志。缺少明细但已包含在会话累计值中的消耗单独记账，模型标为未知，按会话创建时间归属；设置页明确说明此统计口径。
- 明细超过权威累计值等真正不一致的会话保留原有统计，不清零。
- 本实现已核对官方 v2.0.30 数据合同，并使用本机转换后的 2,229 个会话完成只读源验收：逐会话消耗、五类 Token、小时/日/月汇总一致，重复同步不重复累计。

研发版本由受版本管理的 `.version` 定义；本地构建号由 `.build_number` 自动递增。
`./run-app.sh --build` 将二者写入 App 的 Info.plist，并记录源码分支、修订及未提交状态。
正式发布标签必须与 `.version` 一致。

### 版本与自动发布规范

- 版本号使用 `主版本.次版本.修订号`，例如 `1.3.1`；Git 标签使用 `v1.3.1`。
- 先在 `dev` 研发和验收，再合并到 `main`；正式标签必须指向当前 `main` 提交。
- 推送正式标签会触发 GitHub Actions；手动运行仅构建和保存产物，不创建正式发布。
- 正式包使用 `Release` 优化构建，构建号取该工作流的 `GITHUB_RUN_NUMBER`，与本地研发计数独立。
- 下载包命名为 `VibeWave-<版本>-build.<构建号>-macOS-<架构>.zip`；Release 标题同时显示版本和构建号。
- 发布同时提供 `SHA256SUMS` 和 `build-info.json`，可核对下载文件、源码提交与流水线。
- App 的 Info.plist 记录版本、构建号、构建配置、源码引用和修订；构建不改写应用源码。

### 故障排除

下载应用后如果提示"VibeWave.app 已损坏，无法打开"：

```bash
xattr -d com.apple.quarantine VibeWave.app
```

然后再次尝试打开应用。

---

## 贡献指南

欢迎贡献代码、报告问题或提出新功能建议！

### 如何贡献
1. Fork 本仓库
2. 创建您的特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交您的更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启一个 Pull Request

---

## 开源协议

本项目采用 [MIT License](LICENSE) 开源。

---

<div align="center">
<b>用 ❤️ 构建</b>

**[回到顶部 ↑](#vibewave)**

</div>
