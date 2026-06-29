#!/usr/bin/env bash
#
# stop.sh — WorkAdventure を停止する（データは保持されます）
#
set -euo pipefail
cd "$(dirname "$0")"

echo "🛑 コンテナを停止します..."
docker compose down
echo "✅ 停止しました。データ（マップ・証明書）は保持されています。"
echo "   再起動するには ./start.sh を実行してください。"
