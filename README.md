# dsh-presets

中文：DeepSeek Harness (DSH) 的 Agent 预设模式合集。每个预设是一对 `agent.cordis.yml` + `preset.yml`，附跨平台安装脚本（macOS/Linux 用 bash，Windows 用 PowerShell），一行命令即可安装到任意主机，安装后目标实例的 roster 立即发现该预设。

English: A collection of agent preset modes for DeepSeek Harness (DSH). Each preset is an `agent.cordis.yml` + `preset.yml` pair with a cross-platform installer (bash for macOS/Linux, PowerShell for Windows) — one command installs it on any host, and the target instance's roster discovers the preset immediately.

## 预设列表 / Presets

| 预设 / Preset | 工具集 / Tools | 安装 / Install |
|---|---|---|
| 极简V3 / minimal-v3 | bash、str_replace_editor、read/write/edit、glob/grep、pwsh（仅 Windows） | 见下 / see below |
| 只读安全审计 / readonly-audit | 只读工具集 + 审计 persona（bash/pwsh、read、glob/grep、str_replace_editor view、web_search） | 见下 / see below |

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

安装脚本会自动识别 `DSH_HOME` 环境变量，未设置时回退到默认的 `~/.dsh`。不确定时先运行 `--check` / `-Check` 查看目标路径。

The installer honors the `DSH_HOME` environment variable and falls back to `~/.dsh` when unset. Run with `--check` / `-Check` first to see the target path.

安装完成后：新建会话选择「极简V3」确认工具清单，或通过 roster 的 `standingKeyFor('minimal-v3')` 做挂载校验。

After install: start a new session and pick "极简V3" to confirm the tool list, or validate via the roster's `standingKeyFor('minimal-v3')`.

### readonly-audit（只读安全审计）

macOS / Linux:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/my-dsh-plugin/dsh-presets/main/readonly-audit/install-readonly-audit.sh)"
```

Windows PowerShell:

```powershell
irm https://raw.githubusercontent.com/my-dsh-plugin/dsh-presets/main/readonly-audit/install-readonly-audit.ps1 | iex
```

纯预设版：不依赖任何自定义插件。只读强制由部署的 read-only 沙箱承担（宿主 `sandbox-policy` 默认模式需为 `read-only`，或会话切换到 read-only）；本预设只提供只读工具集、审计 persona 与报告交付提示。报告文件写入走宿主原生逐次批准升级。

Pure-preset edition: no custom plugin. The read-only enforcement is carried by the deployment's read-only sandbox (the host `sandbox-policy` default must be `read-only`, or the session must be switched to read-only); this preset only provides the read-capable tool set, the audit persona, and report-delivery guidance. Report-file writes go through the host's native per-call approval escalation.

## 新增预设 / Adding a preset

每个预设一个目录，包含：

Each preset lives in its own directory with:

```
<preset-id>/
├── agent.cordis.yml     # 组合定义 / composition
├── preset.yml           # 元数据 / metadata
└── install-minimal-v3.* # 自包含安装脚本 / self-contained installer
```

安装脚本必须完全自包含（内容内嵌），才能从远程一行执行。

Installers must be fully self-contained (content embedded) so they can run from a remote URL in one line.

## 许可 / License

MIT
