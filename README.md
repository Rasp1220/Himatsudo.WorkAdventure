# Himatsudo.WorkAdventure

自宅サーバーで [WorkAdventure](https://workadventu.re/)（2D メタバース型バーチャルオフィス）を
**clone / pull して一発で構築・起動**できるようにまとめたリポジトリです。

公式の本番用 Docker Compose 構成（Traefik + Let's Encrypt、シングルドメイン）をベースに、
秘密鍵の自動生成や起動スクリプトを追加して、最小手順で立ち上がるようにしています。

- 利用イメージのバージョンは安定版 **`v1.31.7`** に固定（`.env` の `VERSION`）
- マップはあとからブラウザ上の **マップエディター**で編集可能

---

## 必要なもの

| 項目 | 内容 |
|------|------|
| OS | Linux（Ubuntu / Debian 等。Docker が動けば可） |
| Docker | Docker Engine + Docker Compose v2（`docker compose` コマンド） |
| スペック目安 | 2 CPU / 4GB RAM 程度（〜300人規模） |
| ネットワーク | 後述の「公開方法」によって異なる |

Docker 未インストールの場合:

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker "$USER"   # 一度ログインし直す
```

---

## クイックスタート（3ステップ）

```bash
# 1. クローン
git clone <このリポジトリのURL> Himatsudo.WorkAdventure
cd Himatsudo.WorkAdventure

# 2. 初期セットアップ（.env 作成 & 秘密鍵の自動生成）
./setup.sh

# 3. 起動
./start.sh
```

`./start.sh` はイメージ取得からバックグラウンド起動まで自動で行います。
初回は証明書取得やコンテナ初期化で数分かかることがあります。

起動後、`https://<DOMAIN>/` にアクセスします。

> **メモ:** `./start.sh` は `.env` が無ければ自動で `./setup.sh` を呼びます。
> つまり最短では **`git clone` → `./start.sh`** だけでも動きます。
> ただし公開ドメイン運用では先に `.env` の `DOMAIN` / `ACME_EMAIL` 設定が必要です（下記）。

---

## 公開方法を決める（重要）

WorkAdventure は音声・ビデオ（WebRTC）のために **HTTPS + 有効な証明書**が前提です。
自宅サーバーでは「どうやって HTTPS でアクセスするか」を最初に決めます。
`.env` の `DOMAIN` を変えるだけで切り替えられます。

### A. 独自ドメイン ＋ Let's Encrypt（インターネット公開）

最も標準的な構成です。

1. ドメイン（例 `wa.example.com`）の DNS A レコードを自宅サーバーのグローバル IP に向ける
2. ルーターで **ポート 80 / 443**（必要なら 50051）をサーバーへポート開放
3. `.env` を編集:
   ```ini
   DOMAIN=wa.example.com
   ACME_EMAIL=you@example.com
   ```
4. `./start.sh`

Traefik が自動で Let's Encrypt 証明書を取得します。

### B. ローカル検証のみ（LAN 内 / まず動かす）

ポート開放や DNS なしで、まず動作確認したい場合。

- `.env` の `DOMAIN=workadventure.localhost`（既定値）のまま `./start.sh`
- 証明書は Traefik の自己署名になるため、ブラウザの警告を許可して進みます
- WebRTC（ビデオ）はブラウザの制限で一部動かないことがあります

> LAN 内の他端末からアクセスしたい場合は、`workadventure.localhost` の代わりに
> 実 IP やローカル DNS 名を使い、各端末の hosts でその名前をサーバー IP に向けてください。
> （正規のビデオ通話には A の独自ドメイン構成を推奨します）

### C. ポート開放できない場合（Cloudflare Tunnel など）

ルーターを触れない・固定 IP が無い場合は、Cloudflare Tunnel や Tailscale Funnel 等で
外部に HTTPS 公開し、トンネルの転送先をこのサーバーの 80 番に向ける方法もあります。
その場合 `.env` の `DOMAIN` は公開ドメインに設定します（証明書はトンネル側で終端するため
Traefik 側はそのままで構いません）。

---

## マップの編集（あとから）

1. 起動後 `https://<DOMAIN>/` に入室
2. メニューから **マップエディター**を開く（`ENABLE_MAP_EDITOR=true` で有効化済み）
3. 保存時に map-storage の認証を求められたら、`./setup.sh` 実行時に表示された
   **ユーザー名 / パスワード**を入力

詳しくは [`maps/README.md`](./maps/README.md) を参照してください。

---

## よく使うコマンド

| やりたいこと | コマンド |
|--------------|----------|
| 起動 | `./start.sh` |
| 停止（データ保持） | `./stop.sh` |
| ログ表示 | `./logs.sh` または `./logs.sh play` |
| 状態確認 | `docker compose ps` |
| 更新（pull + 再起動） | `./update.sh` |
| 設定変更の反映 | `.env` を編集 → `./update.sh` |

---

## ファイル構成

```
.
├── docker-compose.yaml   WorkAdventure 一式の Compose 定義（公式 prod ベース）
├── .env.template         設定テンプレート（コミット対象）
├── .env                  実際の設定（秘密鍵入り・自動生成、git 管理外）
├── setup.sh              初期セットアップ（.env 作成・秘密鍵生成）
├── start.sh              起動
├── stop.sh               停止
├── logs.sh               ログ表示
├── update.sh             更新
└── maps/                 マップ運用メモ置き場
```

`.env` と `wa/`（証明書などの永続データ）は秘密情報を含むため `.gitignore` 済みです。

---

## トラブルシュート

- **証明書が取得できない / HTTPS エラー**
  → DNS が正しくサーバーを指しているか、ポート 80 が外部から到達できるか確認。
  テスト中は Let's Encrypt のレート制限を避けるため、`docker-compose.yaml` 内の
  ステージング用 `caserver` 行のコメントを外すと安全です。
- **ビデオ・音声がつながらない**
  → HTTPS が有効か確認。自宅 NAT 環境では `.env` の `TURN_SERVER` 設定を推奨。
- **ポート 80/443 が既に使用中**
  → 他の Web サーバーを止めるか、`.env` の `HTTP_PORT` / `HTTPS_PORT` を変更。
- **コンテナの状態を見たい** → `docker compose ps` と `./logs.sh`

---

## 参考

- 公式サイト: https://workadventu.re/
- セルフホスティング: https://docs.workadventu.re/admin/getting-started/self-hosting/
- マップ作成: https://docs.workadventu.re/map-building/
- GitHub: https://github.com/workadventure/workadventure
