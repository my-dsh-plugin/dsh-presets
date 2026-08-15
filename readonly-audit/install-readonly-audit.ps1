# install-readonly-audit.ps1 - 只读安全审计 preset install script (PowerShell)
#
# Installs the "只读安全审计" user preset (agent.cordis.yml + preset.yml) into
# this machine's DSH user preset root. Once installed, the target instance's
# roster discovers the preset immediately - no registration or restart needed.
# The script is fully self-contained (content embedded), so it can be piped
# from a remote URL.
#
# Pure-preset edition: this mode does NOT depend on any custom plugin. The
# read-only enforcement is carried by the deployment's read-only sandbox (the
# host sandbox-policy default must be read-only, or the session must be
# switched to read-only); this preset only contributes the read-capable tool
# set, the audit persona, and the report-delivery guidance. Report-file writes
# go through the host's native per-call approval escalation (write denied
# under read-only -> sandbox_permissions + approval for exactly that call).
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File install-readonly-audit.ps1
#   powershell -ExecutionPolicy Bypass -File install-readonly-audit.ps1 -Force   # overwrite existing install (backs up first)
#   powershell -ExecutionPolicy Bypass -File install-readonly-audit.ps1 -Check   # print target path and status, write nothing
#
# Remote install (after hosting this file in any open-source repo):
#   irm https://raw.githubusercontent.com/<owner>/<repo>/<branch>/readonly-audit/install-readonly-audit.ps1 | iex
#   # or, to bypass the execution policy explicitly:
#   powershell -ExecutionPolicy Bypass -c "irm https://raw.githubusercontent.com/<owner>/<repo>/<branch>/readonly-audit/install-readonly-audit.ps1 | iex"

[CmdletBinding()]
param(
  [switch]$Force,
  [switch]$Check
)

$ErrorActionPreference = 'Stop'

$DSH_HOME = if ($env:DSH_HOME) { $env:DSH_HOME } else { Join-Path $HOME '.dsh' }
$PresetRoot = Join-Path $DSH_HOME '.agent-presets'
$TargetDir = Join-Path $PresetRoot 'readonly-audit'

$PresetYml = @'
name: 只读安全审计
description: 只读安全审计模式（纯预设版）：只读工具集 + 审计 persona；文件写入依赖部署的 read-only 沙箱与宿主逐次批准。
'@

$AgentCordisYml = @'
# The `readonly-audit` agent preset: a read-only security audit mode.
#
# Pure-preset edition: no custom plugin. The enforcement owner is the
# deployment's read-only sandbox (the host `sandbox-policy` default must be
# `read-only`, or the session must be switched to read-only); this preset only
# contributes the read-capable tool set, the audit persona, and the delivery
# guidance. Report-file writes go through the host's native per-call approval
# escalation (write denied under read-only -> sandbox_permissions + approval
# for exactly that call).

# ── identity ────────────────────────────────────────────────────────────────

- id: persona
  name: '@deepseek-ai/dsh-persona'
  config:
    text: >-
      You are a security audit agent powered by the {{model}} model. Your working directory is {{cwd}}.
      Read and analyze source code, dependency manifests, and configuration files to find
      vulnerabilities, dangerous APIs, weak configuration, hard-coded secrets, and supply-chain risks.
      This deployment runs this preset under a read-only file sandbox: the system denies every file
      mutation (write, edit, str_replace insert/create, and shell commands that write) unless the
      user explicitly approves a single escalation for that exact call. Rely on that enforcement;
      do not attempt to bypass it. Before starting the audit, ask the user how they want to receive
      the final report: directly in the conversation, or written to a report file (that single write
      requires their approval). Do not write intermediate notes or artifacts to disk.

- id: agent-instructions
  name: '@deepseek-ai/dsh-agent-instructions'
  config:
    maxBytes: 65536

# ── shell ───────────────────────────────────────────────────────────────────

# The executors stay in the host plane; the host's read-only sandbox policy
# confines these tools' file effects. Background execution is disabled so no
# detached process can outlive the session's policy.
- id: tool-bash
  name: '@deepseek-ai/dsh-tool-bash'
  disabled: !!js process.platform === 'win32'
  config:
    enableRunInBackground: false

- id: tool-pwsh
  name: '@deepseek-ai/dsh-tool-pwsh'
  disabled: !!js process.platform !== 'win32'
  config:
    enableRunInBackground: false

# ── filesystem reads (plus the approved report-file write) ──────────────────

# `tool-fs` registers `read`, `read_image`, `write`, and `edit`. Under the
# deployment's read-only sandbox the host denies `write`/`edit` unless the
# user approves that exact call (the report-file exception).
- id: tool-fs
  name: '@deepseek-ai/dsh-tool-fs'

- id: tool-fs-search
  name: '@deepseek-ai/dsh-tool-fs-search'
  config:
    sampleOverCapGlobResults: false

# `view` is allowed read-only; `create`/`str_replace`/`insert` are denied by
# the read-only sandbox like `write`/`edit`.
- id: tool-str-replace-editor
  name: '@deepseek-ai/dsh-tool-str-replace-editor'
  config:
    maxOutputChars: 16000

# ── questions and web reads ─────────────────────────────────────────────────

- id: tool-ask-user
  name: '@deepseek-ai/dsh-tool-ask-user'

# Web search is read-only from the filesystem's point of view and is enabled
# for dependency-advisory and supply-chain research. `web_fetch` stays off
# here; a deployment with a configured fetch provider may enable it.
- id: tool-web
  name: '@deepseek-ai/dsh-tool-web'
  config:
    search: true
    fetch: false
    searchTimeoutMs: 60000
'@

function Write-Utf8NoBom {
  param(
    [string]$Path,
    [string]$Content
  )
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

Write-Host "DSH_HOME:   $DSH_HOME"
Write-Host "Target dir: $TargetDir"

if ($Check) {
  $installed = Test-Path (Join-Path $TargetDir 'agent.cordis.yml')
  if ($installed) {
    Write-Host 'status: already installed (use -Force to overwrite)'
    Get-ChildItem -Force $TargetDir | Format-Table -AutoSize
  } else {
    Write-Host 'status: not installed'
  }
  exit 0
}

if (Test-Path (Join-Path $TargetDir 'agent.cordis.yml')) {
  if (-not $Force) {
    Write-Error "$TargetDir already exists (use -Force to overwrite)"
    exit 1
  }
  $backup = "$TargetDir.bak-$(Get-Date -Format 'yyyyMMddHHmmss')"
  Move-Item -Path $TargetDir -Destination $backup
  Write-Host "backed up existing install to $backup"
}

New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
Write-Utf8NoBom -Path (Join-Path $TargetDir 'preset.yml') -Content $PresetYml
Write-Utf8NoBom -Path (Join-Path $TargetDir 'agent.cordis.yml') -Content $AgentCordisYml

Write-Host 'installed:'
Get-ChildItem -Force $TargetDir | Format-Table -AutoSize

Write-Host @'

Next steps (on the target instance):
  1. Make sure the deployment sandbox default is read-only (host
     sandbox-policy config), or switch the session to read-only;
  2. Start a new session and pick "只读安全审计", confirm the tool list:
     bash / pwsh(Windows) / read / read_image / glob / grep /
     str_replace_editor(view) / ask_user_question / web_search;
  3. Or validate through the roster: standingKeyFor('readonly-audit').
'@
