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

# Claude Code's x86_64 binary and the Bun runtime both need AVX2 (Intel Haswell /
# AMD Excavator or newer). On older CPUs they die with SIGILL (exit 132) and the
# container restart-loops with no explanation (issue claudeclaw-container-unraid#17),
# so probe both up front and say why. Probing the binaries rather than reading
# /proc/cpuinfo avoids false alarms under emulation, where the flags can be missing.
for bin in claude bun; do
    rc=0
    "${bin}" --version >/dev/null 2>&1 || rc=$?
    if [ "${rc}" -eq 132 ]; then
        echo "[claudeclaw] Error: '${bin}' crashed with an illegal instruction (exit 132)."
        if [ "$(uname -m)" = "x86_64" ] && ! grep -qw avx2 /proc/cpuinfo; then
            echo "[claudeclaw] This CPU does not support AVX2, which Claude Code requires on x86_64."
            echo "[claudeclaw] It needs an Intel Haswell (2013) / AMD Excavator (2015) or newer CPU; there is no build for older CPUs."
        fi
        exit 1
    fi
done

# Run startup diagnostics: print runtime versions, package inventories, and any
# migration warnings. Always exits 0 — warnings are advisory.
/healthcheck.sh || true

# Drop the daemon PID file left by the previous run. The daemon is PID 1 here
# (exec below), so the file always says "1" — and PID 1 always exists in a
# fresh container, so upstream's liveness check reads a stale file as a live
# daemon and aborts, which `restart: unless-stopped` turns into a restart loop
# (issue claudeclaw-plus-container#44). No daemon from an earlier container can
# be alive in this PID namespace. Kept for the one-shot subcommands
# (`docker compose run --rm claudeclaw-plus status`), which share the volume with a
# running daemon and must not remove its file.
case "${1:-}" in
    --help|-h|help|--stop-all|--stop|--clear|status|telegram|discord|slack|send|fire|oneshot) ;;
    *) rm -f "${SETTINGS_DIR}/daemon.pid" ;;
esac

exec bun run /app/src/index.ts "$@"
