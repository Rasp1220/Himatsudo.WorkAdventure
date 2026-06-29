#!/usr/bin/env bash
#
# stop.sh — VPS(玄関) の Traefik を停止する（証明書データは保持されます）
#
set -euo pipefail
cd "$(dirname "$0")"

echo "🛑 Traefik を停止します..."
docker compose -f docker-compose.yaml --env-file .env.vps down
echo "✅ 停止しました。Let's Encrypt 証明書(letsencrypt/)は保持されています。"
