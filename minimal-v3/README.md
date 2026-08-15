# minimal-v3

English | [中文](README.zh.md)

Minimal V3 — the DSH official "minimal mode" (persistent bash + str_replace_editor) plus the common coding tools.

## Overview

- Inherits everything from the minimal mode: fixed complete persona (no runtime-context injection), persistent bash (isolated `terminals` realm), a bare local filesystem realm (`fs-local`), and no context compaction.
- Adds the common tools: `read`/`write`/`edit` (tool-fs), `glob`/`grep` (tool-fs-search), and `pwsh` (the Windows bash substitute, disabled on non-Windows automatically).
- `tool-fs` shares the same local fs realm (`isolate: { fs: true }`) with `str_replace_editor`, so both operate on the same bare local filesystem and require absolute paths.
- **V4-Pro anchoring** (the core design point): DeepSeek V4 Pro conditions strongly on the API-visible first-request tool catalog — community Project2 evidence ([xiaobright/modeltest](https://github.com/xiaobright/modeltest), MIT) measured Minimal at 99/96 vs Standard at 91/92, with the first-request tool schema as the decisive variable. `bootstrap.mjs` therefore keeps the FIRST model request on the official Minimal tool pair (`bash` + `str_replace_editor`) and strips auto-injected context, then exposes the full minimal-v3 catalog after the first durable `tool/call` or `assistant/message`. The persona stays byte-identical to Minimal for the whole session.

## Why this preset exists

The DSH official `minimal` preset is deliberately tiny: a fixed one-line persona, no auto-injected workspace or skill context, no runtime-context snapshots, and exactly two tools (`bash` + `str_replace_editor`). That minimalism is not just a design taste — it matches the conditions DeepSeek V4 Pro was trained against, and the model performs measurably worse under the "richer" standard-family presets.

Community evaluation ([xiaobright/modeltest](https://github.com/xiaobright/modeltest), Project2, DeepSeek V4 Pro, `reasoningEffort=max`, MIT):

| Preset | Ability (run1/run2) | `let me` count | First-request tool catalog |
|---|---:|---:|---|
| Standard | 91 | 208 | 25 tools |
| PTC | 92 | 194 | `run_code` |
| **Minimal** | **99 / 96** | **0 / 0** | 2 tools |
| Anchored Standard | **98 / 99** | 1 / 0 | 2 tools, then full |

Three variables decide whether V4 Pro stays on the Minimal trajectory:

1. **First-request tool catalog (decisive).** The API-visible tool schema on the FIRST model request decides the trajectory. The Minimal pair anchored 5/5 runs with zero `let me` first-lines; every standard-family schema (pwsh/read, pwsh only, sandboxed bash/read) fell into standard-like behavior 11/11. Output-budget caps mattered at 1024 tokens, but the Minimal schema anchors at the adapter default (256000) with no cap needed.
2. **Persona must stay byte-identical.** The one-liner `You are a helpful software engineer assistant.` is part of the conditioning; rewording it broke the `We need` reasoning style in paraphrase runs. `complete: true` keeps it the whole system prompt.
3. **No auto-injected context on the first request.** The available-skills reminder and the AGENTS.md/CLAUDE.md digest break the anchor (0/9 anchored with the skill catalog present vs ~81% without).

So a preset that wants Minimal's capability but more tools faces a conflict: adding `read`/`write`/`edit`/`glob`/`grep` to the first request is exactly what pulls V4 Pro off the Minimal trajectory. **minimal-v3 resolves the conflict with two-phase tool anchoring.**

## How it works

`bootstrap.mjs` (this preset's only addition over `minimal`) hooks two waterfalls:

- `system-prompt/assemble` — narrows the assembled tool catalog to the official Minimal pair (`bash` + `str_replace_editor`) while the session is unpromoted;
- `agent/pre-step` — strips auto-injected context messages (`skill-catalog`, `agent-instructions` sources) during the same phase.

Phase is derived from **durable session events**, not memory: the first `tool/call` OR `assistant/message` promotes the session, and the phase survives resume/reload by replay. After promotion the full minimal-v3 catalog is exposed and stays exposed — promotion is one-way and permanent.

| Phase | Tool catalog | Auto-injected context |
|---|---|---|
| Request #1 (bootstrap) | `bash`, `str_replace_editor` (Minimal-exact) | stripped |
| After first tool call / reply | full: `bash`, `str_replace_editor`, `read`, `write`, `edit`, `glob`, `grep`, `pwsh` (Windows) | normal |

The persona (`complete: true`) is never touched, so the system prompt is Minimal-exact for the whole session; only the tool catalog changes phase.

Robustness: promotion decisions are memoized per session; subagents are always promoted; a missing bootstrap tool degrades to the full catalog with a one-time warning instead of throwing; the context filter degrades to "keep everything" on failure — a filter bug can never brick or starve a session.

This preset is a reproduction of the community pattern, not a universal claim: the benchmark is a single personal evaluation on one workload. Measure on your own tasks before trusting the anchoring effect.

## Tools

| Tool | Source | Notes |
|---|---|---|
| `bash` (persistent) | `dsh-tool-bash-persistent` | from minimal; state persists across calls, 300s timeout |
| `str_replace_editor` | `dsh-tool-str-replace-editor` | from minimal; `view` is read-only, `create`/`str_replace`/`insert` go through the local fs |
| `read` / `write` / `edit` | `dsh-tool-fs` | shares the same fs realm as str_replace_editor |
| `glob` / `grep` | `dsh-tool-fs-search` | `sampleOverCapGlobResults: false` (over-cap results truncate by mtime, no cross-top-level sampling) |
| `pwsh` | `dsh-tool-pwsh` | Windows only (`disabled: !!js process.platform !== 'win32'`) |

## Install

The target host must run DeepSeek Harness (a version that ships the `@deepseek-ai/dsh-*` preset packages, roughly matching the source machine).

macOS / Linux:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/my-dsh-plugin/dsh-presets/main/minimal-v3/install-minimal-v3.sh)"
```

Windows PowerShell:

```powershell
irm https://raw.githubusercontent.com/my-dsh-plugin/dsh-presets/main/minimal-v3/install-minimal-v3.ps1 | iex
```

Installer notes:

- Honors the `DSH_HOME` environment variable, falls back to `~/.dsh` when unset; run `--check` / `-Check` first to see the target path.
- Refuses to overwrite an existing install by default; `--force` / `-Force` backs it up to `.bak-<timestamp>` first.
- Fully self-contained (content embedded), runnable from a remote URL in one line.

## Validation

Validate through the roster after install:

```
standingKeyFor('minimal-v3')
```

Or start a new session and pick "极简V3". The FIRST model request sees only the Minimal tool pair (`bash` + `str_replace_editor`); after the first tool call or assistant reply the full catalog appears (`read`, `write`, `edit`, `glob`, `grep`, plus `pwsh` on Windows). Both snapshots are expected — the bootstrap phase is by design.

## Compatibility

- The preset rows reference `@deepseek-ai/dsh-*` packages (`dsh-tool-fs`, `dsh-tool-fs-search`, `dsh-tool-pwsh`, `dsh-fs-local`, `dsh-terminal*`, `dsh-tool-bash-persistent`, `dsh-persona`), all shipped with the deployment — no extra installs needed.
- If the target DSH version is newer, compare its shipped `minimal/agent.cordis.yml` first; if row ids / config keys changed, port the three added rows onto the target's own minimal copy before installing.

## Files

```
minimal-v3/
├── README.md                  # this file
├── README.zh.md               # 中文版
├── agent.cordis.yml           # composition
├── bootstrap.mjs              # V4-Pro anchoring plugin (first-request Minimal tool pair)
├── preset.yml                 # metadata
├── install-minimal-v3.sh      # installer (macOS/Linux, self-contained)
└── install-minimal-v3.ps1     # installer (Windows, self-contained, UTF-8 BOM)
```

## Credits

The V4-Pro anchoring design is based on the MIT-licensed [xiaobright/dsh-anchored-standard](https://github.com/xiaobright/dsh-anchored-standard) (first-request tool-schema anchoring), simplified for minimal-v3: one-way promotion, no discovery-tool resident set.

## License

MIT
