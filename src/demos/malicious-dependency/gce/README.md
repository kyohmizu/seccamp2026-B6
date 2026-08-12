# 演習環境版: GCE 上の Verdaccio と攻撃者 C2

実環境デモ（GitHub → Cloud Build → Cloud Run）で用いる **Verdaccio（公開 npm レジストリの代役）と攻撃者用 C2 サーバーの構築・破棄**をまとめます。frontend が直接依存する `expense-format` を本環境から配信します。攻撃の解説と**実演コマンド**（悪性版の publish・依存更新 PR・C2 受信確認・マージ・復旧）は [攻撃デモの解説](../../../../chapter1/attack-demo.md) を参照してください。本ドキュメントは環境のプロビジョニングとリソース削除に限定します。

## Compute Engine（GCE）VM 上に構築する理由
- **認証情報を付与しない構成の実現**: OSS パッケージを外部レジストリから取得する通常の利用形態を再現するため、npm クライアントは認証なしで対象レジストリ URL へアクセスする設計としています。
- **アクセス制御の最適化**: **VM のファイアウォールルールにおいて、送信元 IP アドレスを Google の公開 IP レンジのみに限定**するアクセス制限を適用します（インターネット全体には公開しない制限措置）。Cloud Build からのアウトバウンド（egress）通信は Google の IP レンジから送出されるため、正常に到達可能です。
- Cloud Run は単体での IP 制限機能を有しておらず、HTTP(S) Load Balancing と Cloud Armor の組み合せが必要となるため、IP アドレスによる送信元制限を行う用途においては VM のファイアウォール機能の活用が適しています。

## 構成ファイル一覧
- `config.yaml` … Verdaccio の設定定義（`expense-format` はローカル処理、その他は npmjs レジストリへプロキシ、匿名パブリッシュを許可）
- `startup.sh` … Container-Optimized OS（COS）VM の起動スクリプト（メタデータ設定に基づき Verdaccio コンテナを起動。ストレージ領域はホスト側へ永続化）
- `provision.sh` … VM インスタンスの作成および Google IP レンジのみを許可するファイアウォールルールの作成スクリプト
- `publish.sh good|evil` … レジストリに対して正規版（`1.0.0`）または悪性版（`1.0.1`）をパブリッシュするスクリプト
- `teardown.sh` … VM インスタンスおよびファイアウォールルールを削除するクリーンアップスクリプト
- `attacker/` … 攻撃者の受信用 C2 サーバー関連ファイル一式（`provision.sh` / `server.js` / `teardown.sh`。詳細は [attacker/README.md](attacker/README.md) を参照）

## 初期構築手順
各演習環境において初回に1度だけ実行します。基盤構築全体の流れについては [../../../docs/provisioning.md](../../../docs/provisioning.md) の ステップ2〜4 を参照してください。要点のみ以下に再掲します（記載パスはリポジトリルートを基準とします）。

```bash
# 1) レジストリを構築し、正規バージョンのパッケージをパブリッシュ（※ VM の作成により課金が発生します）
PROJECT=YOUR_PROJECT ZONE=asia-northeast1-b src/demos/malicious-dependency/gce/provision.sh
#    出力される「レジストリ URL: http://<IP>:4873/」の値を記録しておきます
REG=http://<IP>:4873/ src/demos/malicious-dependency/gce/publish.sh good

# 2) 演習用リポジトリに frontend のロックファイルを生成してコミット（正規バージョン 1.0.0 に固定）
#    ※ 公開・オーサリング用の元リポジトリにはコミットしないでください（lockfile の resolved 属性に
#      レジストリの IP アドレスが記録されるため）。演習環境を準備する本工程にて含めます。
( cd src/frontend && npm install --package-lock-only --omit=dev --registry http://<IP>:4873/ )
#    .gitignore から src/frontend/package-lock.json の行を除外してからコミットします:
git add src/frontend/package-lock.json
git commit -m "chore: commit frontend lockfile (expense-format 1.0.0)"

# 3) _NPM_REGISTRY の配線（利用する実行方式に合わせて以下のいずれかを設定）
#    - トリガー利用時 (push/PR): 各環境の tfvars に substitutions = { _NPM_REGISTRY = "http://<IP>:4873/" } を定義し terraform apply
#    - 手動実行時 (seed-builds): 実行時に NPM_REGISTRY=http://<IP>:4873/ を環境変数として指定

# 4) アプリケーションをデプロイして動作検証（frontend が正規版 1.0.0 を解決し、npm ci が lockfile 通りに導入することを確認）
NPM_REGISTRY=http://<IP>:4873/ src/infra/scripts/seed-builds.sh
```
> **実行順序の重要性**: frontend アプリケーションは公開 npm に存在しない `expense-format` に依存しているため、レジストリを立ち上げて `_NPM_REGISTRY` を配線するまで frontend のビルドは正常に完了しません。必ず `seed-builds` やトリガー実行の前に本手順を完了させてください。
> **ロックファイルのコミット前提**: 実アプリケーションと同様に演習用リポジトリには lockfile を含めた状態とします。本攻撃手法は依存関係の更新操作を契機として侵入します（詳細は [攻撃デモの解説](../../../../chapter1/attack-demo.md) を参照）。

攻撃者用の受信用 C2 サーバーについても同様に事前構築を行います。
```bash
PROJECT=YOUR_PROJECT src/demos/malicious-dependency/gce/attacker/provision.sh
#    出力される C2 受信 URL（http://<attackerIP>:9099/steal）を記録しておきます（publish evil 実行時に埋め込みます）
```

> デモの実演（悪性版 publish → 依存更新 PR → C2 受信確認 → マージ → 復旧）の手順とコマンドは [攻撃デモの解説 の「実環境での攻撃デモ（手順と結果）」](../../../../chapter1/attack-demo.md#実環境での攻撃デモ手順と結果) を参照してください。

## クリーンアップ（リソース削除）
```bash
# レジストリ用 VM インスタンスの削除
PROJECT=YOUR_PROJECT ZONE=asia-northeast1-b src/demos/malicious-dependency/gce/teardown.sh
# 攻撃者 C2 サーバー用 VM インスタンスの削除
PROJECT=YOUR_PROJECT ZONE=asia-northeast1-b src/demos/malicious-dependency/gce/attacker/teardown.sh
```

## 注意事項
- 演習用レジストリ通信は HTTP 通信（暗号化なし）で動作します。デモ検証用途に限定して使用し、機密情報は絶対に配置しないでください。
- ファイアウォールルールによるアクセス制御は Google の IP レンジ全体を対象としており、Cloud Build 専用に完全特定された制限ではありません。演習期間中のみ起動し、終了後は速やかに `teardown.sh` を実行してリソースを削除してください。
