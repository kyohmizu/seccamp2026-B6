# FlowPay 環境（共有）

仮想企業 PayLoad の経費精算サービス「FlowPay」の各種実装コード一式です。第1章におけるデモ、第2章における解説の題材、および第3章のハンズオン演習において共通で使用します。

## 構成
- `backend/` — Go 言語で実装された経費精算 API。非公開（private）設定の Cloud Run サービスとして動作します（frontend からのアクセスのみを許可）。
- `frontend/` — Node.js / Express で構築された Web UI。金額の整形処理は外部 OSS パッケージ `expense-format` に依存しています。
- `pipelines/` — Cloud Build のパイプライン定義（ビルド / PR チェック / デプロイ）。
- `infra/` — Terraform によるインフラストラクチャ定義（Artifact Registry / Cloud Run 2サービス / Binary Authorization / IAM / source-trigger モジュール）。
- `demos/` — サプライチェーン攻撃の実演環境・スクリプト（悪性の依存パッケージによる CI 環境侵害のシミュレーション）。
- `docs/` — ハンズオン環境の構築手順書（運用者・管理者向け）。

## 環境構築（運用者・管理者向け）
- ハンズオン環境のプロビジョニングから参加者への配布手順（単一環境を構築する場合は `app_count = 1` に設定）: [docs/provisioning.md](docs/provisioning.md)
- 攻撃デモ用演習環境の構築（Compute Engine（GCE）上のプライベート npm レジストリおよび攻撃者用受信サーバー）: [demos/malicious-dependency/gce/](demos/malicious-dependency/gce/)

## 注意事項
- 各 Cloud Run サービスは非公開（private）設定となっており、外部インターネットへ直接公開はされません。ローカル環境からの動作確認を行う際は、`gcloud run services proxy` コマンドを経由してアクセスしてください。
- 攻撃デモに含まれる悪性コードは安全性を担保したシミュレーション用の構成です（実際に悪用可能な認証情報の窃取や、機密情報の外部送信などの攻撃的動作は行いません）。
