# dsh-presets

[English](README.md) | 中文

[DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) (DSH) 的 Agent 预设模式合集。每个预设是一个目录：`agent.cordis.yml` + `preset.yml`，附跨平台安装脚本（macOS/Linux 用 bash，Windows 用 PowerShell），一行命令即可安装到任意主机，安装后目标实例的 roster 立即发现该预设。

## 预设列表

| 预设 | 工具集 | 详细文档 |
|---|---|---|
| [极简V3 / minimal-v3](minimal-v3/README.zh.md) | bash、str_replace_editor、read/write/edit、glob/grep、pwsh（仅 Windows） | [README](minimal-v3/README.zh.md) |
| [只读安全审计 / readonly-audit](readonly-audit/README.zh.md) | 只读工具集 + 审计 persona（bash/pwsh、read、glob/grep、str_replace_editor view、web_search） | [README](readonly-audit/README.zh.md) |

## 目录结构

```
dsh-presets/
├── README.md                  # 本文件
├── README.zh.md               # English version
└── <preset-id>/
    ├── README.md              # 详细文档（英文）
    ├── README.zh.md           # 详细文档（中文）
    ├── agent.cordis.yml       # 组合定义
    ├── preset.yml             # 元数据
    ├── install-<id>.sh        # 安装码（macOS/Linux）
    └── install-<id>.ps1       # 安装码（Windows，UTF-8 BOM）
```

## 安装

目标机需安装 DeepSeek Harness（版本需带 `@deepseek-ai/dsh-*` 预设包）。

### 极简V3 / minimal-v3

macOS / Linux:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/my-dsh-plugin/dsh-presets/main/minimal-v3/install-minimal-v3.sh)"
```

Windows PowerShell:

```powershell
irm https://raw.githubusercontent.com/my-dsh-plugin/dsh-presets/main/minimal-v3/install-minimal-v3.ps1 | iex
```

### 只读安全审计 / readonly-audit

macOS / Linux:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/my-dsh-plugin/dsh-presets/main/readonly-audit/install-readonly-audit.sh)"
```

Windows PowerShell:

```powershell
irm https://raw.githubusercontent.com/my-dsh-plugin/dsh-presets/main/readonly-audit/install-readonly-audit.ps1 | iex
```

## 安装脚本通用说明

- 自动识别 `DSH_HOME` 环境变量，未设置时回退默认 `~/.dsh`；先运行 `--check` / `-Check` 查看目标路径。
- 默认拒绝覆盖已存在安装；`--force` / `-Force` 覆盖前先备份到 `.bak-<时间戳>`。
- 脚本完全自包含（内容内嵌），可远程一行执行。
- 每个预设的详细说明（工具清单、前提条件、使用流程、版本兼容）见其目录内 README。

## 新增预设

每个预设一个目录，包含：

```
<preset-id>/
├── README.md               # 详细文档（英文）
├── README.zh.md            # 详细文档（中文）
├── agent.cordis.yml        # 组合定义
├── preset.yml              # 元数据
├── install-<id>.sh         # 安装码（macOS/Linux）
└── install-<id>.ps1        # 安装码（Windows）
```

- 安装脚本必须完全自包含（内容内嵌），才能从远程一行执行。
- ps1 文件需带 UTF-8 BOM（Windows PowerShell 5.1 正确解析中文的前提）。
- 安装脚本内嵌的预设内容必须与目录内 `agent.cordis.yml` / `preset.yml` 保持逐字节一致（可用脚本提取对比验证）。
- 新增预设后：根 README 的预设列表、目录结构示例同步更新。

## 许可

MIT
