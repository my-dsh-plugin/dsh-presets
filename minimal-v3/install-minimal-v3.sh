#!/usr/bin/env bash
# install-minimal-v3.sh — 极简V3 agent preset 安装码（自包含，可远程调用）
#
# 把「极简V3」用户预设（agent.cordis.yml + preset.yml）安装到本机 DSH 的
# 用户预设根。安装后目标实例的 roster 即可发现该预设，无需注册或重启。
# 脚本内容完全内嵌，不依赖仓库里的其他文件，因此可以直接从远端管道执行。
#
# 用法：
#   bash install-minimal-v3.sh            安装到 ${DSH_HOME:-$HOME/.dsh}/.agent-presets/minimal-v3
#   bash install-minimal-v3.sh --force    覆盖已存在的安装（先备份到 .bak-<时间戳>）
#   bash install-minimal-v3.sh --check    仅打印目标路径和现状，不写入
#
# 远程安装（把本文件放进任意开源仓库后，一行命令）：
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/<owner>/<repo>/<branch>/install-minimal-v3.sh)"
#   # 或
#   curl -fsSL https://raw.githubusercontent.com/<owner>/<repo>/<branch>/install-minimal-v3.sh | bash
#
# 注意：
#   * 目标实例的 DSH 版本必须带本预设引用的 @deepseek-ai/dsh-* 包
#     （dsh-tool-fs / dsh-tool-fs-search / dsh-tool-pwsh / dsh-fs-local /
#     dsh-terminal / dsh-tool-bash-persistent / dsh-persona 等，均随部署提供）；
#   * 安装后请在目标实例新建会话选择「极简V3」确认工具清单，
#     或通过 roster 的 standingKeyFor('minimal-v3') 做挂载校验。

set -euo pipefail

DSH_HOME="${DSH_HOME:-$HOME/.dsh}"
TARGET_DIR="$DSH_HOME/.agent-presets/minimal-v3"

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
name: 极简V3
description: 极简模式扩展：持久 bash、str_replace_editor、read/write/edit、glob/grep 与 pwsh（Windows）的编码 Agent。
PRESET_YML_EOF

cat > "$TARGET_DIR/agent.cordis.yml" <<'AGENT_CORDIS_YML_EOF'
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
AGENT_CORDIS_YML_EOF

echo "installed:"
ls -la "$TARGET_DIR"

cat <<'DONE'

下一步（在目标实例上）：
  1. 新建会话并选择「极简V3」，确认工具清单：
     bash / str_replace_editor / read / write / edit / glob / grep
     （Windows 目标机还会出现 pwsh）
  2. 或通过 roster 校验：standingKeyFor('minimal-v3')
  3. 若校验失败，先对比目标实例 shipped minimal 的版本，
     把三行新增移植到目标机自己的 minimal 副本上再试。
DONE
