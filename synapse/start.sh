#!/bin/sh
#
# Synapse 起動スクリプト（docker-compose の entrypoint から実行されます）。
#
#   1. テンプレートから homeserver.yaml を生成（環境変数を埋め込む）
#   2. 署名鍵が無ければ生成
#   3. Synapse を起動し、起動後に管理者アカウントを登録（毎回冪等）
#
# 公式 matrixdotorg/synapse イメージは root で起動し gosu で UID 991 に降格します。
# この entrypoint も通常は root で動くため、/data の所有者を 991 に揃えてから降格します。
set -eu

CONFIG=/data/homeserver.yaml
SYNAPSE_UID=991
SYNAPSE_GID=991

# python の実体（イメージにより python / python3 のどちらか）
if command -v python3 >/dev/null 2>&1; then
  PY=python3
else
  PY=python
fi

# root で動いている場合のみ所有権調整＋ gosu で降格する
if [ "$(id -u)" = "0" ] && command -v gosu >/dev/null 2>&1; then
  RUN_AS="gosu ${SYNAPSE_UID}:${SYNAPSE_GID}"
  IS_ROOT=1
else
  RUN_AS=""
  IS_ROOT=0
fi

mkdir -p /data/media_store

# 1. テンプレート展開（${VAR} を環境変数で置換）
"$PY" - <<'PYEOF'
import os, string, pathlib
tpl = pathlib.Path("/config/homeserver.template.yaml").read_text()
out = string.Template(tpl).safe_substitute(os.environ)
pathlib.Path("/data/homeserver.yaml").write_text(out)
PYEOF

# 2. 署名鍵の生成（初回のみ）
#    新しい Synapse イメージ（v1.140 等）には `generate_signing_key.py` という
#    スクリプトは存在せず、コンソールスクリプト `generate_signing_key`
#    （= python -m synapse._scripts.generate_signing_key）に置き換わっている。
#    旧名のままだと "generate_signing_key.py: not found"（exit 127）で
#    コンテナが起動できず再起動ループに陥るため、両対応にする。
if [ ! -f /data/signing.key ]; then
  echo "synapse: generating signing key"
  if command -v generate_signing_key >/dev/null 2>&1; then
    generate_signing_key -o /data/signing.key
  else
    "$PY" -m synapse._scripts.generate_signing_key -o /data/signing.key
  fi
fi

# 所有者を Synapse 実行ユーザーに揃える（root 起動時のみ）
if [ "$IS_ROOT" = "1" ]; then
  chown -R "${SYNAPSE_UID}:${SYNAPSE_GID}" /data
fi

# 3. 起動後に管理者アカウントを登録（存在する場合は無視）
(
  until "$PY" -c "import urllib.request; urllib.request.urlopen('http://localhost:8008/_matrix/client/versions')" >/dev/null 2>&1; do
    sleep 3
  done
  if [ -n "${MATRIX_ADMIN_USER:-}" ] && [ -n "${MATRIX_ADMIN_PASSWORD:-}" ]; then
    echo "synapse: ensuring admin user '${MATRIX_ADMIN_USER}' exists"
    # shellcheck disable=SC2086
    $RUN_AS register_new_matrix_user \
      -c "$CONFIG" \
      -u "${MATRIX_ADMIN_USER}" \
      -p "${MATRIX_ADMIN_PASSWORD}" \
      --admin \
      http://localhost:8008 || true
  else
    echo "synapse: MATRIX_ADMIN_USER or MATRIX_ADMIN_PASSWORD is unset — skipping admin registration"
  fi
) &

# shellcheck disable=SC2086
exec $RUN_AS "$PY" -m synapse.app.homeserver --config-path "$CONFIG"
