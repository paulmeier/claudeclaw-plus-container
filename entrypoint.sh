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

# ClaudeClaw+ resolves its data directory (.claude/claudeclaw/) from CWD,
# so run from /root so data lands in the volume-mounted /root/.claude/
cd /root

# Create the directories that the persistence env vars point at. The env vars
# themselves are declared as Dockerfile ENV (so `docker exec` shells inherit
# them too); only the directory creation has to happen here because the volume
# is mounted at runtime — it doesn't exist at image-build time.
#
# What each dir is for:
#   tmp/           — TMPDIR, same filesystem as the volume so plugin installs
#                    can rename() temp files into /root/.claude/ without EXDEV
#   npm-global/    — npm `-g` install prefix (NPM_CONFIG_PREFIX), with bin/ on PATH
#   npm-cache/    — npm + npx download cache (NPM_CONFIG_CACHE)
#   python-user/  — pip user-base (PYTHONUSERBASE) + bin/ on PATH; PIP_USER=1
#                    + PIP_BREAK_SYSTEM_PACKAGES=1 bypass Debian's PEP 668 mark
#   pip-cache/    — pip download cache (PIP_CACHE_DIR)
#   pnpm-global/  — PNPM_HOME (pnpm store + manifest + bin/ all under here)
#   uv-tools/     — UV_TOOL_DIR (one isolated venv per `uv tool install`-ed pkg)
#   uv-tool-bin/  — UV_TOOL_BIN_DIR (shim scripts on PATH)
#   uv-cache/     — UV_CACHE_DIR (shared by `uv tool` and `uvx`)
#   uv-python/    — UV_PYTHON_INSTALL_DIR (Pythons downloaded via `uv python install`)
mkdir -p /root/.claude/tmp \
         /root/.claude/npm-global/bin /root/.claude/npm-cache \
         /root/.claude/python-user/bin /root/.claude/pip-cache \
         /root/.claude/pnpm-global \
         /root/.claude/uv-tools /root/.claude/uv-tool-bin \
         /root/.claude/uv-cache /root/.claude/uv-python

# Run startup diagnostics: print runtime versions, package inventories, and any
# migration warnings. Always exits 0 — warnings are advisory.
/healthcheck.sh || true

exec bun run /app/src/index.ts "$@"
