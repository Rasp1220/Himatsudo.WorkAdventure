#!/usr/bin/env bash
#
# setup-tunnel.sh — VPS ⇄ 自宅 を WireGuard でつなぐためのセットアップ（VPS 上で実行）
#
#   - VPS / 自宅 双方の鍵ペアを生成
#   - VPS 側の設定 /etc/wireguard/wg0.conf を作成（要 root）
#   - 自宅サーバーへコピーして使う設定 ./wg-home.conf を出力
#
#   構成:
#     VPS  : 10.8.0.1/24  (ListenPort=51820)
#     自宅 : 10.8.0.2/24  (VPS へアウトバウンド接続・PersistentKeepalive)
#
#   使い方:
#     sudo ./setup-tunnel.sh [VPSの公開IPまたはホスト名] [ポート]
#       引数を省略するとグローバル IP を自動検出し、ポートは 51820 を使います。
#
set -euo pipefail
cd "$(dirname "$0")"

WG_PORT="${2:-51820}"
WG_SUBNET="10.8.0"
VPS_WG_IP="${WG_SUBNET}.1"
HOME_WG_IP="${WG_SUBNET}.2"

# ---------------------------------------------------------------------------
# 0. 前提コマンドの確認
# ---------------------------------------------------------------------------
if ! command -v wg >/dev/null 2>&1; then
  echo "❌ wireguard-tools が見つかりません。先にインストールしてください。" >&2
  echo "   Debian/Ubuntu: sudo apt-get update && sudo apt-get install -y wireguard" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# 1. VPS の公開エンドポイント（IP/ホスト名）を決定
# ---------------------------------------------------------------------------
ENDPOINT="${1:-}"
if [ -z "$ENDPOINT" ]; then
  echo "🔎 VPS のグローバル IP を自動検出します..."
  ENDPOINT="$(curl -fsS https://api.ipify.org 2>/dev/null || true)"
  if [ -z "$ENDPOINT" ]; then
    echo "❌ グローバル IP を自動検出できませんでした。" >&2
    echo "   引数で指定してください: sudo ./setup-tunnel.sh <VPSの公開IP> [ポート]" >&2
    exit 1
  fi
  echo "   → ${ENDPOINT}"
fi

# ---------------------------------------------------------------------------
# 2. 鍵ペアを生成
# ---------------------------------------------------------------------------
echo "🔐 WireGuard の鍵ペアを生成します..."
umask 077
VPS_PRIV="$(wg genkey)"
VPS_PUB="$(printf '%s' "$VPS_PRIV" | wg pubkey)"
HOME_PRIV="$(wg genkey)"
HOME_PUB="$(printf '%s' "$HOME_PRIV" | wg pubkey)"

# ---------------------------------------------------------------------------
# 3. VPS 側 /etc/wireguard/wg0.conf を作成
# ---------------------------------------------------------------------------
WG_CONF="/etc/wireguard/wg0.conf"
if [ "$(id -u)" -ne 0 ]; then
  echo "⚠️  ${WG_CONF} の書き込みには root 権限が必要です。'sudo ./setup-tunnel.sh ...' で実行してください。" >&2
  exit 1
fi

if [ -f "$WG_CONF" ]; then
  cp "$WG_CONF" "${WG_CONF}.bak.$(date +%s)"
  echo "  ℹ️  既存の ${WG_CONF} を .bak に退避しました"
fi

cat > "$WG_CONF" <<EOF
# WorkAdventure 玄関(VPS) 側 WireGuard 設定 — setup-tunnel.sh が生成
[Interface]
Address = ${VPS_WG_IP}/24
ListenPort = ${WG_PORT}
PrivateKey = ${VPS_PRIV}

[Peer]
# 自宅サーバー
PublicKey = ${HOME_PUB}
AllowedIPs = ${HOME_WG_IP}/32
EOF
chmod 600 "$WG_CONF"
echo "  ✓ ${WG_CONF} を作成しました"

# ---------------------------------------------------------------------------
# 4. 自宅サーバー用の設定を出力（./wg-home.conf）
# ---------------------------------------------------------------------------
cat > ./wg-home.conf <<EOF
# WorkAdventure 自宅サーバー側 WireGuard 設定
# このファイルを自宅サーバーの /etc/wireguard/wg0.conf として配置してください。
[Interface]
Address = ${HOME_WG_IP}/24
PrivateKey = ${HOME_PRIV}

[Peer]
# VPS(玄関)
PublicKey = ${VPS_PUB}
Endpoint = ${ENDPOINT}:${WG_PORT}
AllowedIPs = ${VPS_WG_IP}/32
# NAT 内から接続を維持するためのキープアライブ（自宅→VPS 方向で必須）
PersistentKeepalive = 25
EOF
chmod 600 ./wg-home.conf

# ---------------------------------------------------------------------------
# 5. 案内
# ---------------------------------------------------------------------------
cat <<EOF

===================================================================
 WireGuard 設定を生成しました
-------------------------------------------------------------------
 VPS  : ${VPS_WG_IP}/24  (ListenPort=${WG_PORT}, Endpoint=${ENDPOINT})
 自宅 : ${HOME_WG_IP}/24
===================================================================

【VPS 側】トンネルを起動・自動起動化:
    sudo wg-quick up wg0
    sudo systemctl enable wg-quick@wg0     # 再起動後も自動で張る

  ※ VPS のファイアウォール / セキュリティグループで以下を開放してください:
       - UDP ${WG_PORT}        (WireGuard)
       - TCP 80, 443          (Let's Encrypt と HTTPS 配信)

【自宅サーバー側】生成した wg-home.conf を配置して起動:
    # wg-home.conf を自宅サーバーへ安全にコピー（例）
    scp wg-home.conf you@home:/tmp/wg-home.conf
    # 自宅サーバー上で:
    sudo install -m 600 /tmp/wg-home.conf /etc/wireguard/wg0.conf
    sudo apt-get install -y wireguard      # 未インストールなら
    sudo wg-quick up wg0
    sudo systemctl enable wg-quick@wg0

【疎通確認】VPS から自宅へ ping:
    ping -c3 ${HOME_WG_IP}

  ※ wg-home.conf には秘密鍵が含まれます。コピー後は VPS 上から削除してください:
    shred -u wg-home.conf   # または rm wg-home.conf
EOF
