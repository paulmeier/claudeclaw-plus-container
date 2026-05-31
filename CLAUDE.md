# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Docker container for [ClaudeClaw+](https://github.com/TerrysPOV/ClaudeClaw-Plus) — a superset of [claudeclaw](https://github.com/moazbuilds/claudeclaw) that extends Claude Code into a personal assistant with Telegram/Discord/Slack bridges, cron jobs, voice transcription, and a web dashboard.

ClaudeClaw+ source is cloned from GitHub at image build time (`ARG CLAUDECLAW_PLUS_REF=main`). No ClaudeClaw+ source lives in this repo.

## Build & run

```bash
# Build
docker build -t claudeclaw-plus .

# Build a specific ClaudeClaw+ ref
docker build --build-arg CLAUDECLAW_PLUS_REF=<branch|sha> -t claudeclaw-plus .

# Authenticate Claude Code into the volume (once)
docker compose run --rm claudeclaw-plus claude login

# Run via Compose (recommended)
docker compose up

# Run directly
docker run -p 4632:4632 -v claudeclaw-plus-data:/root/.claude claudeclaw-plus
```

## Architecture

**`Dockerfile`** — Installs Node.js, Bun, Claude Code CLI, clones ClaudeClaw+, runs `bun install`.

**`entrypoint.sh`** — Runs before `bun run src/index.ts`. Two responsibilities:
1. Bootstraps a minimal `settings.json` on first run if none exists under `/root/.claude/claudeclaw/`.
2. Patches `web.host` from `127.0.0.1` → `0.0.0.0` so the dashboard is reachable outside the container.

**`docker-compose.yml`** — Named volume `claudeclaw-plus-data` mounts at `/root/.claude`, persisting Claude Code auth, ClaudeClaw+ settings/logs/jobs, and whisper model downloads across container restarts.

## Configuration

ClaudeClaw+ settings live at `/root/.claude/claudeclaw/settings.json` inside the container (persisted in the named volume). On first start, `entrypoint.sh` creates a skeleton config. To use your own:

```yaml
# docker-compose.yml — uncomment and provide the file:
- ./settings.json:/root/.claude/claudeclaw/settings.json:ro
```

Web dashboard is exposed on port 4632. `entrypoint.sh` ensures `web.host` is always `0.0.0.0`.

## ClaudeClaw+ internals (for context)

- ClaudeClaw+ is a superset of upstream claudeclaw and auto-syncs from it daily; the daemon's on-disk data directory and entrypoint remain `claudeclaw` (e.g. `/root/.claude/claudeclaw/`).
- Runtime: Bun; Node.js required for `ogg-opus-decoder` (voice messages)
- Entry: `bun run src/index.ts [start|stop|status|telegram|discord|slack|send]`
- whisper.cpp binaries auto-download on first voice transcription (linux-x64/arm64 in containers)
- Auth: uses Claude Code's OAuth credential store at `/root/.claude/.credentials.json` — no API key needed. Run `claude login` once into the volume before starting the daemon.
