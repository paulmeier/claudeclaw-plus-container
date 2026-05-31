FROM node:24-trixie-slim

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    unzip \
    jq \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Chromium runtime libraries for the dev-browser Claude Code plugin
# (https://github.com/SawyerHood/dev-browser). The plugin auto-installs on
# ClaudeClaw+ startup and drives Playwright + headless Chromium; without
# these libs Chromium aborts at launch with
# "libglib-2.0.so.0: cannot open shared object file". apt cannot run
# inside the running container because hardened ClaudeClaw+ deployments
# drop CAP_SETGID, so the libs have to be baked into the image.
#
# Package list = Playwright's canonical Debian 13 / Ubuntu 24.04 list,
# taken from microsoft/playwright main @ 2026-05-23
# (packages/playwright-core/src/server/registry/nativeDeps.ts).
# Re-validate when bumping Playwright. The t64 suffixes are from Debian's
# time_t transition — the bookworm names (libasound2, libglib2.0-0, ...)
# would fail to install on trixie.
#
# Installed unconditionally on linux/amd64 and linux/arm64: dev-browser
# ships a linux-arm64 binary since v0.2.3 (confirmed via GitHub Releases
# API on 2026-05-23), so arm64 users need the same Chromium libs.
RUN apt-get update && apt-get install -y --no-install-recommends \
    libasound2t64 \
    libatk-bridge2.0-0t64 \
    libatk1.0-0t64 \
    libatspi2.0-0t64 \
    libcairo2 \
    libcups2t64 \
    libdbus-1-3 \
    libdrm2 \
    libgbm1 \
    libglib2.0-0t64 \
    libnspr4 \
    libnss3 \
    libpango-1.0-0 \
    libx11-6 \
    libxcb1 \
    libxcomposite1 \
    libxdamage1 \
    libxext6 \
    libxfixes3 \
    libxkbcommon0 \
    libxrandr2 \
    && rm -rf /var/lib/apt/lists/*

# Install Bun
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:$PATH"

# Install UV (fast Python package and project manager)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:$PATH"

# Install Claude Code CLI and pnpm. PNPM_HOME (below) puts pnpm's
# content-addressable store, manifest, and bin/ directory into the persistent
# volume so installed packages survive image rebuilds.
RUN npm install -g @anthropic-ai/claude-code pnpm

# ── Persistence env vars ──────────────────────────────────────────────────────
# Redirect each package manager's install paths and cache into /root/.claude/
# (the volume) so installed tooling survives image rebuilds and container
# recreation. Set as Dockerfile ENV (not entrypoint exports) so they are
# inherited by `docker exec` shells too — without this, user-initiated installs
# like `docker compose exec claudeclaw-plus pip install foo` would fail with
# PEP 668 or silently land in the writable image layer. The corresponding
# directories are created at runtime by entrypoint.sh (the volume doesn't
# exist at image-build time, so mkdir must happen there).
ENV IS_SANDBOX=1 \
    TMPDIR=/root/.claude/tmp \
    NPM_CONFIG_PREFIX=/root/.claude/npm-global \
    NPM_CONFIG_CACHE=/root/.claude/npm-cache \
    PYTHONUSERBASE=/root/.claude/python-user \
    PIP_USER=1 \
    PIP_BREAK_SYSTEM_PACKAGES=1 \
    PIP_CACHE_DIR=/root/.claude/pip-cache \
    PNPM_HOME=/root/.claude/pnpm-global \
    UV_TOOL_DIR=/root/.claude/uv-tools \
    UV_TOOL_BIN_DIR=/root/.claude/uv-tool-bin \
    UV_CACHE_DIR=/root/.claude/uv-cache \
    UV_PYTHON_INSTALL_DIR=/root/.claude/uv-python
ENV PATH="/root/.claude/npm-global/bin:/root/.claude/python-user/bin:/root/.claude/pnpm-global/bin:/root/.claude/uv-tool-bin:$PATH"

# Clone ClaudeClaw+ at the ref specified by CLAUDECLAW_PLUS_REF.
# Override at build time with --build-arg CLAUDECLAW_PLUS_REF=<branch|tag|sha> to pin.
WORKDIR /app
ARG CLAUDECLAW_PLUS_REF=main
RUN git clone https://github.com/TerrysPOV/ClaudeClaw-Plus . \
    && git checkout "${CLAUDECLAW_PLUS_REF}" \
    && bun install --frozen-lockfile

COPY entrypoint.sh /entrypoint.sh
COPY backup.sh /backup.sh
COPY migrate-python.sh /migrate-python.sh
COPY migrate-npm.sh /migrate-npm.sh
COPY migrate-pnpm.sh /migrate-pnpm.sh
COPY migrate-uv.sh /migrate-uv.sh
COPY healthcheck.sh /healthcheck.sh
RUN chmod +x /entrypoint.sh /backup.sh \
             /migrate-python.sh /migrate-npm.sh /migrate-pnpm.sh /migrate-uv.sh \
             /healthcheck.sh \
    && ln -s /healthcheck.sh /healthcheck

# Persist Claude Code config, ClaudeClaw+ settings/logs/jobs, and whisper models
VOLUME /root/.claude

EXPOSE 4632

ENTRYPOINT ["/entrypoint.sh"]
CMD ["start"]
