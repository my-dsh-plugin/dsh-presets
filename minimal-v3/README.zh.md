# minimal-v3（极简V3）

[English](README.md) | 中文

极简模式 V3 —— 在 DSH 官方「极简模式」（持久 bash + str_replace_editor）基础上，补充常用编码工具的预设。

## 简介

- 继承极简模式的一切：固定完整 persona（无运行时上下文注入）、持久 bash（`terminals` 隔离 realm）、本地裸文件系统 realm（`fs-local`）、无上下文压缩。
- 新增常用工具：`read`/`write`/`edit`（tool-fs）、`glob`/`grep`（tool-fs-search）、`pwsh`（Windows 下替代 bash，非 Windows 自动禁用）。
- `tool-fs` 与 `str_replace_editor` 共用同一个本地 fs realm（`isolate: { fs: true }`），两者操作的是同一套裸本地文件系统，且均要求绝对路径。
- **V4 Pro 锚定（核心设计点）**：DeepSeek V4 Pro 强依赖 API 可见的首请求工具目录——社区 Project2 实测（[xiaobright/modeltest](https://github.com/xiaobright/modeltest)，MIT）极简模式 99/96 vs 标准模式 91/92，首请求工具 schema 是决定性变量。`bootstrap.mjs` 让**第一个模型请求**只暴露官方极简工具对（`bash` + `str_replace_editor`）并剥离自动注入的上下文，在会话出现第一次持久的 `tool/call` 或 `assistant/message` 后，再暴露 minimal-v3 完整工具集；persona 全程与极简模式逐字节一致。

## 为什么要做这个模式

DSH 官方「极简模式」刻意保持极小：固定单行 persona、无自动注入的工作区/skill 上下文、无运行时上下文快照、只有两个工具（`bash` + `str_replace_editor`）。这种极简不是口味问题——它恰好匹配 DeepSeek V4 Pro 训练时的条件，模型在更"丰富"的标准族预设下表现实测更差。

社区实测（[xiaobright/modeltest](https://github.com/xiaobright/modeltest)，Project2，DeepSeek V4 Pro，`reasoningEffort=max`，MIT）：

| 预设 | Ability（run1/run2） | `let me` 计数 | 首请求工具目录 |
|---|---:|---:|---|
| Standard | 91 | 208 | 25 个工具 |
| PTC | 92 | 194 | `run_code` |
| **Minimal** | **99 / 96** | **0 / 0** | 2 个工具 |
| Anchored Standard | **98 / 99** | 1 / 0 | 2 个工具，随后全量 |

决定 V4 Pro 是否保持在极简轨迹上的三个变量：

1. **首请求工具目录（决定性）**。**第一个模型请求**的 API 可见工具 schema 决定轨迹：极简工具对 5/5 次锚定、零 `let me` 首行；任何标准族 schema（pwsh/read、pwsh only、sandboxed bash/read）11/11 落入标准式行为。输出预算在 1024 时也有影响，但极简 schema 在适配器默认值（256000）下无需上限即可锚定。
2. **persona 必须逐字节一致**。单行 `You are a helpful software engineer assistant.` 本身是条件化的一部分；改写会让 `We need` 推理风格退化（改写实验均落入标准式）。`complete: true` 让它成为完整系统提示词。
3. **首请求不能有自动注入上下文**。available-skills 提醒和 AGENTS.md/CLAUDE.md 摘要会破坏锚定（带 skill 目录时 0/9 锚定，去掉后约 81%）。

因此，「想要极简模式的能力、又想要更多工具」的预设面临冲突：把 `read`/`write`/`edit`/`glob`/`grep` 放进首请求，恰恰会把 V4 Pro 拉离极简轨迹。**minimal-v3 用两阶段工具锚定解决这个冲突。**

## 原理

`bootstrap.mjs`（本预设相对极简模式唯一的增量）挂接两个瀑布：

- `system-prompt/assemble` —— 会话未提升时，把组装好的工具目录收窄为官方极简工具对（`bash` + `str_replace_editor`）；
- `agent/pre-step` —— 同一阶段剥离自动注入的上下文消息（`skill-catalog`、`agent-instructions` 两种来源）。

阶段从**持久会话事件**推导而非内存：第一次 `tool/call` **或** `assistant/message` 即提升会话，resume/reload 通过事件重放保持阶段。提升后完整 minimal-v3 工具集出现并保持——提升是单向、永久的。

| 阶段 | 工具目录 | 自动注入上下文 |
|---|---|---|
| 请求 #1（引导） | `bash`、`str_replace_editor`（与极简完全一致） | 已剥离 |
| 第一次工具调用/回复后 | 完整：`bash`、`str_replace_editor`、`read`、`write`、`edit`、`glob`、`grep`、`pwsh`（Windows） | 正常 |

persona（`complete: true`）全程不动，系统提示词与会话保持一致、与极简模式逐字节相同；只有工具目录分阶段变化。

健壮性：提升决策按会话记忆化；子代理始终全量；引导工具缺失时降级为完整目录并一次性告警，绝不抛错卡死；上下文过滤器失败时降级为"全部保留"——过滤器 bug 不会饿死或卡死会话。

本预设是对社区模式的复现，不是普适结论：该基准只是单一工作负载上的个人评测。在信任锚定效果前，请在自己的任务上实测。

## 工具清单

| 工具 | 来源 | 说明 |
|---|---|---|
| `bash`（持久） | `dsh-tool-bash-persistent` | 极简原有；会话内状态持久，300s 超时 |
| `str_replace_editor` | `dsh-tool-str-replace-editor` | 极简原有；`view` 只读，`create`/`str_replace`/`insert` 走本地 fs |
| `read` / `write` / `edit` | `dsh-tool-fs` | 与 str_replace_editor 共用同一 fs realm |
| `glob` / `grep` | `dsh-tool-fs-search` | `sampleOverCapGlobResults: false`（超量结果按修改时间截断，不做跨顶层抽样） |
| `pwsh` | `dsh-tool-pwsh` | 仅 Windows 启用（`disabled: !!js process.platform !== 'win32'`） |

## 安装

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

## 校验

安装后通过 roster 挂载校验：

```
standingKeyFor('minimal-v3')
```

或直接新建会话选择「极简V3」。**第一个模型请求只看到极简工具对**（`bash` + `str_replace_editor`）；第一次工具调用或模型回复后完整工具集出现（`read`、`write`、`edit`、`glob`、`grep`，Windows 上另有 `pwsh`）。两个快照都是预期行为——引导阶段是设计使然。

## 版本兼容

- 预设行引用 `@deepseek-ai/dsh-*` 包（`dsh-tool-fs`、`dsh-tool-fs-search`、`dsh-tool-pwsh`、`dsh-fs-local`、`dsh-terminal*`、`dsh-tool-bash-persistent`、`dsh-persona`），均随部署提供，无需额外安装。
- 若目标机 DSH 版本较新，先对比其自带的 shipped `minimal/agent.cordis.yml`；行 id / 配置键有变化时，把新增的三行移植到目标机自己的 minimal 副本上再装。

## 文件说明

```
minimal-v3/
├── README.md                  # 英文版
├── README.zh.md               # 本文件
├── agent.cordis.yml           # 组合定义
├── bootstrap.mjs              # V4 Pro 锚定插件（首请求极简工具对）
├── preset.yml                 # 元数据
├── install-minimal-v3.sh      # 安装码（macOS/Linux，自包含）
└── install-minimal-v3.ps1     # 安装码（Windows，自包含，UTF-8 BOM）
```

## 致谢

V4 Pro 锚定设计基于 MIT 许可的 [xiaobright/dsh-anchored-standard](https://github.com/xiaobright/dsh-anchored-standard)（首请求工具 schema 锚定），为 minimal-v3 做了简化：单向提升、无发现工具常驻集。

## 许可

MIT
