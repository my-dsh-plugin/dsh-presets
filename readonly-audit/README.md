# readonly-audit

English | [中文](README.zh.md)

Read-only security audit mode — a preset for code security audits with a read-only tool set and an audit persona. Pure-preset edition: no custom plugin.

## Overview

Audit scenario: analyze source code, dependency manifests, and configuration files for vulnerabilities, dangerous APIs, weak configuration, hard-coded secrets, and supply-chain risks.

- Read-only tool set: `read` / `read_image` / `glob` / `grep` / `str_replace_editor` (view only) / `web_search` / `ask_user_question`, plus sandbox-constrained `bash` / `pwsh` (background execution disabled).
- Audit persona: must not write intermediate artifacts, must ask for report delivery before starting, produces a single Markdown report.
- Report delivery: in-conversation, or one report file written after explicit user approval.

## Design

This is the "pure-preset edition". An earlier version depended on a custom plugin (`dsh-readonly-security-audit`) for a tool-level allowlist, session sandbox switching, and mandatory delivery choice. Review showed the plugin's core enforcement (read-only sandbox rejecting all writes, per-call approval for writes) already exists natively in the host:

- `fs-sandbox` natively supports `read-only` mode and rejects every file mutation;
- `tool-fs` denies `write`/`edit` under `read-only` and goes through the host's native `sandbox_permissions` + `approval` per-call escalation.

So this edition drops the plugin and keeps only the "read-only tool set + audit persona + guidance" layer — a plain-file preset distributable in one command like any other preset.

## Prerequisite

The read-only enforcement is carried by the **deployment's sandbox**; the preset itself cannot enforce it:

- The host `sandbox-policy` default must be `read-only`, or
- The session must be switched to `read-only` at runtime (host UI policy control / `sandbox/mode` event).

If the prerequisite is not met, `write`/`edit` follow the deployment's default mode — read-only-ness depends on the deployment configuration, not on this preset.

## Tools

| Tool | Behavior in this mode |
|---|---|
| `read` / `read_image` / `glob` / `grep` | read-only, allowed |
| `str_replace_editor` | only `view` allowed; `create`/`str_replace`/`insert` denied by the read-only sandbox |
| `write` / `edit` | denied by the read-only sandbox; report writes go through host per-call approval (single release, immediately read-only again) |
| `bash` / `pwsh` | allowed, but file effects constrained by the read-only sandbox; `enableRunInBackground: false` |
| `web_search` | allowed (advisory, supply-chain research); `web_fetch` off by default |
| `ask_user_question` | allowed (report delivery, clarification) |

## Install

The target host must run DeepSeek Harness (a version that ships the `@deepseek-ai/dsh-*` preset packages) and meet the prerequisite above.

macOS / Linux:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/my-dsh-plugin/dsh-presets/main/readonly-audit/install-readonly-audit.sh)"
```

Windows PowerShell:

```powershell
irm https://raw.githubusercontent.com/my-dsh-plugin/dsh-presets/main/readonly-audit/install-readonly-audit.ps1 | iex
```

Installer notes: honors `DSH_HOME` (falls back to `~/.dsh`); `--check` / `-Check` shows the target path; refuses to overwrite by default, `--force` / `-Force` backs up to `.bak-<timestamp>` first; fully self-contained, runnable from a remote URL in one line.

## Workflow

1. Start a new session and pick "只读安全审计".
2. Before the audit starts, ask the user how to deliver the report (conversation or file).
3. Read-only analysis: `read` / `glob` / `grep` / constrained `bash`, etc.; no intermediate artifacts on disk.
4. Produce a single Markdown report: each finding contains problem description, severity, location, evidence, and a text-only remediation suggestion.
5. Deliver per the choice: reply in-conversation, or write the report file after user approval (one approval, read-only restored afterwards).

## Validation

Validate through the roster after install:

```
standingKeyFor('readonly-audit')
```

Or start a new session and pick "只读安全审计", then confirm the tool list and persona.

## Differences from the old plugin edition

| Dimension | Old plugin edition (deprecated) | This edition (pure preset) |
|---|---|---|
| Distribution | requires building and installing an npm plugin package | plain files, one-command install |
| Tool allowlist enforcement | plugin rejects non-allowlisted tools in `tools/pre-execute` | tools not mounted don't exist; mounted tools are constrained by the sandbox |
| Read-only enforcement | plugin switches the session to `read-only` | relies on the deployment `sandbox-policy` default `read-only` |
| Delivery choice | plugin forces the choice first (`choose_audit_report_delivery`) | persona asks, not enforced |
| `/readonly-audit` command | yes | no (no `commands` service dependency) |

The old plugin edition's source and docs live in the workspace project `readonly-security-audit/`.

## Files

```
readonly-audit/
├── README.md                  # this file
├── README.zh.md               # 中文版
├── agent.cordis.yml           # composition
├── preset.yml                 # metadata
├── install-readonly-audit.sh  # installer (macOS/Linux, self-contained)
└── install-readonly-audit.ps1 # installer (Windows, self-contained, UTF-8 BOM)
```

## License

MIT
