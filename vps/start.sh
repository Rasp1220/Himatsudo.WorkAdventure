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

# トンネル(Tailscale / 素WireGuard)の状態を軽く確認（任意）
if command -v tailscale >/dev/null 2>&1 && tailscale status >/dev/null 2>&1; then
  : # Tailscale 稼働中
elif command -v wg >/dev/null 2>&1 && wg show wg0 >/dev/null 2>&1; then
  : # 素WireGuard(wg0) 稼働中
else
  echo "⚠️  トンネルが起動していないようです。先に用意してください:"
  echo "    Tailscale（推奨） … VPS と自宅で 'sudo tailscale up'"
  echo "    素WireGuard       … 'sudo ./setup-tunnel.sh' → 'sudo wg-quick up wg0'"
  echo
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
