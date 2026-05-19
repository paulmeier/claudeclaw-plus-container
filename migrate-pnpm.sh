#!/bin/bash
# Reinstall pnpm global packages after a Node major version bump.
# Native addons compiled for the old ABI won't load under a new Node major version;
# reinstalling forces pnpm to recompile them for the current runtime.
# Run inside a running container after a base image update:
#
#   docker compose exec claudeclaw /migrate-pnpm.sh
set -euo pipefail

PNPM_HOME_DIR="${PNPM_HOME:-/root/.claude/pnpm-global}"
CURRENT_NODE=$(node --version)

echo "[migrate-pnpm] Current Node: ${CURRENT_NODE}"
echo "[migrate-pnpm] PNPM_HOME: ${PNPM_HOME_DIR}"

pkgs_json=$(PNPM_HOME="${PNPM_HOME_DIR}" pnpm ls --global --json --depth=0 2>/dev/null || echo "[]")

pkgs=()
while IFS= read -r pkg; do
    [ -n "$pkg" ] && pkgs+=("$pkg")
done < <(printf '%s' "$pkgs_json" \
    | jq -r '.[].dependencies // {} | to_entries[] | "\(.key)@\(.value.version)"' 2>/dev/null)

if [ ${#pkgs[@]} -eq 0 ]; then
    echo "[migrate-pnpm] No globally installed pnpm packages found — nothing to migrate."
    exit 0
fi

echo "[migrate-pnpm] ${#pkgs[@]} package(s) to reinstall:"
printf '[migrate-pnpm]   %s\n' "${pkgs[@]}"
echo "[migrate-pnpm] Reinstalling for Node ${CURRENT_NODE} ..."

PNPM_HOME="${PNPM_HOME_DIR}" pnpm add -g "${pkgs[@]}"

echo
echo "[migrate-pnpm] Done."
