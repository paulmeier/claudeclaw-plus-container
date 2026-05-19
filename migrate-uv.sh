#!/bin/bash
# Reinstall UV tool installations after a Python version bump.
# UV tools run in isolated virtual environments keyed to a specific Python interpreter
# path. If the system Python minor version changes (e.g. 3.11 → 3.12), those venvs
# become invalid. Reinstalling recreates each venv under the current Python.
# Run inside a running container after a base image update:
#
#   docker compose exec claudeclaw /migrate-uv.sh
set -euo pipefail

TOOL_DIR="${UV_TOOL_DIR:-/root/.claude/uv-tools}"
TOOL_BIN_DIR="${UV_TOOL_BIN_DIR:-/root/.claude/uv-tool-bin}"
CACHE_DIR="${UV_CACHE_DIR:-/root/.claude/uv-cache}"
export UV_TOOL_DIR="$TOOL_DIR"
export UV_TOOL_BIN_DIR="$TOOL_BIN_DIR"
export UV_CACHE_DIR="$CACHE_DIR"

echo "[migrate-uv] UV_TOOL_DIR: ${TOOL_DIR}"

if [ ! -d "${TOOL_DIR}" ]; then
    echo "[migrate-uv] ${TOOL_DIR} not found — nothing to migrate."
    exit 0
fi

tools=()
for tool_dir in "${TOOL_DIR}"/*/; do
    [ -d "$tool_dir" ] || continue
    tool_name=$(basename "$tool_dir")

    # Read name + version specifier from UV's receipt file if present.
    # Falls back to the directory name (latest version) when receipt is missing.
    receipt="${tool_dir}uv-receipt.json"
    pkg="$tool_name"
    if [ -f "$receipt" ]; then
        name=$(jq -r '.tool.requirements[0].name // ""' "$receipt" 2>/dev/null)
        specifier=$(jq -r '.tool.requirements[0].specifier // ""' "$receipt" 2>/dev/null)
        [ -n "$name" ] && pkg="${name}${specifier}"
    fi

    tools+=("$pkg")
done

if [ ${#tools[@]} -eq 0 ]; then
    echo "[migrate-uv] No UV tool installations found — nothing to migrate."
    exit 0
fi

echo "[migrate-uv] ${#tools[@]} tool(s) to reinstall:"
printf '[migrate-uv]   %s\n' "${tools[@]}"
echo "[migrate-uv] Reinstalling ..."

for pkg in "${tools[@]}"; do
    uv tool install --reinstall "$pkg"
done

echo
echo "[migrate-uv] Done."
echo "[migrate-uv] If uvx environments are also broken, clear the cache:"
echo "[migrate-uv]   uv cache clean"
