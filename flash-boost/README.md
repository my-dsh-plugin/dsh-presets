# flash-boost（Flash增强）

English | [中文](README.zh.md)

A Flash-optimized preset: neutral identity + classify-then-act + recall/anti-runaway anchors, with an RL-shape first-request tool pair. Manual selection — pick this preset when the session runs on DeepSeek V4 Flash.

## Why manual selection

Automatic task routing (the router-standard approach) classifies the first user message into spec/react at runtime — a black box that can misclassify and adds complexity. Manual mode selection puts the routing decision with the person who actually knows the task: pick this preset for Flash sessions, anchored-minimal for Pro sessions.

## Why this persona

DeepSeek V4 Flash's trajectory follows the **system persona**, not the tool catalog ([modeltest](https://github.com/xiaobright/modeltest): Flash stays minimal-like even with the full 25-tool catalog). Community measurement ([dsh-router-standard](https://github.com/yjh051108/dsh-router-standard) P11/P23, MIT) shows:

- The Minimal spec sentence **anti-routes on Flash** (planGreen > 0) — the one-liner that anchors Pro does the opposite for Flash.
- The measured Flash optimum (w7): neutral identity + classify-then-act + recall/anti-runaway anchors → open-task completion **0% → 100%** (P23).

The persona is kept as the complete system prompt (`complete: true`), so nothing dilutes it:

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

## Why the RL-shape bootstrap

On Flash the first-turn tool surface decides **action vs reasoning**: measured (router-standard v0.2.0, official API) — shell + str_replace_editor → **100% tool calls at 18–29K reasoning chars**; read/write/edit surface → ~25% action / 73–101K reasoning. `bootstrap.mjs` keeps the first request on the RL pair, then exposes the full catalog after the first durable `tool/call` or `assistant/message`.

## Tools

| Tool | Source | Notes |
|---|---|---|
| `bash` (persistent) | `dsh-tool-bash-persistent` | RL-shape pair; state persists, 300s timeout |
| `str_replace_editor` | `dsh-tool-str-replace-editor` | RL-shape pair; shares the local fs realm |
| `read` / `write` / `edit` | `dsh-tool-fs` | appears after promotion |
| `glob` / `grep` | `dsh-tool-fs-search` | `sampleOverCapGlobResults: false` |
| `pwsh` | `dsh-tool-pwsh` | Windows only |

## Platform notes (Windows)

The persistent PTY bash is linux/darwin-only (`/bin/bash` default), so on Windows:

- the `persistent-shell` group is disabled (`!!js process.platform === 'win32'`), and
- `bootstrap.mjs` substitutes `pwsh` for `bash` in the RL-shape pair — the first request on Windows exposes `pwsh` + `str_replace_editor`.

The RL-shape action/reasoning effect is unchanged; only the shell member differs. Note that `pwsh` is non-persistent (a fresh process per call), unlike the POSIX persistent bash.

## Install

The target host must run DeepSeek Harness (a version that ships the `@deepseek-ai/dsh-*` preset packages).

macOS / Linux:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/my-dsh-plugin/dsh-presets/main/flash-boost/install-flash-boost.sh)"
```

Windows PowerShell:

```powershell
irm https://raw.githubusercontent.com/my-dsh-plugin/dsh-presets/main/flash-boost/install-flash-boost.ps1 | iex
```

Installer notes: honors `DSH_HOME` (falls back to `~/.dsh`); `--check` / `-Check` shows the target path; refuses to overwrite by default, `--force` / `-Force` backs up to `.bak-<timestamp>` first; fully self-contained, runnable from a remote URL in one line.

## Validation

Validate through the roster after install:

```
standingKeyFor('flash-boost')
```

Or start a new session and pick "Flash增强". The FIRST request sees the RL-shape pair (`bash` + `str_replace_editor`); after the first tool call or reply the full catalog appears. Both snapshots are expected.

## Known limitation: mid-session preset switching

The bootstrap assumes the session **starts** on this preset. Do not switch into or out of it mid-conversation (e.g. via an agent-mode switcher riding `agentPreset.select`) — mid-session history already contains `tool/call` / `assistant/message` events, so the bootstrap phase is skipped.

Recommended usage: pick this preset when creating a session and keep it for the session's lifetime.

## Compatibility

- The preset rows reference `@deepseek-ai/dsh-*` packages shipped with the deployment — no extra installs needed.
- If the target DSH version is newer, compare its shipped compositions first.

## Files

```
flash-boost/
├── README.md                  # this file
├── README.zh.md               # 中文版
├── agent.cordis.yml           # composition
├── bootstrap.mjs              # RL-shape anchoring plugin
├── preset.yml                 # metadata
├── install-flash-boost.sh     # installer (macOS/Linux, self-contained)
└── install-flash-boost.ps1    # installer (Windows, self-contained, UTF-8 BOM)
```

## Credits

The Flash persona (w7) and RL-shape bootstrap are based on the MIT-licensed [dsh-router-standard](https://github.com/yjh051108/dsh-router-standard) (P11/P23 measurements) and [xiaobright/dsh-anchored-standard](https://github.com/xiaobright/dsh-anchored-standard) (first-request tool-schema anchoring).

## License

MIT
