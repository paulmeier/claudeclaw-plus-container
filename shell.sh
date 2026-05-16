#!/bin/zsh
cd "$(dirname "$0")"
docker compose up -d --quiet-pull 2>/dev/null
docker compose exec claudeclaw-plus claude
