# dsh-presets

中文：DeepSeek Harness (DSH) 的 Agent 预设模式合集。每个预设是一个目录：`agent.cordis.yml` + `preset.yml`，附跨平台安装脚本（macOS/Linux 用 bash，Windows 用 PowerShell），一行命令即可安装到任意主机，安装后目标实例的 roster 立即发现该预设。

English: A collection of agent preset modes for DeepSeek Harness (DSH). Each preset is a directory with `agent.cordis.yml` + `preset.yml` plus a cross-platform installer (bash for macOS/Linux, PowerShell for Windows) — one command installs it on any host, and the target instance's roster discovers the preset immediately.

## 预设列表 / Presets

| 预设 / Preset | 工具集 / Tools | 详细文档 / Docs |
|---|---|---|
| [极简V3 / minimal-v3](minimal-v3/README.md) | bash、str_replace_editor、read/write/edit、glob/grep、pwsh（仅 Windows） | [README](minimal-v3/README.md) |
| [只读安全审计 / readonly-audit](readonly-audit/README.md) | 只读工具集 + 审计 persona（bash/pwsh、read、glob/grep、str_replace_editor view、web_search） | [README](readonly-audit/README.md) |

## 目录结构 / Layout

```
dsh-presets/
├── README.md                  # 本文件 / this file
└── <preset-id>/
    ├── README.md              # 该预设的详细文档 / detailed docs
    ├── agent.cordis.yml       # 组合定义 / composition
    ├── preset.yml             # 元数据 / metadata
    ├── install-<id>.sh        # macOS/Linux 安装码 / installer
    └── install-<id>.ps1       # Windows 安装码 / installer (UTF-8 BOM)
```

## 安装 / Install

目标机需安装 DeepSeek Harness（版本需带 `@deepseek-ai/dsh-*` 预设包）。

The target host must run DeepSeek Harness (a version that ships the `@deepseek-ai/dsh-*` preset packages).

### minimal-v3（极简V3）

macOS / Linux:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/my-dsh-plugin/dsh-presets/main/minimal-v3/install-minimal-v3.sh)"
```

Windows PowerShell:

```powershell
irm https://raw.githubusercontent.com/my-dsh-plugin/dsh-presets/main/minimal-v3/install-minimal-v3.ps1 | iex
```

### readonly-audit（只读安全审计）

macOS / Linux:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/my-dsh-plugin/dsh-presets/main/readonly-audit/install-readonly-audit.sh)"
```

Windows PowerShell:

```powershell
irm https://raw.githubusercontent.com/my-dsh-plugin/dsh-presets/main/readonly-audit/install-readonly-audit.ps1 | iex
```

## 安装脚本通用说明 / Installer notes

- 自动识别 `DSH_HOME` 环境变量，未设置时回退默认 `~/.dsh`；先运行 `--check` / `-Check` 查看目标路径。
- 默认拒绝覆盖已存在安装；`--force` / `-Force` 覆盖前先备份到 `.bak-<时间戳>`。
- 脚本完全自包含（内容内嵌），可远程一行执行。
- 每个预设的详细说明（工具清单、前提条件、使用流程、版本兼容）见其目录内 README。

The installers honor the `DSH_HOME` environment variable and fall back to `~/.dsh` when unset. Run with `--check` / `-Check` first to see the target path. By default they refuse to overwrite an existing install; `--force` / `-Force` backs it up to `.bak-<timestamp>` first. Installers are fully self-contained (content embedded) so they can run from a remote URL in one line. See each preset's own README for tools, prerequisites, workflow, and version compatibility.

## 新增预设 / Adding a preset

每个预设一个目录，包含：

Each preset lives in its own directory with:

```
<preset-id>/
├── README.md               # 详细文档（中英双语）/ detailed docs (bilingual)
├── agent.cordis.yml        # 组合定义 / composition
├── preset.yml              # 元数据 / metadata
├── install-<id>.sh         # macOS/Linux 安装码 / installer
└── install-<id>.ps1        # Windows 安装码 / installer
```

- 安装脚本必须完全自包含（内容内嵌），才能从远程一行执行。
- ps1 文件需带 UTF-8 BOM（Windows PowerShell 5.1 正确解析中文的前提）。
- 安装脚本内嵌的预设内容必须与目录内 `agent.cordis.yml` / `preset.yml` 保持逐字节一致（可用脚本提取对比验证）。
- 新增预设后：根 README 的预设列表、目录结构示例同步更新。

Installers must be fully self-contained (content embedded) so they can run from a remote URL in one line. The ps1 files need a UTF-8 BOM so Windows PowerShell 5.1 parses Chinese correctly. The embedded preset content in each installer must stay byte-identical with the `agent.cordis.yml` / `preset.yml` beside it. Keep the root README's preset table and layout example in sync when adding a preset.

## 许可 / License

MIT
