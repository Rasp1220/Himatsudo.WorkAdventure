#!/usr/bin/env bash
#
# setup.sh — WorkAdventure を初回構築するためのスクリプト
#
#   - .env が無ければ .env.template から作成
#   - 空の秘密鍵（SECRET_KEY 等）をランダム生成して書き込み
#   - 何度実行しても安全（既に値があれば上書きしない）
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
# ランダム文字列生成（openssl が無ければ /dev/urandom にフォールバック）
# ---------------------------------------------------------------------------
gen_secret() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex 32
  else
    head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n'
  fi
}

# .env 内の "KEY=" が空のときだけ value を埋める
fill_if_empty() {
  local key="$1" value="$2" file=".env"
  # 現在の値を取得（KEY=... の右側）
  local current
  current="$(grep -E "^${key}=" "$file" | head -n1 | cut -d= -f2- || true)"
  if [ -z "$current" ]; then
    # 区切りに | を使い、value に / 等が含まれても安全に置換
    sed -i "s|^${key}=.*|${key}=${value}|" "$file"
    echo "  ✓ ${key} を自動生成しました"
  else
    echo "  - ${key} は既に設定済み（変更しません）"
  fi
}

# ---------------------------------------------------------------------------
# 1. .env の作成
# ---------------------------------------------------------------------------
if [ ! -f .env ]; then
  cp .env.template .env
  echo "📄 .env.template から .env を作成しました"
else
  echo "📄 既存の .env を使用します"
fi

# ---------------------------------------------------------------------------
# 2. 秘密鍵の自動生成
# ---------------------------------------------------------------------------
echo "🔐 秘密鍵を確認・生成します..."
fill_if_empty "SECRET_KEY"                        "$(gen_secret)"
fill_if_empty "ROOM_API_SECRET_KEY"               "$(gen_secret)"
fill_if_empty "MAP_STORAGE_AUTHENTICATION_PASSWORD" "$(gen_secret)"

# Matrix / Synapse（チャット）用の秘密鍵・管理者パスワード
fill_if_empty "MATRIX_ADMIN_PASSWORD"             "$(gen_secret | head -c 24)"
fill_if_empty "MATRIX_REGISTRATION_SHARED_SECRET" "$(gen_secret)"
fill_if_empty "MATRIX_MACAROON_SECRET"            "$(gen_secret)"
fill_if_empty "MATRIX_FORM_SECRET"                "$(gen_secret)"

# ---------------------------------------------------------------------------
# 2b. Basic 認証の自動生成（BASIC_AUTH_USERS キーが .env にある場合のみ）
# ---------------------------------------------------------------------------
if grep -q "^BASIC_AUTH_USERS=" .env; then
  BA_CURRENT_PASS="$(grep -E '^BASIC_AUTH_PASSWORD=' .env | head -n1 | cut -d= -f2- || true)"
  if [ -z "$BA_CURRENT_PASS" ]; then
    BA_USERNAME="$(grep -E '^BASIC_AUTH_USERNAME=' .env | head -n1 | cut -d= -f2-)"
    BA_USERNAME="${BA_USERNAME:-admin}"
    BA_PASS=$(gen_secret | head -c 16)
    BA_HASH=$(openssl passwd -apr1 "$BA_PASS")
    python3 - "$BA_PASS" "${BA_USERNAME}:${BA_HASH}" <<'PYEOF'
import sys, re
ba_pass, ba_users = sys.argv[1], sys.argv[2]
with open('.env') as f:
    content = f.read()
content = re.sub(r'^BASIC_AUTH_PASSWORD=.*', 'BASIC_AUTH_PASSWORD=' + ba_pass, content, flags=re.MULTILINE)
content = re.sub(r'^BASIC_AUTH_USERS=.*', 'BASIC_AUTH_USERS=' + ba_users, content, flags=re.MULTILINE)
with open('.env', 'w') as f:
    f.write(content)
PYEOF
    echo "  ✓ BASIC_AUTH_PASSWORD / BASIC_AUTH_USERS を自動生成しました"
  else
    echo "  - BASIC_AUTH_PASSWORD は既に設定済み（変更しません）"
  fi
fi

# ---------------------------------------------------------------------------
# 3. 設定内容の確認表示
# ---------------------------------------------------------------------------
DOMAIN_VAL="$(grep -E '^DOMAIN=' .env | head -n1 | cut -d= -f2-)"
MS_USER="$(grep -E '^MAP_STORAGE_AUTHENTICATION_USER=' .env | head -n1 | cut -d= -f2-)"
MS_PASS="$(grep -E '^MAP_STORAGE_AUTHENTICATION_PASSWORD=' .env | head -n1 | cut -d= -f2-)"
BA_USER_VAL="$(grep -E '^BASIC_AUTH_USERNAME=' .env | head -n1 | cut -d= -f2- || true)"
BA_PASS_VAL="$(grep -E '^BASIC_AUTH_PASSWORD=' .env | head -n1 | cut -d= -f2- || true)"

echo
echo "==================================================================="
echo " セットアップ完了"
echo "-------------------------------------------------------------------"
echo " DOMAIN              : ${DOMAIN_VAL}"
echo " マップ編集ログイン  : ユーザー名 = ${MS_USER}"
echo "                       パスワード = ${MS_PASS}"
echo "   （WorkAdventure 上でマップ編集を保存する際に使います）"
if [ -n "$BA_PASS_VAL" ]; then
  echo " Basic 認証          : ユーザー名 = ${BA_USER_VAL:-admin}"
  echo "                       パスワード = ${BA_PASS_VAL}"
  echo "   （サイトにアクセスした際にブラウザが求めるパスワードです）"
fi
echo "==================================================================="
echo

case "$DOMAIN_VAL" in
  *.localhost)
    echo "ℹ️  DOMAIN が '*.localhost' のため、ローカル検証モードです。"
    echo "    Let's Encrypt 証明書は取得されず、Traefik の自己署名証明書になります。"
    echo "    ブラウザの警告は手動で許可してください。"
    echo "    インターネット公開する場合は .env の DOMAIN と ACME_EMAIL を設定し直してください。"
    ;;
  *)
    ACME_VAL="$(grep -E '^ACME_EMAIL=' .env | head -n1 | cut -d= -f2-)"
    if [ -z "$ACME_VAL" ]; then
      echo "⚠️  公開ドメインを使う場合、Let's Encrypt 用に ACME_EMAIL の設定が必要です。"
      echo "    .env を開いて ACME_EMAIL=あなたのメール を設定してください。"
    fi
    echo "ℹ️  ${DOMAIN_VAL} の DNS A レコードがこのサーバーを指し、"
    echo "    ポート ${HTTP_PORT:-80}/443 が外部へ開放されていることを確認してください。"
    ;;
esac

echo
echo "次のコマンドで起動します:"
echo "    ./start.sh"
