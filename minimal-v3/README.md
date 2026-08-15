# minimal-v3（极简V3）

中文：极简模式 V3 —— 在 DSH 官方「极简模式」（持久 bash + str_replace_editor）基础上，补充常用编码工具的预设。

English: Minimal V3 — the DSH official "minimal mode" (persistent bash + str_replace_editor) plus the common coding tools.

## 简介 / Overview

- 继承极简模式的一切：固定完整 persona（无运行时上下文注入）、持久 bash（`terminals` 隔离 realm）、本地裸文件系统 realm（`fs-local`）、无上下文压缩。
- 新增常用工具：`read`/`write`/`edit`（tool-fs）、`glob`/`grep`（tool-fs-search）、`pwsh`（Windows 下替代 bash，非 Windows 自动禁用）。
- `tool-fs` 与 `str_replace_editor` 共用同一个本地 fs realm（`isolate: { fs: true }`），两者操作的是同一套裸本地文件系统，且均要求绝对路径。

## 工具清单 / Tools

| 工具 / Tool | 来源 / Source | 说明 / Notes |
|---|---|---|
| `bash`（持久） | `dsh-tool-bash-persistent` | 极简原有；会话内状态持久，300s 超时 |
| `str_replace_editor` | `dsh-tool-str-replace-editor` | 极简原有；`view` 只读，`create`/`str_replace`/`insert` 走本地 fs |
| `read` / `write` / `edit` | `dsh-tool-fs` | 与 str_replace_editor 共用同一 fs realm |
| `glob` / `grep` | `dsh-tool-fs-search` | `sampleOverCapGlobResults: false`（超量结果按修改时间截断，不做跨顶层抽样） |
| `pwsh` | `dsh-tool-pwsh` | 仅 Windows 启用（`disabled: !!js process.platform !== 'win32'`） |

## 安装 / Install

目标机需安装 DeepSeek Harness（版本需带 `@deepseek-ai/dsh-*` 预设包，与来源机版本相当）。

macOS / Linux:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/my-dsh-plugin/dsh-presets/main/minimal-v3/install-minimal-v3.sh)"
```

Windows PowerShell:

```powershell
irm https://raw.githubusercontent.com/my-dsh-plugin/dsh-presets/main/minimal-v3/install-minimal-v3.ps1 | iex
```

安装脚本特性：

- 自动识别 `DSH_HOME` 环境变量，未设置时回退 `~/.dsh`；先运行 `--check` / `-Check` 可查看目标路径。
- 默认拒绝覆盖已存在安装；`--force` / `-Force` 覆盖前先备份到 `.bak-<时间戳>`。
- 脚本完全自包含（内容内嵌），可远程一行执行。

## 校验 / Validation

安装后通过 roster 挂载校验：

```
standingKeyFor('minimal-v3')
```

或直接新建会话选择「极简V3」，确认工具清单中出现 `bash`、`str_replace_editor`、`read`、`write`、`edit`、`glob`、`grep`（Windows 目标机额外有 `pwsh`）。

## 版本兼容 / Compatibility

- 预设行引用 `@deepseek-ai/dsh-*` 包（`dsh-tool-fs`、`dsh-tool-fs-search`、`dsh-tool-pwsh`、`dsh-fs-local`、`dsh-terminal*`、`dsh-tool-bash-persistent`、`dsh-persona`），均随部署提供，无需额外安装。
- 若目标机 DSH 版本较新，先对比其自带的 shipped `minimal/agent.cordis.yml`；行 id / 配置键有变化时，把新增的三行移植到目标机自己的 minimal 副本上再装。

## 文件说明 / Files

```
minimal-v3/
├── agent.cordis.yml              # 组合定义（预设本体）
├── preset.yml                    # 元数据（名称、描述）
├── install-minimal-v3.sh         # macOS/Linux 安装码（自包含）
└── install-minimal-v3.ps1        # Windows 安装码（自包含，UTF-8 BOM）
```

## 许可 / License

MIT
