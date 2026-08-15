#!/usr/bin/env bash
# install-readonly-audit.sh - 只读安全审计 preset 安装码（自包含，可远程调用）
#
# 把「只读安全审计」用户预设（agent.cordis.yml + preset.yml）安装到本机 DSH
# 的用户预设根。安装后目标实例的 roster 即可发现该预设，无需注册或重启。
# 脚本内容完全内嵌，不依赖仓库里的其他文件，因此可以直接从远端管道执行。
#
# 纯预设版说明：本模式不依赖任何自定义插件。只读强制由部署的 read-only
# 沙箱承担（宿主 sandbox-policy 默认模式需为 read-only，或会话切换到
# read-only）；本预设只贡献只读工具集、审计 persona 与报告交付提示。
# 报告文件写入走宿主原生的逐次批准升级（read-only 下 write 被拒 ->
# sandbox_permissions + approval 单次批准）。
#
# 用法：
#   bash install-readonly-audit.sh            安装到 ${DSH_HOME:-$HOME/.dsh}/.agent-presets/readonly-audit
#   bash install-readonly-audit.sh --force    覆盖已存在的安装（先备份到 .bak-<时间戳>）
#   bash install-readonly-audit.sh --check    仅打印目标路径和现状，不写入
#
# 远程安装（把本文件放进任意开源仓库后，一行命令）：
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/<owner>/<repo>/<branch>/readonly-audit/install-readonly-audit.sh)"
#   # 或
#   curl -fsSL https://raw.githubusercontent.com/<owner>/<repo>/<branch>/readonly-audit/install-readonly-audit.sh | bash

set -euo pipefail

DSH_HOME="${DSH_HOME:-$HOME/.dsh}"
TARGET_DIR="$DSH_HOME/.agent-presets/readonly-audit"

# ---- argument parsing ----
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
name: 只读安全审计
description: 只读安全审计模式（纯预设版）：只读工具集 + 审计 persona；文件写入依赖部署的 read-only 沙箱与宿主逐次批准。
PRESET_YML_EOF

cat > "$TARGET_DIR/agent.cordis.yml" <<'AGENT_CORDIS_YML_EOF'
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
AGENT_CORDIS_YML_EOF

echo "installed:"
ls -la "$TARGET_DIR"

cat <<'DONE'

下一步（在目标实例上）：
  1. 确保部署 sandbox 默认模式为 read-only（宿主 sandbox-policy 配置），
     或在会话中切换到 read-only；
  2. 新建会话并选择「只读安全审计」，确认工具清单：
     bash / pwsh(Windows) / read / read_image / glob / grep /
     str_replace_editor(view) / ask_user_question / web_search；
  3. 或通过 roster 校验：standingKeyFor('readonly-audit')。
DONE
