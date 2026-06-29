#!/usr/bin/env bash
#
# update.sh — リポジトリと Docker イメージを更新して再起動する
#
#   git pull → イメージ再取得 → 再作成 を一括で行います。
#   バージョンは .env の VERSION で固定されているため、
#   新バージョンに上げたい場合は .env の VERSION を変更してから実行してください。
#
set -euo pipefail
cd "$(dirname "$0")"

echo "⬇️  リポジトリを更新します (git pull)..."
git pull --ff-only || echo "（git pull はスキップまたは失敗しました。続行します）"

echo "⬇️  Docker イメージを取得します..."
docker compose pull

echo "🔄 コンテナを再作成します..."
docker compose up -d

echo "✅ 更新完了。古いイメージを掃除するには 'docker image prune' を実行してください。"
