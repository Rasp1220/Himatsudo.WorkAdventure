#!/usr/bin/env bash
#
# logs.sh — 各コンテナのログを追尾表示する
#
#   使い方:
#     ./logs.sh            全サービスのログ
#     ./logs.sh play       play サービスだけ
#
set -euo pipefail
cd "$(dirname "$0")"

docker compose logs -f --tail=100 "$@"
