# minimal-v3

English | [中文](README.zh.md)

Minimal V3 — the DSH official "minimal mode" (persistent bash + str_replace_editor) plus the common coding tools.

## Overview

- Inherits everything from the minimal mode: fixed complete persona (no runtime-context injection), persistent bash (isolated `terminals` realm), a bare local filesystem realm (`fs-local`), and no context compaction.
- Adds the common tools: `read`/`write`/`edit` (tool-fs), `glob`/`grep` (tool-fs-search), and `pwsh` (the Windows bash substitute, disabled on non-Windows automatically).
- `tool-fs` shares the same local fs realm (`isolate: { fs: true }`) with `str_replace_editor`, so both operate on the same bare local filesystem and require absolute paths.

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

Or start a new session and pick "极简V3"; confirm the tool list shows `bash`, `str_replace_editor`, `read`, `write`, `edit`, `glob`, `grep` (plus `pwsh` on Windows targets).

## Compatibility

- The preset rows reference `@deepseek-ai/dsh-*` packages (`dsh-tool-fs`, `dsh-tool-fs-search`, `dsh-tool-pwsh`, `dsh-fs-local`, `dsh-terminal*`, `dsh-tool-bash-persistent`, `dsh-persona`), all shipped with the deployment — no extra installs needed.
- If the target DSH version is newer, compare its shipped `minimal/agent.cordis.yml` first; if row ids / config keys changed, port the three added rows onto the target's own minimal copy before installing.

## Files

```
minimal-v3/
├── README.md                  # this file
├── README.zh.md               # 中文版
├── agent.cordis.yml           # composition
├── preset.yml                 # metadata
├── install-minimal-v3.sh      # installer (macOS/Linux, self-contained)
└── install-minimal-v3.ps1     # installer (Windows, self-contained, UTF-8 BOM)
```

## License

MIT
