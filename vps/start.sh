#!/usr/bin/env bash
#
# start.sh — VPS(玄関) の Traefik リバースプロキシを起動する
#
set -euo pipefail
cd "$(dirname "$0")"

# .env.vps / dynamic/wa.yml が無ければセットアップ
if [ ! -f .env.vps ] || [ ! -f dynamic/wa.yml ]; then
  echo "🛠  セットアップが未完了のため setup-vps.sh を実行します..."
  ./setup-vps.sh
  echo
fi

# Tailscale の状態を軽く確認（任意）
if command -v tailscale >/dev/null 2>&1; then
  if ! tailscale status >/dev/null 2>&1; then
    echo "⚠️  Tailscale が起動していないようです。"
    echo "    VPS と自宅サーバーの両方で 'sudo tailscale up' を実行してください。"
    echo
  fi
fi

echo "⬇️  Docker イメージを取得します..."
docker compose -f docker-compose.yaml --env-file .env.vps pull

echo "🚀 Traefik を起動します..."
docker compose -f docker-compose.yaml --env-file .env.vps up -d

DOMAIN_VAL="$(grep -E '^DOMAIN=' .env.vps | head -n1 | cut -d= -f2-)"
echo
echo "✅ 起動しました。"
echo "🌐 アクセス URL: https://${DOMAIN_VAL}/"
echo "   （初回は Let's Encrypt 証明書取得で数十秒かかる場合があります）"
echo "   ログ: docker compose -f docker-compose.yaml logs -f"
