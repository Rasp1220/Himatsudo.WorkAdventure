#!/usr/bin/env bash
#
# logs.sh — VPS(玄関) Traefik のログを追尾表示する
#
set -euo pipefail
cd "$(dirname "$0")"

docker compose -f docker-compose.yaml --env-file .env.vps logs -f --tail=100 "$@"
