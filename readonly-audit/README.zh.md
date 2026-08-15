# readonly-audit（只读安全审计）

[English](README.md) | 中文

只读安全审计模式 —— 以只读工具集 + 审计 persona 进行代码安全审计的预设。纯预设版，不依赖任何自定义插件。

## 简介

审计场景：分析源码、依赖清单、配置文件，查找漏洞、危险 API、弱配置、硬编码密钥与供应链风险。

- 只读工具集：`read` / `read_image` / `glob` / `grep` / `str_replace_editor`（仅 `view`）/ `web_search` / `ask_user_question`，外加受沙箱约束的 `bash` / `pwsh`（禁后台执行）。
- 审计 persona：明确要求不写中间产物、开始前询问报告交付方式、最终产出单一 Markdown 报告。
- 报告交付：对话输出，或经用户逐次批准写一份报告文件。

## 设计说明

本预设是「纯预设版」：早期版本依赖一个自定义插件（`dsh-readonly-security-audit`）做工具级白名单、会话沙箱切换与交付方式强制。经评估，插件的核心强制力（只读沙箱拒绝一切写入、写操作逐次批准）宿主原生已有：

- `fs-sandbox` 原生支持 `read-only` 模式，拒绝一切文件变更；
- `tool-fs` 在 `read-only` 下拒绝 `write`/`edit`，并走宿主原生的 `sandbox_permissions` + `approval` 逐次批准升级。

因此本版去掉了插件，只保留「只读工具集 + 审计 persona + 提示」这一层，成为纯文件预设，可像任何普通预设一样一行命令分发。

## 前提条件

只读强制由**部署的沙箱**承担，预设本身无法强制：

- 宿主 `sandbox-policy` 默认模式需为 `read-only`，或
- 会话运行时切换到 `read-only`（宿主 UI policy 控件 / `sandbox/mode` 事件）。

未满足前提时，`write`/`edit` 仍会按部署默认模式放行 —— 只读性取决于部署配置，而非本预设。

## 工具清单

| 工具 | 模式下的行为 |
|---|---|
| `read` / `read_image` / `glob` / `grep` | 只读，放行 |
| `str_replace_editor` | 仅 `view` 放行；`create`/`str_replace`/`insert` 被 read-only 沙箱拒绝 |
| `write` / `edit` | read-only 沙箱拒绝；报告写入经宿主逐次批准（单次放行后立即恢复只读） |
| `bash` / `pwsh` | 允许，但文件效果受 read-only 沙箱约束；`enableRunInBackground: false` |
| `web_search` | 放行（依赖公告、供应链研究）；`web_fetch` 默认关闭 |
| `ask_user_question` | 放行（报告交付方式、澄清） |

## 安装

目标机需安装 DeepSeek Harness（版本需带 `@deepseek-ai/dsh-*` 预设包），且满足上面的「前提条件」。

macOS / Linux:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/my-dsh-plugin/dsh-presets/main/readonly-audit/install-readonly-audit.sh)"
```

Windows PowerShell:

```powershell
irm https://raw.githubusercontent.com/my-dsh-plugin/dsh-presets/main/readonly-audit/install-readonly-audit.ps1 | iex
```

安装脚本特性：自动识别 `DSH_HOME`（未设置回退 `~/.dsh`）；`--check` / `-Check` 查看目标路径；默认拒绝覆盖，`--force` / `-Force` 覆盖前备份到 `.bak-<时间戳>`；完全自包含，可远程一行执行。

## 使用流程

1. 新建会话，选择「只读安全审计」。
2. 审计开始前，向用户询问报告交付方式（对话 or 文件）。
3. 只读分析：`read` / `glob` / `grep` / 受限 `bash` 等；不写任何中间产物。
4. 产出单一 Markdown 报告：每项发现含问题描述、严重级别、位置、证据、纯文本修复建议。
5. 按交付方式输出：对话直接回复，或经用户批准写入报告文件（一次批准，写后恢复只读）。

## 校验

安装后通过 roster 挂载校验：

```
standingKeyFor('readonly-audit')
```

或直接新建会话选择「只读安全审计」，确认工具清单与 persona。

## 与旧插件版的差异

| 维度 | 旧插件版（已弃用） | 本版（纯预设版） |
|---|---|---|
| 分发 | 需要构建并安装 npm 插件包 | 纯文件，一行命令安装 |
| 工具白名单强制 | 插件在 `tools/pre-execute` 拒绝非白名单工具 | 不装即没有；已装工具的放行由沙箱约束 |
| 只读强制 | 插件把会话切到 `read-only` | 依赖部署 `sandbox-policy` 默认 `read-only` |
| 交付方式 | 插件强制先选（`choose_audit_report_delivery`） | persona 提示询问，不强制 |
| `/readonly-audit` 命令 | 有 | 无（不依赖 commands 服务） |

旧插件版源码与文档保留在工作区项目 `readonly-security-audit/` 中。

## 文件说明

```
readonly-audit/
├── README.md                  # 英文版
├── README.zh.md               # 本文件
├── agent.cordis.yml           # 组合定义
├── preset.yml                 # 元数据
├── install-readonly-audit.sh  # 安装码（macOS/Linux，自包含）
└── install-readonly-audit.ps1 # 安装码（Windows，自包含，UTF-8 BOM）
```

## 许可

MIT
