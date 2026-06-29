# maps ディレクトリ

このディレクトリは、自前のマップを管理するための置き場所です。

WorkAdventure のマップ本体は、起動後は **map-storage コンテナ内**
（Docker ボリューム `map-storage-data`）に保存されます。
そのため、ここに置いたファイルが自動的に反映されるわけではありません。

## マップの編集・追加方法（あとから実施）

WorkAdventure 起動後、ブラウザから直接編集できます。

1. `https://<あなたのDOMAIN>/` にアクセスして入室する
2. 画面のメニューから **マップエディター（Map Editor）** を開く
   - `.env` の `ENABLE_MAP_EDITOR=true` で有効化済みです
3. 編集を保存する際、map-storage の認証を求められたら
   `./setup.sh` 実行時に表示された **ユーザー名 / パスワード** を入力する
   （`.env` の `MAP_STORAGE_AUTHENTICATION_USER` / `MAP_STORAGE_AUTHENTICATION_PASSWORD`）

## 自作マップ（Tiled）を最初のマップにしたい場合

1. [map-starter-kit](https://github.com/workadventure/map-starter-kit) を使ってマップを作成
2. map-storage へアップロード（WAM 形式に変換されます）
3. `.env` の `START_ROOM_URL` を `/~/<アップロードしたマップ名>.wam` に変更
4. `./update.sh`（または `./stop.sh && ./start.sh`）で再起動

詳細は公式ドキュメントを参照してください:
https://docs.workadventu.re/map-building/
