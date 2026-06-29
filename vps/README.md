# VPS(玄関) リバースプロキシ

自宅サーバーの WorkAdventure を、**VPS を玄関(リバースプロキシ)** にして
インターネット公開するための一式です。自宅は受信ポート開放不要で、
VPS ⇄ 自宅 を **Tailscale** でつなぎます。

```
利用者 ──https://wa.example.com（DNS→VPSのグローバルIP）──▶  VPS(このディレクトリ)
                                                            Traefik: Let's Encrypt で TLS 終端
                                                            │ Tailscale(100.x)で自宅へ
                                                            ▼ http://<自宅のTailscale IP>:80
                                                          自宅サーバー: WorkAdventure 一式
                                                            Traefik は素のHTTP :80 で配信（ACMEなし）
```

- VPS 側は「DOMAIN 宛を丸ごと自宅 Traefik(:80) へ流すだけ」のシンプルな構成です。
  `/ws/`・`/api`・`/map-storage` などの振り分けは自宅 Traefik がそのまま処理します
  （WebSocket もそのまま透過します）。

> ## ⚠️ DNS に入れる IP を間違えないこと
>
> 公開ドメイン `wa.example.com` の **A レコードには VPS の「グローバル IP」** を設定します。
> Tailscale が割り当てる内部 IP（`100.x.x.x`）は自分のトンネル内だけの私設 IP で、
> インターネットからは繋がりません。**内部 IP は「VPS が自宅へ転送するときだけ」使う**もので、
> DNS には設定しません。

---

## 必要なもの

| 項目 | 内容 |
|------|------|
| VPS | グローバル IP を持つ Linux サーバー（Docker が動くこと） |
| ドメイン | 公開ドメイン（例 `wa.example.com`）の A レコードを VPS のグローバル IP に向ける |
| 開放ポート | VPS で **TCP 80 / 443**（HTTPS）のみ（Tailscale が NAT 越えを自動処理するため他は不要） |
| 自宅サーバー | リポジトリ同梱の WorkAdventure 一式（後述の overlay で起動） |

---

## 設定順序

### STEP 0｜ドメイン DNS（お名前.com 等）

`wa` の **A レコード → VPS のグローバル IP** を登録します（反映に数分〜数十分）。

| ホスト名 | 種別 | VALUE |
|----------|------|-------|
| `wa` | A | VPS のグローバル IP |

### STEP 1｜VPS でこのリポジトリを clone

```bash
git clone <このリポジトリのURL> Himatsudo.WorkAdventure
cd Himatsudo.WorkAdventure/vps

# Docker（未導入なら）
curl -fsSL https://get.docker.com | sh
```

VPS のファイアウォール / セキュリティグループで **TCP 80, 443** を開放してください。

### STEP 2｜Tailscale を「VPS と 自宅 の両方」に入れる

```bash
# VPS・自宅サーバー それぞれで実行
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up        # ブラウザで同じアカウントにログイン → 同じネットワークに参加

# 自宅サーバーで内部IPを確認（これを VPS の転送先に使う）
tailscale ip -4          # 例: 100.101.102.103
```

疎通確認（VPS → 自宅）:

```bash
ping -c3 100.101.102.103
```

> 自宅サーバーで他の用途に使っている既存の Tailscale IP を、そのまま WA にも使えます
> （IP は同じでもポートで区別されるため干渉しません。VPS は :80 だけを転送します）。

### STEP 3｜自宅サーバーで WorkAdventure を「玄関の背後」モードで起動

リポジトリのルート（自宅サーバー側）の `.env`:

```ini
DOMAIN=wa.example.com    # VPS に向けた公開ドメイン
ACME_EMAIL=              # TLS は VPS が終端するので空でOK
COMPOSE_FILE=docker-compose.yaml:docker-compose.behind-proxy.yaml
```

```bash
./setup.sh     # 初回のみ（秘密鍵生成）
./start.sh
```

### STEP 4｜VPS で玄関(Traefik)を起動

`vps/.env.vps`:

```ini
DOMAIN=wa.example.com
ACME_EMAIL=you@example.com      # Let's Encrypt 通知用（必須）
HOME_TS_IP=100.101.102.103      # ← STEP2 で確認した自宅の Tailscale IP
```

```bash
./setup-vps.sh      # .env.vps を作成/反映
./start.sh
```

### STEP 5｜確認

`https://wa.example.com/` を開きます（初回は Let's Encrypt の証明書取得で数十秒）。

---

## 音声・画面共有について

- **会議室（Jitsi エリア）** … 外部 Jitsi に直接つながるため、そのまま会話・画面共有できます。
- **近接の会話・画面共有（人に近づくと開くバブル）** … ブラウザ間 P2P です。NAT 環境では
  中継に TURN が必要になる場合があります。必要になったら、VPS は公開 IP を持つので
  coturn を建てて自前 TURN にするのが確実です（ルートの `.env` の `TURN_*` を設定）。

---

## よく使うコマンド（VPS 側）

| やりたいこと | コマンド |
|--------------|----------|
| 玄関の起動 | `./start.sh` |
| 玄関の停止 | `./stop.sh` |
| ログ表示 | `./logs.sh` |
| トンネル状態 | `tailscale status` |
| 設定変更の反映 | `.env.vps` 編集 → `./setup-vps.sh` → `./start.sh` |

---

## トラブルシュート

- **証明書が取得できない / HTTPS エラー**
  → `wa` の A レコードが VPS の**グローバル IP**を指しているか、VPS の TCP 80/443 が
  開いているか確認。テスト中は `docker-compose.yaml` 内のステージング用 `caserver`
  行のコメントを外すとレート制限を避けられます。
- **502 / 504（バックエンドに届かない）**
  → VPS から `ping <自宅の Tailscale IP>` が通るか、`.env.vps` の `HOME_TS_IP` が正しいか、
  自宅側が `docker-compose.behind-proxy.yaml` 付きで起動して :80 を配信しているか確認。
- **トンネルがつながらない**
  → VPS・自宅の両方で `tailscale status` が `active`／相手のデバイスが見えているか確認。
