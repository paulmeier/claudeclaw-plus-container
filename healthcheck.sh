#!/bin/bash
# healthcheck.sh — runtime diagnostics for the claudeclaw container.
# Runs automatically at container startup and is available at any time:
#
#   docker compose exec claudeclaw /healthcheck
#
# Reports runtime versions, installed package inventories, disk usage, key
# environment variables, and migration warnings for all supported package
# managers (npm, pnpm, pip, uv). Exits 0 even when warnings are present —
# warnings are advisory and do not prevent the daemon from starting.

# Intentionally no set -e: a diagnostic script must run to completion even
# when individual checks fail or commands are unavailable.

# ── Defaults ──────────────────────────────────────────────────────────────────
# These mirror the values set by entrypoint.sh so the script is self-contained
# when called via `docker compose exec` (where entrypoint env vars aren't set).
_NPM_GLOBAL="${NPM_CONFIG_PREFIX:-/root/.claude/npm-global}"
_NPM_CACHE="${NPM_CONFIG_CACHE:-/root/.claude/npm-cache}"
_PYTHON_USER="${PYTHONUSERBASE:-/root/.claude/python-user}"
_PIP_CACHE="${PIP_CACHE_DIR:-/root/.claude/pip-cache}"
_PNPM_GLOBAL="${PNPM_HOME:-/root/.claude/pnpm-global}"
_UV_TOOLS="${UV_TOOL_DIR:-/root/.claude/uv-tools}"
_UV_TOOL_BINS="${UV_TOOL_BIN_DIR:-/root/.claude/uv-tool-bin}"
_UV_CACHE="${UV_CACHE_DIR:-/root/.claude/uv-cache}"
_UV_PYTHON="${UV_PYTHON_INSTALL_DIR:-/root/.claude/uv-python}"

# ── Colours (only when stdout is a terminal) ──────────────────────────────────
if [ -t 1 ]; then
    _B='\033[1m' _R='\033[0m' _DIM='\033[2m'
    _GRN='\033[0;32m' _YLW='\033[1;33m' _RED='\033[0;31m'
else
    _B='' _R='' _DIM='' _GRN='' _YLW='' _RED=''
fi

# ── Helpers ───────────────────────────────────────────────────────────────────
WARNINGS=0

_section() { printf "\n${_B}── %s${_R}\n" "$*"; }
_ok()      { printf "  ${_GRN}ok${_R}    %s\n" "$*"; }
_warn()    { printf "  ${_YLW}WARN${_R}  %s\n" "$*"; WARNINGS=$((WARNINGS + 1)); }
_kv()      { printf "  %-28s %s\n" "$1" "$2"; }
_sub()     { printf "         %s\n" "$*"; }
_hr()      { printf "${_DIM}%s${_R}\n" "────────────────────────────────────────────────────"; }

_dirsize() {
    local path="$1"
    if [ -d "$path" ]; then
        du -sh "$path" 2>/dev/null | cut -f1
    else
        echo "(absent)"
    fi
}

# ── Header ────────────────────────────────────────────────────────────────────
_hr
printf "${_B}claudeclaw healthcheck${_R}  $(date -u '+%Y-%m-%d %H:%M:%S UTC')\n"
_hr

# ── Runtimes ──────────────────────────────────────────────────────────────────
_section "Runtimes"

_NODE_VER=$(node  --version 2>/dev/null || echo "(not found)")
_NODE_ABI=$(node  -e 'process.stdout.write(process.versions.modules)' 2>/dev/null || echo "?")
_NPM_VER=$(npm    --version 2>/dev/null || echo "(not found)")
_PNPM_VER=$(pnpm  --version 2>/dev/null || echo "(not found)")
_BUN_VER=$(bun    --version 2>/dev/null || echo "(not found)")
_PY_VER=$(python3 --version 2>/dev/null | awk '{print $2}' || echo "(not found)")
_PY_MINOR=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")' 2>/dev/null || echo "?")
_PIP_VER=$(pip3   --version 2>/dev/null | awk '{print $2}' || echo "(not found)")
_UV_VER=$(uv      --version 2>/dev/null | awk '{print $2}' || echo "(not found)")

_kv "Node"   "$_NODE_VER  (ABI $_NODE_ABI)"
_kv "npm"    "v$_NPM_VER"
_kv "pnpm"   "v$_PNPM_VER"
_kv "Bun"    "v$_BUN_VER"
_kv "Python" "$_PY_VER"
_kv "pip"    "v$_PIP_VER"
_kv "uv"     "v$_UV_VER"

# ── Node ABI tracking ─────────────────────────────────────────────────────────
# The ABI version (process.versions.modules) changes with every Node major
# release. Packages with native addons compiled against an old ABI will fail
# to load under a new one. We persist the last-seen ABI in the volume so we
# can detect a bump on the next container start.
_ABI_FILE="${_NPM_GLOBAL}/.node-abi"
_STORED_ABI=$(cat "$_ABI_FILE" 2>/dev/null || true)
_NODE_ABI_CHANGED=false
if [ -n "$_STORED_ABI" ] && [ "$_STORED_ABI" != "$_NODE_ABI" ]; then
    _NODE_ABI_CHANGED=true
fi

# ── npm globals ───────────────────────────────────────────────────────────────
_section "npm globals  ($_NPM_GLOBAL/lib/node_modules)"
_NODE_MODULES="${_NPM_GLOBAL}/lib/node_modules"
_npm_pkgs=()

if [ -d "$_NODE_MODULES" ]; then
    for _d in "$_NODE_MODULES"/*/; do
        [ -d "$_d" ] || continue
        [[ "$(basename "$_d")" == .* ]] && continue
        _n=$(jq -r '.name    // ""' "${_d}package.json" 2>/dev/null || true)
        _v=$(jq -r '.version // ""' "${_d}package.json" 2>/dev/null || true)
        [ -n "$_n" ] && _npm_pkgs+=("${_n}@${_v}")
    done
    for _sd in "$_NODE_MODULES"/@*/; do
        [ -d "$_sd" ] || continue
        for _d in "$_sd"*/; do
            [ -d "$_d" ] || continue
            _n=$(jq -r '.name    // ""' "${_d}package.json" 2>/dev/null || true)
            _v=$(jq -r '.version // ""' "${_d}package.json" 2>/dev/null || true)
            [ -n "$_n" ] && _npm_pkgs+=("${_n}@${_v}")
        done
    done
fi

_kv "packages" "${#_npm_pkgs[@]}"
if [ ${#_npm_pkgs[@]} -gt 0 ]; then
    for _p in "${_npm_pkgs[@]}"; do _sub "$_p"; done
fi
_kv "cache" "$(_dirsize "$_NPM_CACHE")"

_NPX_CACHE="${_NPM_CACHE}/_npx"
if [ -d "$_NPX_CACHE" ]; then
    _kv "npx cache" "$(_dirsize "$_NPX_CACHE")"
fi

if [ "$_NODE_ABI_CHANGED" = true ] && [ ${#_npm_pkgs[@]} -gt 0 ]; then
    _warn "Node ABI changed ($_STORED_ABI → $_NODE_ABI) — npm native addons may be broken"
    _sub "→ /migrate-npm.sh"
    if [ -d "$_NPX_CACHE" ]; then
        _warn "npx cached environments may also be broken"
        _sub "→ rm -rf $_NPX_CACHE"
    fi
elif [ ${#_npm_pkgs[@]} -gt 0 ]; then
    _ok "Node ABI $_NODE_ABI — no npm migration needed"
fi

# ── pnpm globals ──────────────────────────────────────────────────────────────
_section "pnpm globals  ($_PNPM_GLOBAL)"
_pnpm_pkgs=()

_pnpm_json=$(PNPM_HOME="$_PNPM_GLOBAL" pnpm ls --global --json --depth=0 2>/dev/null || echo "[]")
while IFS= read -r _pkg; do
    [ -n "$_pkg" ] && _pnpm_pkgs+=("$_pkg")
done < <(printf '%s' "$_pnpm_json" \
    | jq -r '.[].dependencies // {} | to_entries[] | "\(.key)@\(.value.version)"' 2>/dev/null || true)

_kv "packages" "${#_pnpm_pkgs[@]}"
if [ ${#_pnpm_pkgs[@]} -gt 0 ]; then
    for _p in "${_pnpm_pkgs[@]}"; do _sub "$_p"; done
fi
_kv "total size" "$(_dirsize "$_PNPM_GLOBAL")"

if [ "$_NODE_ABI_CHANGED" = true ] && [ ${#_pnpm_pkgs[@]} -gt 0 ]; then
    _warn "Node ABI changed ($_STORED_ABI → $_NODE_ABI) — pnpm native addons may be broken"
    _sub "→ /migrate-pnpm.sh"
elif [ ${#_pnpm_pkgs[@]} -gt 0 ]; then
    _ok "Node ABI $_NODE_ABI — no pnpm migration needed"
fi

# ── pip (user) ────────────────────────────────────────────────────────────────
_section "pip user packages  ($_PYTHON_USER/lib)"
_PY_LIB="${_PYTHON_USER}/lib"
_CURRENT_PY="python${_PY_MINOR}"
_pip_pkgs=()
_stale_py_dirs=()

if [ -d "$_PY_LIB" ]; then
    for _lib_dir in "$_PY_LIB"/python*/; do
        [ -d "$_lib_dir" ] || continue
        _ver=$(basename "$_lib_dir")
        _site="${_lib_dir}site-packages"
        [ -d "$_site" ] || continue

        if [ "$_ver" != "$_CURRENT_PY" ]; then
            _count=$(find "$_site" -maxdepth 1 -name '*.dist-info' -type d 2>/dev/null | wc -l | tr -d ' ')
            _stale_py_dirs+=("$_ver ($_count package(s))")
        else
            while IFS= read -r -d '' _di; do
                _n=$(grep -m1 "^Name: "    "${_di}/METADATA" 2>/dev/null | cut -d' ' -f2- | tr -d '[:space:]' || true)
                _v=$(grep -m1 "^Version: " "${_di}/METADATA" 2>/dev/null | cut -d' ' -f2- | tr -d '[:space:]' || true)
                [ -n "$_n" ] && _pip_pkgs+=("${_n}==${_v}")
            done < <(find "$_site" -maxdepth 1 -name '*.dist-info' -type d -print0 2>/dev/null)
        fi
    done
fi

_kv "Python" "$_PY_VER  ($_CURRENT_PY)"
_kv "packages" "${#_pip_pkgs[@]}"
if [ ${#_pip_pkgs[@]} -gt 0 ]; then
    for _p in "${_pip_pkgs[@]}"; do _sub "$_p"; done
fi
_kv "cache" "$(_dirsize "$_PIP_CACHE")"

if [ ${#_stale_py_dirs[@]} -gt 0 ]; then
    _warn "Stale pip site-packages for old Python version(s) — packages are invisible to current interpreter"
    for _d in "${_stale_py_dirs[@]}"; do _sub "$_d"; done
    _sub "→ /migrate-python.sh"
    _sub "  Then: rm -rf $_PY_LIB/<old-version>"
elif [ ${#_pip_pkgs[@]} -gt 0 ]; then
    _ok "Python version matches installed packages ($_CURRENT_PY)"
fi

# ── uv tools ──────────────────────────────────────────────────────────────────
_section "uv tools  ($_UV_TOOLS)"
_uv_tools=()
_broken_uv=()

if [ -d "$_UV_TOOLS" ]; then
    for _td in "$_UV_TOOLS"/*/; do
        [ -d "$_td" ] || continue
        _tname=$(basename "$_td")

        # Reconstruct install spec from receipt (name + version specifier)
        _receipt="${_td}uv-receipt.json"
        _spec="$_tname"
        if [ -f "$_receipt" ]; then
            _rname=$(jq -r '.tool.requirements[0].name    // ""' "$_receipt" 2>/dev/null || true)
            _rspec=$(jq -r '.tool.requirements[0].specifier // ""' "$_receipt" 2>/dev/null || true)
            [ -n "$_rname" ] && _spec="${_rname}${_rspec}"
        fi
        _uv_tools+=("$_spec")

        # Detect broken venv: check that the Python home recorded in pyvenv.cfg still exists.
        # A missing home directory means the interpreter the venv was built with is gone.
        _cfg="${_td}pyvenv.cfg"
        if [ -f "$_cfg" ]; then
            _home=$(grep "^home = " "$_cfg" 2>/dev/null | sed 's/^home = //' | tr -d '[:space:]' || true)
            if [ -n "$_home" ] && [ ! -d "$_home" ]; then
                _broken_uv+=("$_tname  (home: $_home — directory missing)")
            fi
        fi
    done
fi

_kv "tools" "${#_uv_tools[@]}"
if [ ${#_uv_tools[@]} -gt 0 ]; then
    for _t in "${_uv_tools[@]}"; do _sub "$_t"; done
fi
_kv "cache" "$(_dirsize "$_UV_CACHE")"

# UV-managed Python installations
if [ -d "$_UV_PYTHON" ] && [ -n "$(ls -A "$_UV_PYTHON" 2>/dev/null)" ]; then
    _uv_py_count=$(ls -1 "$_UV_PYTHON" 2>/dev/null | wc -l | tr -d ' ')
    _kv "managed Pythons" "$_uv_py_count"
    for _pydir in "$_UV_PYTHON"/*/; do
        [ -d "$_pydir" ] && _sub "$(basename "$_pydir")"
    done
else
    _kv "managed Pythons" "none"
fi

if [ ${#_broken_uv[@]} -gt 0 ]; then
    _warn "${#_broken_uv[@]} UV tool venv(s) reference a Python interpreter that no longer exists"
    for _t in "${_broken_uv[@]}"; do _sub "$_t"; done
    _sub "→ /migrate-uv.sh"
    _sub "  For broken uvx environments: uv cache clean"
elif [ ${#_uv_tools[@]} -gt 0 ]; then
    _ok "All UV tool venvs reference a valid Python interpreter"
fi

# ── Volume disk usage ─────────────────────────────────────────────────────────
_section "Volume disk usage  (/root/.claude)"

_kv "npm-global/"   "$(_dirsize "$_NPM_GLOBAL")"
_kv "npm-cache/"    "$(_dirsize "$_NPM_CACHE")"
_kv "python-user/"  "$(_dirsize "$_PYTHON_USER")"
_kv "pip-cache/"    "$(_dirsize "$_PIP_CACHE")"
_kv "pnpm-global/"  "$(_dirsize "$_PNPM_GLOBAL")"
_kv "uv-tools/"     "$(_dirsize "$_UV_TOOLS")"
_kv "uv-tool-bin/"  "$(_dirsize "$_UV_TOOL_BINS")"
_kv "uv-cache/"     "$(_dirsize "$_UV_CACHE")"
_kv "uv-python/"    "$(_dirsize "$_UV_PYTHON")"
if [ -d /root/.claude ]; then
    _kv "total" "$(du -sh /root/.claude 2>/dev/null | cut -f1)"
fi

# ── Environment ───────────────────────────────────────────────────────────────
_section "Environment"

_kv "NPM_CONFIG_PREFIX"      "${NPM_CONFIG_PREFIX:-$_NPM_GLOBAL  ${_DIM}(default)${_R}}"
_kv "NPM_CONFIG_CACHE"       "${NPM_CONFIG_CACHE:-$_NPM_CACHE  ${_DIM}(default)${_R}}"
_kv "PYTHONUSERBASE"         "${PYTHONUSERBASE:-$_PYTHON_USER  ${_DIM}(default)${_R}}"
_kv "PIP_USER"               "${PIP_USER:-${_DIM}(not set)${_R}}"
_kv "PIP_BREAK_SYSTEM_PKGS"  "${PIP_BREAK_SYSTEM_PACKAGES:-${_DIM}(not set)${_R}}"
_kv "PIP_CACHE_DIR"          "${PIP_CACHE_DIR:-$_PIP_CACHE  ${_DIM}(default)${_R}}"
_kv "UV_TOOL_DIR"            "${UV_TOOL_DIR:-$_UV_TOOLS  ${_DIM}(default)${_R}}"
_kv "UV_TOOL_BIN_DIR"        "${UV_TOOL_BIN_DIR:-$_UV_TOOL_BINS  ${_DIM}(default)${_R}}"
_kv "UV_CACHE_DIR"           "${UV_CACHE_DIR:-$_UV_CACHE  ${_DIM}(default)${_R}}"
_kv "UV_PYTHON_INSTALL_DIR"  "${UV_PYTHON_INSTALL_DIR:-$_UV_PYTHON  ${_DIM}(default)${_R}}"
_kv "PNPM_HOME"              "${PNPM_HOME:-$_PNPM_GLOBAL  ${_DIM}(default)${_R}}"
_kv "PATH (head)"            "$(echo "$PATH" | tr ':' '\n' | head -5 | tr '\n' ':' | sed 's/:$//')..."

# ── Persist ABI after all checks ──────────────────────────────────────────────
# Written last so the stored value always reflects what was running when this
# healthcheck completed — not an intermediate state.
mkdir -p "$_NPM_GLOBAL" 2>/dev/null || true
printf '%s' "$_NODE_ABI" > "$_ABI_FILE" 2>/dev/null || true

# ── Summary ───────────────────────────────────────────────────────────────────
echo
_hr
if [ "$WARNINGS" -eq 0 ]; then
    printf "${_GRN}${_B}All checks passed.${_R}\n"
else
    printf "${_YLW}${_B}$WARNINGS warning(s) — see above for migration instructions.${_R}\n"
fi
_hr
echo
