# dsh-presets

English | [中文](README.zh.md)

A collection of agent preset modes for [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) (DSH). Each preset is a directory with `agent.cordis.yml` + `preset.yml` plus a cross-platform installer (bash for macOS/Linux, PowerShell for Windows) — one command installs it on any host, and the target instance's roster discovers the preset immediately.

## Presets

| Preset | Tools | Docs |
|---|---|---|
| [anchored-minimal](anchored-minimal/README.md) | bash, str_replace_editor, read/write/edit, glob/grep, pwsh (Windows only) — V4-Pro anchored (first request on the Minimal tool pair) | [README](anchored-minimal/README.md) |
| [flash-boost](flash-boost/README.md) | Flash-optimized: neutral + classify + anti-runaway persona, RL-shape first request — pick manually for V4 Flash sessions | [README](flash-boost/README.md) |
| [readonly-audit](readonly-audit/README.md) | read-only tool set + audit persona (bash/pwsh, read, glob/grep, str_replace_editor view, web_search) | [README](readonly-audit/README.md) |

## Layout

```
dsh-presets/
├── README.md                  # this file
├── README.zh.md               # 中文版
└── <preset-id>/
    ├── README.md              # detailed docs (English)
    ├── README.zh.md           # detailed docs (中文)
    ├── agent.cordis.yml       # composition
    ├── preset.yml             # metadata
    ├── install-<id>.sh        # installer (macOS/Linux)
    └── install-<id>.ps1       # installer (Windows, UTF-8 BOM)
```

## Install

The target host must run DeepSeek Harness (a version that ships the `@deepseek-ai/dsh-*` preset packages).

### anchored-minimal

macOS / Linux:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/my-dsh-plugin/dsh-presets/main/anchored-minimal/install-anchored-minimal.sh)"
```

Windows PowerShell:

```powershell
irm https://raw.githubusercontent.com/my-dsh-plugin/dsh-presets/main/anchored-minimal/install-anchored-minimal.ps1 | iex
```

### flash-boost

macOS / Linux:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/my-dsh-plugin/dsh-presets/main/flash-boost/install-flash-boost.sh)"
```

Windows PowerShell:

```powershell
irm https://raw.githubusercontent.com/my-dsh-plugin/dsh-presets/main/flash-boost/install-flash-boost.ps1 | iex
```

### readonly-audit

macOS / Linux:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/my-dsh-plugin/dsh-presets/main/readonly-audit/install-readonly-audit.sh)"
```

Windows PowerShell:

```powershell
irm https://raw.githubusercontent.com/my-dsh-plugin/dsh-presets/main/readonly-audit/install-readonly-audit.ps1 | iex
```

## Installer notes

- The installers honor the `DSH_HOME` environment variable and fall back to `~/.dsh` when unset. Run with `--check` / `-Check` first to see the target path.
- By default they refuse to overwrite an existing install; `--force` / `-Force` backs it up to `.bak-<timestamp>` first.
- Installers are fully self-contained (content embedded) so they can run from a remote URL in one line.
- See each preset's own README for tools, prerequisites, workflow, and version compatibility.

## Adding a preset

Each preset lives in its own directory with:

```
<preset-id>/
├── README.md               # detailed docs (English)
├── README.zh.md            # detailed docs (中文)
├── agent.cordis.yml        # composition
├── preset.yml              # metadata
├── install-<id>.sh         # installer (macOS/Linux)
└── install-<id>.ps1        # installer (Windows)
```

- Installers must be fully self-contained (content embedded) so they can run from a remote URL in one line.
- The ps1 files need a UTF-8 BOM so Windows PowerShell 5.1 parses Chinese correctly.
- The embedded preset content in each installer must stay byte-identical with the `agent.cordis.yml` / `preset.yml` beside it.
- Keep the root README's preset table and layout example in sync when adding a preset.

## License

MIT
