#!/bin/sh
set -e

TIMESTAMP=$(date +%Y-%m-%d-%H%M%S)

if [ -f "/.dockerenv" ]; then
    # ── Running inside the container ─────────────────────────────────────────
    # Data is at /root/.claude — no Docker needed.
    # Mount a backup directory into the container and point CLAUDECLAW_PLUS_BACKUP_DIR
    # at it, or accept the default of /backup.
    BACKUP_DIR="${CLAUDECLAW_PLUS_BACKUP_DIR:-/backup}"

    if [ ! -d "$BACKUP_DIR" ]; then
        echo "Error: backup directory '$BACKUP_DIR' does not exist inside the container."
        echo ""
        echo "Mount a host directory to the container and set CLAUDECLAW_PLUS_BACKUP_DIR, e.g.:"
        echo "  docker compose run -v ~/Backups/claudeclaw-plus:/backup claudeclaw-plus /backup.sh"
        echo "  CLAUDECLAW_PLUS_BACKUP_DIR=/backup docker compose exec claudeclaw-plus /backup.sh"
        exit 1
    fi

    BACKUP_FILE="$BACKUP_DIR/claudeclaw-plus-$TIMESTAMP.tar.gz"
    echo "Backing up ClaudeClaw+ data (in-container)..."
    tar czf "$BACKUP_FILE" -C /root/.claude .

else
    # ── Running on the host ───────────────────────────────────────────────────
    # Access data through the Docker volume using an alpine container.
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    BACKUP_DIR="${CLAUDECLAW_PLUS_BACKUP_DIR:-$SCRIPT_DIR/backups}"
    BACKUP_FILE="$BACKUP_DIR/claudeclaw-plus-$TIMESTAMP.tar.gz"

    # Compose prefixes volume names with the project name (by default the
    # directory name, e.g. claudeclaw-plus-container_claudeclaw-plus-data), so
    # look the volume up by its compose label rather than hardcoding it. Falls
    # back to the bare name used by the `docker run -v claudeclaw-plus-data:...`
    # instructions. CLAUDECLAW_PLUS_VOLUME overrides both.
    VOLUME="${CLAUDECLAW_PLUS_VOLUME:-}"
    if [ -z "$VOLUME" ]; then
        matches=$(docker volume ls -q --filter label=com.docker.compose.volume=claudeclaw-plus-data)
        count=$(printf '%s' "$matches" | grep -c . || true)
        if [ "$count" -gt 1 ]; then
            echo "Error: multiple ClaudeClaw+ volumes found; pick one with CLAUDECLAW_PLUS_VOLUME=<name>:"
            printf '  %s\n' $matches
            exit 1
        fi
        VOLUME="${matches:-claudeclaw-plus-data}"
    fi

    # `docker run -v` silently creates a missing volume, which would produce an
    # empty archive that looks like a successful backup — refuse instead.
    if ! docker volume inspect "$VOLUME" >/dev/null 2>&1; then
        echo "Error: Docker volume '$VOLUME' not found."
        echo "List volumes with 'docker volume ls' and set CLAUDECLAW_PLUS_VOLUME=<name>."
        exit 1
    fi

    mkdir -p "$BACKUP_DIR"
    echo "Backing up ClaudeClaw+ volume '$VOLUME' (host)..."
    docker run --rm \
      -v "$VOLUME":/data:ro \
      -v "$BACKUP_DIR":/backup \
      alpine tar czf "/backup/claudeclaw-plus-$TIMESTAMP.tar.gz" -C /data .
fi

SIZE=$(du -sh "$BACKUP_FILE" | cut -f1)
echo "Saved: $BACKUP_FILE ($SIZE)"
