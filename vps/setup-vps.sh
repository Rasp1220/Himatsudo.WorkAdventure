#!/usr/bin/env bash
#
# setup-vps.sh — VPS(玄関) 側の初期セットアップ
#
#   - .env.vps が無ければ .env.vps.template から作成
#   - .env.vps の値を埋め込んで Traefik の動的設定 dynamic/wa.yml を生成
#   - 何度実行しても安全（冪等）
#
set -euo pipefail
cd "$(dirname "$0")"

# ---------------------------------------------------------------------------
# 0. 前提コマンドの確認
# ---------------------------------------------------------------------------
if ! command -v docker >/dev/null 2>&1; then
  echo "❌ docker が見つかりません。先に Docker をインストールしてください。" >&2
  echo "   参考: https://docs.docker.com/engine/install/" >&2
  exit 1
fi
if ! docker compose version >/dev/null 2>&1; then
  echo "❌ 'docker compose' (Compose v2) が見つかりません。Docker を最新版に更新してください。" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# 1. .env.vps の作成
# ---------------------------------------------------------------------------
if [ ! -f .env.vps ]; then
  cp .env.vps.template .env.vps
  echo "📄 .env.vps.template から .env.vps を作成しました"
  echo "   → DOMAIN と ACME_EMAIL を編集してから、もう一度このスクリプトを実行してください。"
else
  echo "📄 既存の .env.vps を使用します"
fi

# .env.vps を読み込む
set -a
# shellcheck disable=SC1091
. ./.env.vps
set +a

: "${DOMAIN:?DOMAIN が未設定です（.env.vps）}"
if [ -z "${HOME_TS_IP:-}" ]; then
  echo "❌ HOME_TS_IP が未設定です（.env.vps）。" >&2
  echo "   自宅サーバーで 'tailscale ip -4' を実行し、表示された 100.x.x.x を設定してください。" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# 2. 動的設定の生成
# ---------------------------------------------------------------------------
mkdir -p dynamic letsencrypt
sed -e "s|\${DOMAIN}|${DOMAIN}|g" \
    -e "s|\${HOME_TS_IP}|${HOME_TS_IP}|g" \
    dynamic/wa.yml.template > dynamic/wa.yml
echo "  ✓ dynamic/wa.yml を生成しました（DOMAIN=${DOMAIN} → http://${HOME_TS_IP}:80）"

# acme.json は 600 でないと Traefik が拒否する
touch letsencrypt/acme.json
chmod 600 letsencrypt/acme.json

echo
echo "==================================================================="
echo " VPS セットアップ完了"
echo "-------------------------------------------------------------------"
echo " DOMAIN     : ${DOMAIN}"
echo " 転送先     : http://${HOME_TS_IP}:80 (Tailscale 越しの自宅サーバー)"
echo "==================================================================="
echo
echo "次の順で進めてください:"
echo "  1) Tailscale を用意（未実施なら）: VPS と自宅で 'sudo tailscale up'"
echo "  2) ./start.sh          ... Traefik(玄関) を起動"
