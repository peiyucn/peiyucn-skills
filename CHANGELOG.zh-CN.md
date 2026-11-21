# 更新日志

简体中文 | [English](CHANGELOG.md) | [README](README.zh-CN.md)

记录 **note2md** 插件的所有可感知变更。格式遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)；版本号以 [`.claude-plugin/marketplace.json`](.claude-plugin/marketplace.json) 为准。

已下架的 `obscura-scrape` 插件不在此列出；其发布历史保留在 git tag 中。

## [0.6.0] - 2026-09-07

### 新增

- `agentsmd` 命令：`/note2md init` 收尾时在笔记根目录写入 `AGENTS.md` 工作区清单；该清单也可独立补建或刷新。

## [0.5.3] - 2026-09-06

### 变更

- 版本号改回每个插件的独立版本线。无用户可感知的行为变化。

## [0.5.1] - 2026-09-05

### 变更

- 生成的 `AGENTS.md` 工作区清单改用标准章节骨架。无用户可感知的行为变化。

## [0.5.0] - 2026-08-10

### 变更

- OneNote 转换改为脚本驱动。
- 模板系统重设计。

## [0.4.1] - 2026-08-06

### 文档

- 简化 `_import` 暂存区表述；明确非 Windows 环境必须手动导出 XML。

## [0.4.0] - 2026-08-06

### 变更

- OneNote 导入改版：`_import` 暂存区、双模式导入、XML 排版、表格 / 列表规则。

## [0.3.0] - 2026-08-05

### 变更

- 移除 Python 依赖；OneNote 导入改为 Agent 原生转换 + 强制校验，支持跨平台。

## [0.2.1] - 2026-08-04

### 修复

- `export-onenote.ps1` 在 Windows PowerShell 5.1 下因编码导致的中文解析报错。

## [0.2.0] - 2026-08-04

### 新增

- SectionGroup 递归导出 / 转换。
- 丢失矩阵与已知限制文档。

### 修复

- 插件清单与失效链接。

## [0.1.0] - 2026-07-29

### 新增

- 首个版本：OneNote 迁移、斜杠命令、模板系统。
