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

    mkdir -p "$BACKUP_DIR"
    echo "Backing up ClaudeClaw+ volume (host)..."
    docker run --rm \
      -v claudeclaw-plus-data:/data:ro \
      -v "$BACKUP_DIR":/backup \
      alpine tar czf "/backup/claudeclaw-plus-$TIMESTAMP.tar.gz" -C /data .
fi

SIZE=$(du -sh "$BACKUP_FILE" | cut -f1)
echo "Saved: $BACKUP_FILE ($SIZE)"
