#!/bin/bash
set -e

SETTINGS_DIR="/root/.claude/claudeclaw"
SETTINGS_FILE="${SETTINGS_DIR}/settings.json"

# Bootstrap minimal settings on first run. ClaudeClaw+ inherits the upstream
# settings.json schema (it auto-syncs from moazbuilds/claudeclaw daily), so the
# same defaults apply.
if [ ! -f "${SETTINGS_FILE}" ]; then
    mkdir -p "${SETTINGS_DIR}"
    cat > "${SETTINGS_FILE}" << 'EOF'
{
  "model": "sonnet",
  "web": {
    "enabled": true,
    "host": "0.0.0.0",
    "port": 4632
  },
  "telegram": {
    "token": "",
    "allowedUserIds": [],
    "receiveEnabled": false
  },
  "discord": {
    "token": "",
    "allowedUserIds": [],
    "listenChannels": [],
    "listenGuilds": []
  },
  "slack": {
    "botToken": "",
    "appToken": "",
    "allowedUserIds": [],
    "listenChannels": []
  }
}
EOF
    echo "[claudeclaw-plus] Created default settings at ${SETTINGS_FILE}"
    echo "[claudeclaw-plus] Edit this file or mount your own before starting."
fi

# Ensure web.host is 0.0.0.0 so the dashboard is reachable from outside the container.
# A user-provided settings.json with host=127.0.0.1 would silently break the dashboard.
CURRENT_HOST=$(jq -r '.web.host // "127.0.0.1"' "${SETTINGS_FILE}")
if [ "${CURRENT_HOST}" = "127.0.0.1" ]; then
    tmp=$(mktemp)
    jq '.web.host = "0.0.0.0"' "${SETTINGS_FILE}" > "${tmp}" && mv "${tmp}" "${SETTINGS_FILE}"
    echo "[claudeclaw-plus] Patched web.host to 0.0.0.0 for container networking"
fi

# Claude Code refuses --dangerously-skip-permissions when running as root unless
# IS_SANDBOX=1 is set. ClaudeClaw+ uses that flag for its bypassPermissions mode,
# and this container runs as root, so without this env var every spawned `claude`
# call would exit immediately with no output (chat replies appear blank).
export IS_SANDBOX=1

# ClaudeClaw+ resolves its data directory (.claude/claudeclaw/) from CWD,
# so run from /root so data lands in the volume-mounted /root/.claude/
cd /root

# Keep TMPDIR on the same filesystem as the volume so the plugin installer can
# rename() temp files into /root/.claude/ without EXDEV errors.
mkdir -p /root/.claude/tmp
export TMPDIR=/root/.claude/tmp

# Persist npm global installs and npx cache inside the volume so packages
# added by Claude Code skills (or directly via `npm install -g` / `npx`)
# survive image updates and container recreation. Without this, anything
# installed lands in /usr/lib/node_modules or /root/.npm — both wiped on
# every image pull. NPM_CONFIG_* env vars take precedence over .npmrc, so
# this also works for users who happen to bind-mount their own .npmrc.
mkdir -p /root/.claude/npm-global/bin /root/.claude/npm-cache
export NPM_CONFIG_PREFIX=/root/.claude/npm-global
export NPM_CONFIG_CACHE=/root/.claude/npm-cache
export PATH=/root/.claude/npm-global/bin:$PATH

exec bun run /app/src/index.ts "$@"
