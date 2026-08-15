#!/usr/bin/env bash
# install-anchored-minimal.sh - self-contained installer (regenerated: Windows bash->pwsh bootstrap substitution)
#
# Installs the anchored-minimal user preset (preset.yml + agent.cordis.yml + bootstrap.mjs)
# into the DSH user preset root. The roster discovers it immediately.
#
# Usage:
#   bash install-anchored-minimal.sh             install to ${DSH_HOME:-$HOME/.dsh}/.agent-presets/anchored-minimal
#   bash install-anchored-minimal.sh --force     overwrite existing install (backs up first)
#   bash install-anchored-minimal.sh --check     print target path and status, write nothing
#
# Remote install:
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/<owner>/<repo>/<branch>/anchored-minimal/install-anchored-minimal.sh)"

set -euo pipefail

DSH_HOME="${DSH_HOME:-$HOME/.dsh}"
TARGET_DIR="$DSH_HOME/.agent-presets/anchored-minimal"

FORCE=0
CHECK=0
for arg in "$@"; do
  case "$arg" in
    --force) FORCE=1 ;;
    --check) CHECK=1 ;;
    *) echo "unknown argument: $arg" >&2; exit 2 ;;
  esac
done

echo "DSH_HOME:   $DSH_HOME"
echo "Target dir: $TARGET_DIR"

if [ "$CHECK" -eq 1 ]; then
  if [ -e "$TARGET_DIR/agent.cordis.yml" ]; then
    echo "status: already installed (use --force to overwrite)"
    ls -la "$TARGET_DIR"
  else
    echo "status: not installed"
  fi
  exit 0
fi

if [ -e "$TARGET_DIR/agent.cordis.yml" ]; then
  if [ "$FORCE" -ne 1 ]; then
    echo "error: $TARGET_DIR already exists (use --force to overwrite)" >&2
    exit 1
  fi
  BACKUP="$TARGET_DIR.bak-$(date +%Y%m%d%H%M%S)"
  mv "$TARGET_DIR" "$BACKUP"
  echo "backed up existing install to $BACKUP"
fi

mkdir -p "$TARGET_DIR"
umask 077

cat > "$TARGET_DIR/preset.yml" <<'PRESET_YML_EOF'
name: 锚定极简
description: 极简模式扩展：持久 bash、str_replace_editor、read/write/edit、glob/grep 与 pwsh（Windows）的编码 Agent。
PRESET_YML_EOF

cat > "$TARGET_DIR/agent.cordis.yml" <<'AGENT_CORDIS_YML_EOF'
# The `anchored-minimal` agent preset: minimal plus the common coding tools.
#
# This preset is copied from `minimal`: the persona is the complete system
# prompt, runtime context snapshots are suppressed, and context compaction is
# absent. On top of persistent `bash` and `str_replace_editor` it adds the
# common tool suite: `pwsh` (the Windows substitute for bash, disabled on
# non-Windows), `read`/`write`/`edit` from `tool-fs`, and `glob`/`grep` from
# `tool-fs-search`. `tool-fs` shares the bare local filesystem realm with
# `str_replace_editor`, so both operate on the same un-sandboxed local fs.
#
# V4-PRO ANCHORING: DeepSeek V4 Pro conditions strongly on the API-visible
# first-request tool catalog. Community Project2 evidence (xiaobright/modeltest,
# MIT) measured Minimal at 99/96 vs Standard at 91/92, and the first-request
# tool schema is the decisive variable. This preset therefore bootstraps the
# FIRST model request on the official Minimal pair (`bash` +
# `str_replace_editor`) via `bootstrap.mjs` (row must stay FIRST), then exposes
# the full anchored-minimal catalog after the first durable `tool/call` or
# `assistant/message`. The persona stays byte-identical to Minimal for the
# whole session.

# ── bootstrap (must stay FIRST) ─────────────────────────────────────────────
#
# This plugin publishes nothing: it only listens to the `system-prompt/assemble`
# and `agent/pre-step` waterfalls, so it needs no realm and no inject list.
# Being first in the file (and registering `prepend`) makes its filters the
# outermost transforms, which is what lets it strip the bootstrap-phase
# catalog and injected context even when later rows inject both.
- id: tool-bootstrap
  name: ./bootstrap.mjs
  config:
    bootstrapTools: [bash, str_replace_editor]
    suppressedContextSources: [skill-catalog, agent-instructions]

- id: persona
  name: '@deepseek-ai/dsh-persona'
  config:
    text: You are a helpful software engineer assistant.
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
AGENT_CORDIS_YML_EOF

cat > "$TARGET_DIR/bootstrap.mjs" <<'BOOTSTRAP_MJS_EOF'
/**
 * anchored-minimal anchored tool bootstrap
 *
 * Keeps the FIRST model request on the official Minimal preset's REAL tool
 * pair (persistent `bash` + `str_replace_editor`) so DeepSeek V4 Pro anchors
 * on the Minimal trajectory (community Project2 evidence: Minimal 99/96 vs
 * Standard 91/92; the API-visible first-request tool catalog is the decisive
 * variable, 5/5 anchored with the Minimal pair vs 11/11 standard-like with
 * any standard-family schema). After the first durable promotion signal — a
 * `tool/call` OR the first `assistant/message`, whichever comes first — the
 * full anchored-minimal catalog is exposed and stays exposed.
 *
 * The phase is derived from durable session events, so resume and reload
 * preserve it. The persona (`complete: true`) is untouched and stays
 * byte-identical to the official Minimal preset; this plugin only narrows
 * the tool catalog and strips auto-injected context during bootstrap.
 *
 * ⚠️ KNOWN CONFLICT — mid-session preset switching:
 * The anchoring assumption is that a session STARTS on this preset. If the
 * session is recomposed onto this preset MID-CONVERSATION (for example via
 * an agent-mode switcher riding `agentPreset.select`, which re-links the
 * agent to another preset's standing composition while the session keeps its
 * history), the durable history already contains `tool/call` /
 * `assistant/message` events, so this plugin immediately treats the session
 * as promoted and the bootstrap phase is skipped. The model then sees the
 * full tool catalog with the Minimal persona but WITHOUT the Minimal-grounded
 * first-request trajectory — exactly the unanchored condition the bootstrap
 * exists to prevent, and model capability may degrade as a result. Switching
 * AWAY from this preset mid-session is equally unsupported: the anchored
 * trajectory is abandoned for whatever the target preset conditions.
 *
 * Recommendation: pick this preset when CREATING a session and keep it for
 * the session's lifetime. Do not switch into or out of it mid-conversation.
 *
 * Based on the MIT-licensed design of xiaobright/dsh-anchored-standard
 * (first-request tool-schema anchoring), simplified for anchored-minimal: no
 * discovery-tool resident set, no compaction epoch — promotion is one-way
 * and permanent per session.
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
export const name = 'anchored-minimal-tool-bootstrap'

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
 * The default first-request catalog: the OFFICIAL Minimal preset's exact tool
 * pair — the persistent `bash` shell and `str_replace_editor`.
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
BOOTSTRAP_MJS_EOF

echo "installed:"
ls -la "$TARGET_DIR"

cat <<'DONE'

Next steps (on the target instance):
  1. Start a NEW session and pick the preset;
  2. First request sees the bootstrap pair (bash + str_replace_editor;
     pwsh + str_replace_editor on Windows);
  3. Keep the session on this preset - mid-session switching breaks the anchor.
DONE
