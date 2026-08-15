# flash-boost（Flash增强）

[English](README.md) | 中文

Flash 专用模式：中性 persona + 分类执行指令 + 回顾/防跑题锚（实测最优），首轮 RL 形状工具对、之后完整工具集。**手动选择**——会话跑在 DeepSeek V4 Flash 上时选本预设。

## 为什么手动切换

自动任务路由（router-standard 的做法）要在运行时对首条用户消息做 spec/react 分类——黑盒、可能分错、增加复杂度。手动选模式把路由决策交给你——**你最清楚这轮是构建还是修 bug**：Flash 会话选本预设，Pro 会话选锚定极简。

## 为什么是这个 persona

DeepSeek V4 Flash 的轨迹跟随**系统 persona**，而不是工具目录（[modeltest](https://github.com/xiaobright/modeltest)：Flash 即使面对完整 25 工具目录也保持极简式行为）。社区实测（[dsh-router-standard](https://github.com/yjh051108/dsh-router-standard) P11/P23，MIT）显示：

- 极简 spec 句在 Flash 上**反路由**（planGreen > 0）——锚定 Pro 的那句话对 Flash 起反作用；
- Flash 实测最优（w7）：中性身份 + 分类执行 + 回顾/防跑题锚 → 开放任务完成率 **0% → 100%**（P23）。

persona 作为完整系统提示词（`complete: true`），不被任何 section 稀释：

```
You are a helpful assistant.
Before acting, decide the task type (build or fix) and adopt the matching
style: build → hands-on production; fix → inspect-and-plan.
Before acting, briefly review what you have already done in this session and
continue from where you left off; do not repeat completed steps.
Do not run environment checks (echo, whoami, uname, node --version, date) or
exhaustive grep/glob scans.
Think deeply first, then produce.
```

## 为什么保留 RL 形状引导

Flash 的首轮工具面决定**行动 vs 纯推理**：实测（router-standard v0.2.0，官方 API）——shell + str_replace_editor → **100% 工具调用、18–29K 推理字符**；read/write/edit 面 → 仅 ~25% 行动、73–101K 推理。`bootstrap.mjs` 让首请求停留在 RL 工具对上，第一次持久 `tool/call` 或 `assistant/message` 后暴露完整工具集。

## 工具清单

| 工具 | 来源 | 说明 |
|---|---|---|
| `bash`（持久） | `dsh-tool-bash-persistent` | RL 形状对；状态持久，300s 超时 |
| `str_replace_editor` | `dsh-tool-str-replace-editor` | RL 形状对；共用本地 fs realm |
| `read` / `write` / `edit` | `dsh-tool-fs` | 提升后出现 |
| `glob` / `grep` | `dsh-tool-fs-search` | `sampleOverCapGlobResults: false` |
| `pwsh` | `dsh-tool-pwsh` | 仅 Windows |

## Windows 平台说明

持久 PTY bash 仅支持 linux/darwin（默认 `/bin/bash`），因此 Windows 上：

- `persistent-shell` 组被禁用（`!!js process.platform === 'win32'`）；
- `bootstrap.mjs` 会把 RL 形状工具对里的 `bash` 替换为 `pwsh`——Windows 上首个请求暴露的是 `pwsh` + `str_replace_editor`。

RL 形状的"行动 vs 纯推理"效果不变，只有工具对里的 shell 成员不同。注意 `pwsh` 非持久（每次调用新进程），不同于 POSIX 的持久 bash。

## 安装

目标机需安装 DeepSeek Harness（版本需带 `@deepseek-ai/dsh-*` 预设包）。

macOS / Linux:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/my-dsh-plugin/dsh-presets/main/flash-boost/install-flash-boost.sh)"
```

Windows PowerShell:

```powershell
irm https://raw.githubusercontent.com/my-dsh-plugin/dsh-presets/main/flash-boost/install-flash-boost.ps1 | iex
```

安装脚本特性：自动识别 `DSH_HOME`（未设置回退 `~/.dsh`）；`--check` / `-Check` 查看目标路径；默认拒绝覆盖，`--force` / `-Force` 覆盖前备份；完全自包含，可远程一行执行。

## 校验

安装后通过 roster 挂载校验：

```
standingKeyFor('flash-boost')
```

或直接新建会话选择「Flash增强」。**第一个模型请求只看到 RL 形状工具对**（`bash` + `str_replace_editor`）；第一次工具调用或模型回复后完整工具集出现。两个快照都是预期行为。

## 已知限制：会话中途切换模式

引导的前提是会话**从本预设开始**。请勿在对话中途切入或切出本预设（例如基于 `agentPreset.select` 的模式切换器）——中途会话历史里已有 `tool/call` / `assistant/message` 事件，引导阶段会被跳过。

推荐用法：**创建会话时选择本预设，并在会话生命周期内保持不变**。

## 版本兼容

- 预设行引用 `@deepseek-ai/dsh-*` 包，均随部署提供，无需额外安装。
- 若目标机 DSH 版本较新，先对比其自带的组合文件。

## 文件说明

```
flash-boost/
├── README.md                  # 英文版
├── README.zh.md               # 本文件
├── agent.cordis.yml           # 组合定义
├── bootstrap.mjs              # RL 形状锚定插件
├── preset.yml                 # 元数据
├── install-flash-boost.sh     # 安装码（macOS/Linux，自包含）
└── install-flash-boost.ps1    # 安装码（Windows，自包含，UTF-8 BOM）
```

## 致谢

Flash persona（w7）与 RL 形状引导基于 MIT 许可的 [dsh-router-standard](https://github.com/yjh051108/dsh-router-standard)（P11/P23 实测）与 [xiaobright/dsh-anchored-standard](https://github.com/xiaobright/dsh-anchored-standard)（首请求工具 schema 锚定）。

## 许可

MIT
