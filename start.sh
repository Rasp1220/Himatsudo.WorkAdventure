#!/usr/bin/env bash
#
# start.sh — WorkAdventure を起動する
#
#   初回は setup.sh を未実行でも自動的に呼び出します。
#   イメージの取得 → バックグラウンド起動まで一発で行います。
#
set -euo pipefail

cd "$(dirname "$0")"

# .env が無ければ初期セットアップを実行
if [ ! -f .env ]; then
  echo "🛠  .env が無いため setup.sh を実行します..."
  ./setup.sh
  echo
fi

echo "⬇️  Docker イメージを取得します..."
docker compose pull

echo "🚀 コンテナを起動します..."
docker compose up -d

echo
echo "✅ 起動しました。状態を確認するには:"
echo "    docker compose ps"
echo "    ./logs.sh"
echo

DOMAIN_VAL="$(grep -E '^DOMAIN=' .env | head -n1 | cut -d= -f2-)"
echo "🌐 アクセス URL: https://${DOMAIN_VAL}/"
echo "   （初回は証明書取得やコンテナ初期化のため数分かかる場合があります）"
