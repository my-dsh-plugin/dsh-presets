/**
 * minimal-v3 anchored tool bootstrap
 *
 * Keeps the FIRST model request on the official Minimal preset's REAL tool
 * pair (persistent `bash` + `str_replace_editor`) so DeepSeek V4 Pro anchors
 * on the Minimal trajectory (community Project2 evidence: Minimal 99/96 vs
 * Standard 91/92; the API-visible first-request tool catalog is the decisive
 * variable, 5/5 anchored with the Minimal pair vs 11/11 standard-like with
 * any standard-family schema). After the first durable promotion signal — a
 * `tool/call` OR the first `assistant/message`, whichever comes first — the
 * full minimal-v3 catalog is exposed and stays exposed.
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
 * (first-request tool-schema anchoring), simplified for minimal-v3: no
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
export const name = 'minimal-v3-tool-bootstrap'

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
