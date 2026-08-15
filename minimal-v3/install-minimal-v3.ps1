# install-minimal-v3.ps1 - 极简V3 agent preset install script (PowerShell)
#
# Installs the "极简V3" user preset (agent.cordis.yml + preset.yml) into this
# machine's DSH user preset root. Once installed, the target instance's roster
# discovers the preset immediately - no registration or restart needed.
# The script is fully self-contained (content embedded), so it can be piped
# from a remote URL.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File install-minimal-v3.ps1
#   powershell -ExecutionPolicy Bypass -File install-minimal-v3.ps1 -Force   # overwrite existing install (backs up first)
#   powershell -ExecutionPolicy Bypass -File install-minimal-v3.ps1 -Check   # print target path and status, write nothing
#
# Remote install (after hosting this file in any open-source repo):
#   irm https://raw.githubusercontent.com/<owner>/<repo>/<branch>/install-minimal-v3.ps1 | iex
#   # or, to bypass the execution policy explicitly:
#   powershell -ExecutionPolicy Bypass -c "irm https://raw.githubusercontent.com/<owner>/<repo>/<branch>/install-minimal-v3.ps1 | iex"
#
# Notes:
#   * The target instance's DSH version must ship the @deepseek-ai/dsh-* packages
#     referenced by this preset (dsh-tool-fs / dsh-tool-fs-search / dsh-tool-pwsh /
#     dsh-fs-local / dsh-terminal / dsh-tool-bash-persistent / dsh-persona).
#   * After install, start a new session and pick "极简V3" to confirm the tool
#     list, or validate through the roster's standingKeyFor('minimal-v3').
#   * On Windows the preset also exposes the `pwsh` tool (the bash substitute);
#     it is disabled automatically on non-Windows platforms.

[CmdletBinding()]
param(
  [switch]$Force,
  [switch]$Check
)

$ErrorActionPreference = 'Stop'

$DSH_HOME = if ($env:DSH_HOME) { $env:DSH_HOME } else { Join-Path $HOME '.dsh' }
$PresetRoot = Join-Path $DSH_HOME '.agent-presets'
$TargetDir = Join-Path $PresetRoot 'minimal-v3'

$PresetYml = @'
name: 极简V3
description: 极简模式扩展：持久 bash、str_replace_editor、read/write/edit、glob/grep 与 pwsh（Windows）的编码 Agent。
'@

$AgentCordisYml = @'
# The `minimal-v3` agent preset: minimal plus the common coding tools.
#
# This preset is copied from `minimal`: the persona is the complete system
# prompt, runtime context snapshots are suppressed, and context compaction is
# absent. On top of persistent `bash` and `str_replace_editor` it adds the
# common tool suite: `pwsh` (the Windows substitute for bash, disabled on
# non-Windows), `read`/`write`/`edit` from `tool-fs`, and `glob`/`grep` from
# `tool-fs-search`. `tool-fs` shares the bare local filesystem realm with
# `str_replace_editor`, so both operate on the same un-sandboxed local fs.

- id: persona
  name: '@deepseek-ai/dsh-persona'
  config:
    text: You are a helpful software engineer assistant.
    complete: true
    includeRuntimeContext: false

# The PTY registry is an agent-owned service, so it lives in an entry-local
# realm. The backend still consumes the host sandbox policy and subprocess
# implementation, while the tool registers into this agent's scoped catalog.
- id: persistent-shell
  name: cordis:group
  group: true
  isolate:
    terminals: true
  config:
    - id: pty
      name: '@deepseek-ai/dsh-terminal'

    - id: terminal-bash
      name: '@deepseek-ai/dsh-terminal-bash'
      config:
        timeoutMs: 300000

    - id: persistent-bash
      name: '@deepseek-ai/dsh-tool-bash-persistent'
      config:
        timeoutMs: 300000
        description: |-
          Run commands in a bash shell
          * When invoking this tool, the contents of the "command" parameter does NOT need to be XML-escaped.
          * You don't have access to the internet via this tool.
          * You do have access to a mirror of common linux and python packages via apt and pip.
          * State is persistent across command calls and discussions with the user.
          * To inspect a particular line range of a file, e.g. lines 10-25, try 'sed -n 10,25p /path/to/the/file'.
          * Please avoid commands that may produce a very large amount of output.
          * Please run long lived commands in the background, e.g. 'sleep 10 &' or start a server in the background.

# The bare local filesystem shadows the host's sandboxed provider only for this
# preset. `tool-fs` (read/write/edit) sits inside the same realm so it shares
# this exact filesystem with `str_replace_editor`; both require absolute paths.
- id: filesystem
  name: cordis:group
  group: true
  isolate:
    fs: true
  config:
    - id: fs-local
      name: '@deepseek-ai/dsh-fs-local'
      config:
        cwd: !!js process.env.DSH_CWD ?? process.cwd()

    - id: tool-fs
      name: '@deepseek-ai/dsh-tool-fs'

    - id: str-replace-editor
      name: '@deepseek-ai/dsh-tool-str-replace-editor'
      config:
        maxOutputChars: 16000

# `glob`/`grep` register into the host `tools` registry and provide nothing,
# so they need no realm; they resolve the host `subprocess` seam for ripgrep.
- id: tool-fs-search
  name: '@deepseek-ai/dsh-tool-fs-search'
  config:
    sampleOverCapGlobResults: false

# `pwsh` mirrors `tool-bash` on Windows: it consumes the host `shell` registry
# and is disabled on non-Windows platforms.
- id: tool-pwsh
  name: '@deepseek-ai/dsh-tool-pwsh'
  disabled: !!js process.platform !== 'win32'
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
  1. Start a new session and pick "极简V3", confirm the tool list:
     bash / str_replace_editor / read / write / edit / glob / grep
     (Windows targets additionally get pwsh)
  2. Or validate through the roster: standingKeyFor('minimal-v3')
  3. If validation fails, compare the target instance's shipped minimal
     version first, then port the three added rows onto the target's own
     minimal copy and retry.
'@
