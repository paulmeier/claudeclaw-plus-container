#!/bin/bash
# Reinstall Python user-base packages from a previous minor version into the current one.
# Run inside a running container after a base image update bumps the Python minor version:
#
#   docker compose exec claudeclaw /migrate-python.sh
set -euo pipefail

PYTHON_USER_BASE="${PYTHONUSERBASE:-/root/.claude/python-user}"
CURRENT_VER=$(python3 -c "import sys; print(f'python{sys.version_info.major}.{sys.version_info.minor}')")
LIB_DIR="${PYTHON_USER_BASE}/lib"

echo "[migrate-python] Current Python: ${CURRENT_VER}"
echo "[migrate-python] User base: ${PYTHON_USER_BASE}"

if [ ! -d "${LIB_DIR}" ]; then
    echo "[migrate-python] ${LIB_DIR} not found — nothing to migrate."
    exit 0
fi

found_old=0
while IFS= read -r -d '' dir; do
    version=$(basename "$dir")
    [ "$version" = "$CURRENT_VER" ] && continue

    site_pkg="${dir}/site-packages"
    found_old=1

    echo
    echo "[migrate-python] Scanning ${version} ..."

    if [ ! -d "$site_pkg" ]; then
        echo "[migrate-python]   No site-packages — skipping."
        continue
    fi

    pkgs=()
    while IFS= read -r -d '' dist_info; do
        name=$(grep -m1 "^Name: " "${dist_info}/METADATA" 2>/dev/null | cut -d' ' -f2- | tr -d '[:space:]')
        ver=$(grep -m1 "^Version: " "${dist_info}/METADATA" 2>/dev/null | cut -d' ' -f2- | tr -d '[:space:]')
        [ -n "$name" ] && [ -n "$ver" ] && pkgs+=("${name}==${ver}")
    done < <(find "$site_pkg" -maxdepth 1 -name '*.dist-info' -type d -print0)

    if [ ${#pkgs[@]} -eq 0 ]; then
        echo "[migrate-python]   No packages found — skipping."
        continue
    fi

    echo "[migrate-python]   ${#pkgs[@]} package(s) to reinstall:"
    printf '[migrate-python]     %s\n' "${pkgs[@]}"
    echo "[migrate-python]   Installing for ${CURRENT_VER} ..."

    PYTHONUSERBASE="${PYTHON_USER_BASE}" pip3 install --user --break-system-packages "${pkgs[@]}"

    echo
    echo "[migrate-python]   Installed. Old directory preserved: ${dir}"
    echo "[migrate-python]   Remove when satisfied: rm -rf '${dir}'"
done < <(find "${LIB_DIR}" -maxdepth 1 -name 'python*' -type d -print0)

if [ "$found_old" -eq 0 ]; then
    echo "[migrate-python] No old Python user-base directories found — nothing to migrate."
fi

echo
echo "[migrate-python] Done."
