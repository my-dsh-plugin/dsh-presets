# install-flash-boost.ps1 - self-contained installer (regenerated: Windows bash->pwsh bootstrap substitution)
#
# Installs the flash-boost user preset (preset.yml + agent.cordis.yml + bootstrap.mjs)
# into the DSH user preset root. The roster discovers it immediately.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File install-flash-boost.ps1
#   powershell -ExecutionPolicy Bypass -File install-flash-boost.ps1 -Force
#   powershell -ExecutionPolicy Bypass -File install-flash-boost.ps1 -Check
#
# Remote install:
#   irm https://raw.githubusercontent.com/<owner>/<repo>/<branch>/flash-boost/install-flash-boost.ps1 | iex

[CmdletBinding()]
param(
  [switch]$Force,
  [switch]$Check
)

$ErrorActionPreference = 'Stop'

$DSH_HOME = if ($env:DSH_HOME) { $env:DSH_HOME } else { Join-Path $HOME '.dsh' }
$PresetRoot = Join-Path $DSH_HOME '.agent-presets'
$TargetDir = Join-Path $PresetRoot 'flash-boost'

$PresetYml = @'
name: Flash增强
description: Flash 专用模式：中性 persona + 分类执行指令 + 防跑题锚（实测最优）；首轮 RL 形状工具对、之后完整工具集。
'@

$AgentCordisYml = @'
# The `flash-boost` agent preset: a Flash-optimized mode with manual selection.
#
# WHY MANUAL SELECTION: automatic task routing (the router-standard approach)
# classifies the first user message into spec/react at runtime — a black box
# that can misclassify and adds complexity. Manual mode selection puts the
# routing decision with the person who actually knows the task: pick this
# preset when the session is for Flash, keep anchored-minimal/standard for Pro.
#
# FLASH-TUNED PERSONA (community-measured): DeepSeek V4 Flash's trajectory
# follows the system persona, not the tool catalog (modeltest: Flash stays
# minimal-like even with the full 25-tool catalog). The optimal weak persona
# is NOT the Minimal one-liner — the spec sentence ANTI-routes on Flash
# (router-standard P11). Measured optimum (P11/P23): neutral identity +
# classify-then-act instruction + recall/anti-runaway anchors. The anchors
# lifted open-task completion from 0% to 100% (P23).
#
# RL-SHAPE TOOL BOOTSTRAP: on Flash the first-turn tool surface decides
# whether the model acts or just reasons. Measured: shell + str_replace_editor
# (the RL training shape) → 100% tool calls at 18–29K reasoning chars; the
# read/write/edit surface → ~25% action / 73–101K reasoning. `bootstrap.mjs`
# keeps the first request on that RL pair, then exposes the full catalog after
# the first durable tool call or assistant message.

# ── bootstrap (must stay FIRST) ─────────────────────────────────────────────
#
# This plugin publishes nothing: it only listens to the `system-prompt/assemble`
# and `agent/pre-step` waterfalls, so it needs no realm and no inject list.
- id: tool-bootstrap
  name: ./bootstrap.mjs
  config:
    bootstrapTools: [bash, str_replace_editor]
    suppressedContextSources: [skill-catalog, agent-instructions]

# ── identity ────────────────────────────────────────────────────────────────
#
# The Flash-optimized persona: neutral identity (NOT the Minimal spec sentence,
# which anti-routes on Flash), classify-then-act, and the recall/anti-runaway
# anchors. Kept as the complete system prompt (complete: true) so no identity,
# web-orientation, or tool-guidance section can dilute it.
- id: persona
  name: '@deepseek-ai/dsh-persona'
  config:
    text: >-
      You are a helpful assistant.
      Before acting, decide the task type (build or fix) and adopt the matching
      style: build → hands-on production; fix → inspect-and-plan.
      Before acting, briefly review what you have already done in this session and
      continue from where you left off; do not repeat completed steps.
      Do not run environment checks (echo, whoami, uname, node --version, date) or
      exhaustive grep/glob scans.
      Think deeply first, then produce.
    complete: true
    includeRuntimeContext: false

# The PTY registry is an agent-owned service, so it lives in an entry-local
# realm. The backend still consumes the host sandbox policy and subprocess
# implementation, while the tool registers into this agent's scoped catalog.
# DISABLED ON WINDOWS: the PTY backend and /bin/bash default are
# linux/darwin-only; on Windows the `tool-pwsh` row provides the shell and the
# bootstrap pair substitutes `pwsh` for `bash` (see bootstrap.mjs).
- id: persistent-shell
  name: cordis:group
  group: true
  disabled: !!js process.platform === 'win32'
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

$BootstrapMjs = @'
/**
 * flash-boost RL-shape tool bootstrap
 *
 * Keeps the FIRST model request on the RL-shape tool pair (persistent `bash` +
 * `str_replace_editor`) so DeepSeek V4 Flash ACTS instead of only reasoning.
 * Community measurement (router-standard v0.2.0, official API, 2026-08-15):
 * on Flash the first-turn tool surface decides action vs reasoning — shell +
 * str_replace_editor → 100% tool calls at 18–29K reasoning chars; the
 * read/write/edit surface → ~25% action / 73–101K reasoning. After the first
 * durable promotion signal — a `tool/call` OR the first `assistant/message`,
 * whichever comes first — the full flash-boost catalog is exposed and stays
 * exposed.
 *
 * The phase is derived from durable session events, so resume and reload
 * preserve it. The persona (`complete: true`) is untouched; this plugin only
 * narrows the tool catalog and strips auto-injected context during bootstrap.
 *
 * Note on the difference from anchored-minimal: that preset anchors on the
 * Minimal tool pair because V4 Pro's trajectory follows the API-visible
 * first-request catalog; Flash's trajectory follows the PERSONA instead
 * (modeltest: Flash stays minimal-like even with the full 25-tool catalog).
 * flash-boost keeps the RL-shape bootstrap purely for the action/reasoning
 * trade-off — the persona carries the Flash-specific conditioning.
 *
 * ⚠️ KNOWN CONFLICT — mid-session preset switching:
 * The bootstrap assumption is that a session STARTS on this preset. If the
 * session is recomposed onto this preset MID-CONVERSATION (for example via
 * an agent-mode switcher riding `agentPreset.select`), the durable history
 * already contains `tool/call` / `assistant/message` events, so this plugin
 * immediately treats the session as promoted and the bootstrap phase is
 * skipped. Switching AWAY mid-session is equally unsupported.
 *
 * Recommendation: pick this preset when CREATING a session and keep it for
 * the session's lifetime. Do not switch into or out of it mid-conversation.
 *
 * Based on the MIT-licensed design of xiaobright/dsh-anchored-standard
 * (first-request tool-schema anchoring), simplified for flash-boost: one-way
 * promotion, no discovery-tool resident set, no compaction epoch.
 *
 * Robustness:
 *  - Promotion decisions are memoized per session id for this process; the
 *    durable event scan runs once per session per process, then O(1).
 *  - Subagents (delegationDepth > 0) are always promoted (full catalog).
 *  - A missing bootstrap tool degrades to the full catalog with a one-time
 *    warning instead of throwing, so composition drift can never brick a
 *    session.
 *  - The pre-step context filter degrades to "keep everything" on failure:
 *    a filter bug must never eat the user's context.
 *  - Invalid config fails at apply time (preset mount), where it is visible
 *    and fixable.
 */

/** Cordis plugin name used by loader diagnostics. */
export const name = 'flash-boost-tool-bootstrap'

/**
 * Deliberately NO inject list: the listeners only touch services at event
 * time. Applying without an inject — combined with this row being FIRST in
 * agent.cordis.yml — registers the plugin before any context-injecting row,
 * and waterfall after-next transforms apply in reverse registration order, so
 * the first-request strip below is the LAST transform. The pre-step listener
 * additionally registers with `prepend: true` so the strip stays the outermost
 * transform even against host-plane listeners and future row reordering.
 */
export const inject = []

/** Durable session event types that count as a promotion signal. */
const PROMOTE_EVENTS = new Set(['tool/call', 'assistant/message'])

/** Every config key this plugin accepts — anything else is a typo. */
const ALLOWED_KEYS = new Set(['bootstrapTools', 'suppressedContextSources'])

/**
 * Context sources stripped from the first request by default. Both are
 * automatic `agent/pre-step` injections: the available-skills reminder
 * (`skill-catalog`) and the AGENTS.md/CLAUDE.md workspace digest
 * (`agent-instructions`). True Minimal mounts neither plugin.
 */
const DEFAULT_SUPPRESSED_SOURCES = ['skill-catalog', 'agent-instructions']

/**
 * The default first-request catalog: the RL-shape tool pair — the persistent
 * `bash` shell and `str_replace_editor` (measured 100% action at 18–29K
 * reasoning chars on Flash, vs ~25% action on the read/write/edit surface).
 */
const DEFAULT_BOOTSTRAP_TOOLS = ['bash', 'str_replace_editor']

function stringList(value, field) {
  if (!Array.isArray(value) || value.length === 0 || value.some((item) => typeof item !== 'string' || item.length === 0)) {
    throw new TypeError(`${name}: ${field} must be a non-empty array of non-empty strings`)
  }
  return [...new Set(value)]
}

function sourceList(value, field, fallback) {
  if (value === undefined) return new Set(fallback)
  if (!Array.isArray(value) || value.some((item) => typeof item !== 'string' || item.length === 0)) {
    throw new TypeError(`${name}: ${field} must be an array of non-empty strings`)
  }
  return new Set(value)
}

/** Register the per-session bootstrap filter. */
export function apply(ctx, config) {
  const source = config === undefined ? {} : config
  if (typeof source !== 'object' || source === null || Array.isArray(source)) {
    throw new TypeError(`${name}: config must be an object`)
  }
  const unknown = Object.keys(source).filter((key) => !ALLOWED_KEYS.has(key))
  if (unknown.length > 0) {
    throw new TypeError(`${name}: unknown config key(s) ${unknown.join(', ')} — allowed keys: ${[...ALLOWED_KEYS].sort().join(', ')}`)
  }
  const bootstrapTools = stringList(source.bootstrapTools, 'bootstrapTools')
  const suppressedSources = sourceList(source.suppressedContextSources, 'suppressedContextSources', DEFAULT_SUPPRESSED_SOURCES)

  /**
   * Platform-adapted bootstrap pair. On Windows the PTY-backed persistent bash
   * is unavailable (linux/darwin-only), so `bash` in the configured pair is
   * substituted with `pwsh` — the Windows shell this preset mounts. The
   * bootstrap pair therefore stays valid on every platform.
   */
  if (typeof process !== 'undefined' && process.platform === 'win32') {
    for (let index = 0; index < bootstrapTools.length; index += 1) {
      if (bootstrapTools[index] === 'bash') bootstrapTools[index] = 'pwsh'
    }
  }

  /**
   * Per-session promotion state, memoized per process. `0` = unpromoted,
   * `1` = promoted. Derived from durable session events so resume/reload
   * preserve the phase without catch-up machinery.
   */
  const promotedFor = new Map()
  const isPromoted = (session) => {
    if (session === undefined) return true
    const cached = promotedFor.get(session.id)
    if (cached !== undefined) return cached
    let promoted = false
    if (Array.isArray(session.events)) {
      for (const event of session.events) {
        if (PROMOTE_EVENTS.has(event.type)) {
          promoted = true
          break
        }
      }
    }
    promotedFor.set(session.id, promoted)
    return promoted
  }

  let warned = false
  const warnOnce = (message) => {
    if (warned) return
    warned = true
    try {
      ctx.logger.warn(message)
    } catch {
      // Logger unavailable — the guard exists only to avoid spamming.
    }
  }

  /**
   * Narrow the assembled catalog to the bootstrap pair. When a bootstrap tool
   * is missing from the assembled catalog, degrade to the full catalog with a
   * one-time warning instead of throwing.
   */
  const keepBootstrapTools = (assembled) => {
    const available = new Set(assembled.tools.map((tool) => tool.name))
    const missing = bootstrapTools.filter((toolName) => !available.has(toolName))
    if (missing.length > 0) {
      warnOnce(
        `${name}: expected bootstrap tools ${JSON.stringify(missing)} are missing from the assembled catalog — `
        + 'bootstrap disabled, full catalog exposed',
      )
      return assembled
    }
    return {
      ...assembled,
      tools: assembled.tools.filter((tool) => bootstrapTools.includes(tool.name)),
    }
  }

  ctx.on('system-prompt/assemble', async (_assembly, context, next) => {
    // Downstream errors propagate untouched; only this filter's own logic is guarded.
    const assembled = await next()
    try {
      if (isPromoted(context.agent?.session)) return assembled
      return keepBootstrapTools(assembled)
    } catch (error) {
      // A filter bug must never brick a session: degrade to the full catalog.
      warnOnce(`${name}: bootstrap filter failed, exposing the full catalog: ${String((error && error.message) || error)}`)
      return assembled
    }
  })

  // Strip first-step injected reminders (skill catalog, AGENTS.md) during
  // bootstrap. Because this listener is the first registered (see the inject
  // note, the row order in agent.cordis.yml, and `prepend` below), the strip
  // is the final waterfall transform and actually removes what later
  // listeners inject.
  ctx.on('agent/pre-step', async ({ agent }, next) => {
    // Downstream errors propagate untouched; only this filter's own logic is guarded.
    const decision = await next()
    if (decision.kind === 'reject') return decision
    try {
      if (isPromoted(agent?.session) || suppressedSources.size === 0) return decision
      if (!Array.isArray(decision.messages)) return decision
      const kept = decision.messages.filter((message) => {
        const kind = message?.source?.kind
        return typeof kind !== 'string' || !suppressedSources.has(kind)
      })
      return kept.length === decision.messages.length ? decision : { ...decision, messages: kept }
    } catch (error) {
      // A filter bug must never eat context: degrade to keeping every message.
      warnOnce(`${name}: pre-step context filter failed, keeping injected context: ${String((error && error.message) || error)}`)
      return decision
    }
  }, { prepend: true })
}
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
Write-Utf8NoBom -Path (Join-Path $TargetDir 'bootstrap.mjs') -Content $BootstrapMjs

Write-Host 'installed:'
Get-ChildItem -Force $TargetDir | Format-Table -AutoSize

Write-Host @'

Next steps (on the target instance):
  1. Start a NEW session and pick the preset;
  2. First request sees the bootstrap pair (bash + str_replace_editor;
     pwsh + str_replace_editor on Windows);
  3. Keep the session on this preset - mid-session switching breaks the anchor.
'@
