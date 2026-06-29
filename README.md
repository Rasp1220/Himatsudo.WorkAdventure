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
`.env` の `DOMAIN`（と `COMPOSE_FILE`）を変えるだけで切り替えられます。

| 方法 | ポート開放 | TLS 終端 | 向いているケース |
|------|:--------:|---------|------------------|
| **VPS 玄関（推奨）** | 不要 | VPS | 自宅でポート開放できない／固定 IP が無い。自前の VPS とドメインがある |
| A. 独自ドメイン+LE | 必要(80/443) | 自宅 | 自宅でポート開放できる |
| B. ローカル検証 | 不要 | 自己署名 | まず LAN 内で動作確認したい |
| C. Cloudflare Tunnel | 不要 | Cloudflare | VPS を持たず Cloudflare を使う |

### ★ VPS を玄関（リバースプロキシ）にして公開する【推奨】

自宅でポート開放できない場合の本命構成です。VPS を玄関にして HTTPS を終端し、
**Tailscale** トンネル越しに自宅の WorkAdventure へ転送します。自宅は受信ポート開放不要です。

```
利用者 ──https://wa.example.com（DNS→VPSのグローバルIP）──▶  VPS(玄関)
                                                            Traefik: Let's Encrypt で TLS 終端
                                                            │ Tailscale(100.x)で自宅へ
                                                            ▼ http://<自宅のTailscale IP>:80
                                                          自宅サーバー: WorkAdventure 一式
                                                            Traefik は素のHTTP :80 で配信（ACMEなし）
```

> **⚠️ DNS の A レコードには VPS の「グローバル IP」を設定します。**
> Tailscale の内部 IP（`100.x`）はトンネル内専用で外から繋がりません。
> 内部 IP は「VPS が自宅へ転送するときだけ」使います。

自宅側はルートの `.env` を次のようにして起動するだけです。

```ini
DOMAIN=wa.example.com   # VPS に向けた公開ドメイン（A レコードは VPS のグローバルIP）
ACME_EMAIL=             # TLS は VPS が終端するので空でOK
COMPOSE_FILE=docker-compose.yaml:docker-compose.behind-proxy.yaml
```

```bash
./start.sh
```

VPS 側の構築（Tailscale トンネルと Traefik 玄関）と全体の設定順序は
**[`vps/README.md`](./vps/README.md)** に手順をまとめています。

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

### C. Cloudflare Tunnel で公開する（ポート開放不要・無料）

ルーターのポート開放ができない / 固定 IP が無い場合におすすめです。Cloudflare が
HTTPS を終端し、サーバーからアウトバウンド接続するトンネルで公開します。

このリポジトリには専用のオーバーレイ設定 `docker-compose.cloudflare.yaml` を同梱しており、
有効化すると `cloudflared` コンテナが追加され、Traefik は Let's Encrypt を使わず
:80 で配信する構成に切り替わります。

**前提:** 独自ドメイン（例 `example.com`）を Cloudflare に追加し、ネームサーバーを
Cloudflare に向けてある（＝フルセットアップ。無料プランで可）こと。

1. **トンネルを作成**（Cloudflare Zero Trust ダッシュボード → Networks → Tunnels）
   - 「Cloudflared」タイプでトンネルを作成し、表示される **トークン**を控える
2. **公開ホスト名を設定**（同トンネルの Public Hostnames）
   - Subdomain: `wa` / Domain: `example.com`（→ `wa.example.com`）
   - Service: **`HTTP`** / URL: **`reverse-proxy:80`**
   - これで `wa` の CNAME レコードが自動作成されます（手動追加不要）
3. **`.env` を編集**
   ```ini
   DOMAIN=wa.example.com
   # 次の2つのコメントを外す/設定する
   COMPOSE_FILE=docker-compose.yaml:docker-compose.cloudflare.yaml
   CLOUDFLARE_TUNNEL_TOKEN=<手順1で控えたトークン>
   ```
4. **起動**
   ```bash
   ./start.sh
   ```

`https://wa.example.com/` でアクセスできます（ACME_EMAIL は不要）。

> **音声・画面共有について（重要）**
> Cloudflare Tunnel は HTTP/HTTPS のみで、WebRTC の UDP 中継は通しません。
> - **会議室（Jitsi エリア）** … 外部 Jitsi に直接つながるため、そのまま会話・画面共有できます。TURN 不要。
> - **近接の会話・画面共有（人に近づくと開くバブル）** … ブラウザ間 P2P のため **TURN が必要**です。
>   `.env` には無料の公開 TURN（Open Relay Project, 443/TCP・TLS 対応）を既定で設定済みなので、
>   そのままでも中継されます（無料枠は月20GB）。本格運用では自前 TURN への変更を推奨します。
>
> カメラ映像（ビデオ）が不要な場合は、入室時やツールバーでカメラを OFF にすれば、
> 音声と画面共有だけで利用できます（設定変更は不要）。

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
├── docker-compose.yaml            WorkAdventure 一式の Compose 定義（公式 prod ベース）
├── docker-compose.cloudflare.yaml Cloudflare Tunnel 公開用オーバーレイ（任意）
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
