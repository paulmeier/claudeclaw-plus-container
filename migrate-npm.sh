#!/bin/bash
# Reinstall npm global packages after a Node major version bump.
# Native addons compiled for the old ABI won't load under a new Node major version;
# reinstalling forces npm to recompile them for the current runtime.
# Run inside a running container after a base image update:
#
#   docker compose exec claudeclaw /migrate-npm.sh
set -euo pipefail

NPM_GLOBAL="${NPM_CONFIG_PREFIX:-/root/.claude/npm-global}"
NODE_MODULES="${NPM_GLOBAL}/lib/node_modules"
CURRENT_NODE=$(node --version)

echo "[migrate-npm] Current Node: ${CURRENT_NODE}"
echo "[migrate-npm] npm global prefix: ${NPM_GLOBAL}"

if [ ! -d "${NODE_MODULES}" ]; then
    echo "[migrate-npm] ${NODE_MODULES} not found — nothing to migrate."
    exit 0
fi

pkgs=()

add_pkg() {
    local pkg_json="$1"
    [ -f "$pkg_json" ] || return
    local name ver
    name=$(jq -r '.name // ""' "$pkg_json" 2>/dev/null)
    ver=$(jq -r '.version // ""' "$pkg_json" 2>/dev/null)
    [ -n "$name" ] && [ -n "$ver" ] && pkgs+=("${name}@${ver}")
}

# Regular packages: node_modules/<pkg>/package.json
for dir in "${NODE_MODULES}"/*/; do
    [ -d "$dir" ] || continue
    [[ "$(basename "$dir")" == .* ]] && continue
    add_pkg "${dir}package.json"
done

# Scoped packages: node_modules/@scope/<pkg>/package.json
for scope_dir in "${NODE_MODULES}"/@*/; do
    [ -d "$scope_dir" ] || continue
    for dir in "${scope_dir}"*/; do
        [ -d "$dir" ] || continue
        add_pkg "${dir}package.json"
    done
done

if [ ${#pkgs[@]} -eq 0 ]; then
    echo "[migrate-npm] No globally installed packages found — nothing to migrate."
    exit 0
fi

echo "[migrate-npm] ${#pkgs[@]} package(s) to reinstall:"
printf '[migrate-npm]   %s\n' "${pkgs[@]}"
echo "[migrate-npm] Reinstalling for Node ${CURRENT_NODE} ..."

NPM_CONFIG_PREFIX="${NPM_GLOBAL}" npm install -g "${pkgs[@]}"

echo
echo "[migrate-npm] Done."
