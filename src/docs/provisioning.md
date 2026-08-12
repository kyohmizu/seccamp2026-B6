# プロビジョニング手順

単一の Google Cloud（GCP）プロジェクト内に、参加者分の演習環境（Cloud Run・Artifact Registry・サービスアカウント等）を Terraform を用いて一括構築し、動作検証を経て参加者へ配布するまでの運用管理手順です。環境数（`app_count`）と GitHub 連携情報（`github_owner` / `connection_name` / `npm_registry`）を指定することで、各参加者のリポジトリ `<github_owner>/seccamp2026-B6-app-NN` に対するビルド・デプロイのトリガーまで含めて全環境を自動生成できます。各環境は連番の識別キーによって分離・管理されます。設計背景の詳細は [../infra/README.md](../infra/README.md) を参照してください。

> Terraform によるインフラ定義（`infra/`）は運用管理者が実行する環境構築ツールです。参加者は Terraform の直接操作は行わず、用意された初期状態に対して `gcloud` コマンドや設定ファイルの編集を行い、セキュリティの堅牢化を進めます。
> 参加者アカウントに対する GCP プロジェクトへのアクセス権限付与作業は本手順の対象外です。事前のアカウント準備フェーズにて実施してください。

補助スクリプト類は [../infra/scripts/](../infra/scripts/) に配置されています。すべてのスクリプト実行は `src/infra` ディレクトリ直下で行います。

## 前提条件
- 課金（billing）が有効化された GCP プロジェクトを1つ用意してください。
- 実行環境で `gcloud` の認証が完了しており、対象プロジェクトに対して `serviceusage`・`run`・`artifactregistry`・`iam` 等の各種 API 操作権限を有していることを確認してください。
- Terraform のバージョンは mise を用いて `terraform@1.15.7` に固定しています（`infra/mise.toml`）。以降の `terraform` コマンドは `mise exec -- terraform` としても実行可能です。
- Python3 環境（`terraform output` の実行結果整形処理に使用します）。
- 演習用 npm レジストリ（Verdaccio）。frontend の依存関係である `expense-format`（公開 npm には存在しない自作 OSS）を供給するためのプライベートレジストリです。ステップ2 にて構築します。本レジストリが存在しない場合、frontend のビルド処理が失敗します。
- GitHub の host connection（Cloud Build 2nd-gen）。参加者リポジトリへのトリガーを作るために、対象プロジェクトごとに gcloud で1回だけ作成・OAuth 認可しておきます（手順は付録「GitHub トリガーによる自動ビルドパイプラインの構築」を参照）。`app_count` のループはこの接続（`connection_name`）を全 env 共通で使用します。

## ステップ1: tfvars ファイルの準備
`terraform.tfvars` に対象プロジェクト ID および生成する環境数を記述します。
```bash
cd src/infra
cp terraform.tfvars.example terraform.tfvars
```
```hcl
google_project  = "<GCPプロジェクトID>"
app_count       = 10                   # app-01〜app-10 の環境を生成する
github_owner    = "<GitHub owner>"     # 個人アカウント名 or 組織名
connection_name = "flowpay-github"     # 前提条件で作成した host connection 名
npm_registry    = "http://<IP>:4873/"  # ステップ2 で取得する Verdaccio URL（確定後に記入）
```
演習環境（`app-01`〜）は、対象リポジトリ `<github_owner>/seccamp2026-B6-app-NN` へのトリガーまで含めて Terraform により自動生成されます。`npm_registry` の IP はステップ2 の Verdaccio 構築後に確定するため、値が決まってから記入します。環境ごとに個別のカスタマイズ設定が必要な場合は、`app_count = 0` と設定した上で `environments` を明示的に定義します（詳細は付録を参照）。

## ステップ2: 演習用 npm レジストリの構築（シードビルド前に必須）
frontend アプリケーションは公開 npm に存在しない自作 OSS `expense-format` に依存しています。このパッケージを供給する Verdaccio を Compute Engine（GCE）VM 上に構築します。構築手順の詳細は [../demos/malicious-dependency/gce/README.md](../demos/malicious-dependency/gce/README.md) を参照してください。
```bash
PROJECT=<GCPプロジェクトID> ZONE=asia-northeast1-b src/demos/malicious-dependency/gce/provision.sh
# 出力される「レジストリ URL: http://<IP>:4873/」の値を記録しておきます
REG=http://<IP>:4873/ src/demos/malicious-dependency/gce/publish.sh good
```
ここで取得した URL は ステップ4 における `NPM_REGISTRY` 環境変数として渡します。
> レジストリ URL（VM の IP アドレス）は環境固有であるため Git リポジトリへはコミットしないでください。VM を再作成すると IP が変更されます。固定の静的 IP アドレスを事前に予約・割り当てておくことで、再作成時も同一の URL を維持できます。

## ステップ2.5: frontend 用ロックファイルの作成（演習リポジトリへのコミット）
実稼働アプリケーションと同様に `package-lock.json` を作成して Git にコミットします。本ファイルは公開の元リポジトリには含めず（`resolved` フィールドにレジストリの IP アドレスが記録されるため）、演習環境を準備する本工程で生成・コミットを行います。
```bash
( cd src/frontend && npm install --package-lock-only --omit=dev --registry http://<IP>:4873/ )
# .gitignore から src/frontend/package-lock.json の行を除外してコミット
git add src/frontend/package-lock.json
git commit -m "chore: commit frontend lockfile (expense-format 1.0.0)"
```
> 攻撃デモ演習では、この lockfile に対し `npm update` を実行して悪性バージョンへ更新し、PR を作成するシナリオを実施します（[../demos/malicious-dependency/gce/README.md](../demos/malicious-dependency/gce/README.md)）。

## ステップ3: インフラの適用（apply）
```bash
terraform init
terraform plan     # 作成される環境（env）の数を確認します
terraform apply
terraform output environments   # 各環境の URL・AR パス・SA・サービス名等が出力されます
```
各環境（env）ごとに、API の有効化、Artifact Registry、サービスアカウント2個、Cloud Run サービス2基（private 設定）、および IAM ポリシーが自動生成されます。初期状態では Binary Authorization が有効化されていないため、未検証のコンテナイメージもデプロイ可能な非堅牢な状態となります。デプロイ時の検証メカニズムは 演習05 にて有効化します。
> Binary Authorization ポリシーは GCP プロジェクト単位のシングルトンリソースです。単一プロジェクトを全参加者で共有する構成の場合、演習05 はプロジェクト全体の共通演習として扱われます（参加者単位の独立した制御状態は保持できません）。演習05 の検証完了後は、共有環境のデプロイをブロックし続けないようポリシーを `ALWAYS_ALLOW` へ復元してください。

## ステップ4: 初期コンテナイメージの投入（シードビルド）
`terraform apply` 直後の Cloud Run サービスにはプレースホルダー用の初期イメージが配置されているため、実際のアプリケーションイメージをビルドしてデプロイします。`NPM_REGISTRY` には ステップ2 で取得したレジストリ URL を指定します。
```bash
NPM_REGISTRY=http://<IP>:4873/ scripts/seed-builds.sh              # 全環境に対してビルド・push・Cloud Run の更新を実行
# NPM_REGISTRY=http://<IP>:4873/ scripts/seed-builds.sh app-01  # 特定環境のみ実行する場合
```

## ステップ5: 動作検証（スモークテスト）
```bash
scripts/smoke-test.sh              # 各環境の frontend UI および frontend→backend 間通信を proxy 経由で検証
```
すべての環境において `GET / -> 200` および `GET /api/expenses -> 200` の正常応答が返ることを確認します。

## ステップ6: 参加者への配布
`terraform output -json environments` の出力結果をベースに、各参加者に対して以下の情報を案内・配布します。
- frontend / backend へのアクセス確認手順（`gcloud run services proxy` コマンドによるアクセス案内。外部インターネットへは公開しません）。
- 対象 Artifact Registry のリポジトリパス。
- 演習ハンズオンの案内ドキュメント（[../../chapter3/exercises/README.md](../../chapter3/exercises/README.md)）。

## リソースのクリーンアップ手順
Terraform の管理対象リソース（Artifact Registry、サービスアカウント、Cloud Run、IAM、およびトリガー方式の場合はリポジトリ・トリガー）を削除します。
```bash
terraform destroy
```
Terraform の管理外リソースについては個別に手動削除を行います。
```bash
# 演習用レジストリ用 VM（課金対象リソースのため削除漏れに注意）
PROJECT=<GCPプロジェクトID> ZONE=asia-northeast1-b src/demos/malicious-dependency/gce/teardown.sh
# 攻撃者用 C2 受信サーバー用 VM（同上）
PROJECT=<GCPプロジェクトID> ZONE=asia-northeast1-b src/demos/malicious-dependency/gce/attacker/teardown.sh
```
- **Binary Authorization**: 演習05 で有効化した場合、ポリシー設定はプロジェクト単位の管理であり Terraform 管理外となります。共有プロジェクトの場合はポリシーを `ALWAYS_ALLOW` へ手動復元してください。
- **GitHub host connection**（トリガー方式採用時）: `gcloud builds connections create` コマンドで作成した接続定義は Terraform 管理外です。完全に削除する場合は `gcloud builds connections delete <接続名> --region <リージョン名>` を実行します。
- **ローカルの生成物**: 手元環境の `terraform.tfvars`・`src/frontend/.npmrc`・`.terraform/` ディレクトリ・tfstate ファイルを削除します。
- 有効化した API 群は `destroy` 実行時も無効化されません（`disable_on_destroy = false`）。参加者ごとに別プロジェクトを割り当てる運用の場合、GCP プロジェクトごと削除するのが最も確実に全削除（API・ビルド履歴・ログ等を含む）を行える方法です。

## 付録: 発展的な運用設計
### GitHub トリガーによる自動ビルドパイプラインの構築
コードの push 操作を契機として自動ビルドを実行する構成を構築する手順です。まず、GitHub host connection を作成します。なお、OAuth 認可手続きのためにブラウザ操作が必要となります。
```bash
gcloud builds connections create github flowpay-github --region asia-northeast1
# 出力結果に含まれる actionUri の URL をブラウザで開き、Cloud Build GitHub App に対する対象リポジトリへのアクセスを認可します
```
`terraform.tfvars` 内の該当環境定義（`environments`）に対して `github_owner` / `github_repo` / `connection_name` を設定した上で `terraform apply` を実行すると、リポジトリ連携と**3つのビルドトリガー**が自動生成されます（`main` ブランチへの push を検知する build＋AR push トリガー、`pull_request` イベントを検知する PR チェックトリガー、および **Pub/Sub 経由の deploy トリガー**（イメージの push を契機に Cloud Run へ反映。build 用とは異なる専用の deploy SA で実行））。PR チェックトリガーは、攻撃デモにおいて「更新 PR の作成時にマージ前の段階で CI ランナー上で悪性依存関係が実行される」挙動を実演するために使用します（不要な場合は `enable_pr_check = false` と設定）。トリガー実行時に frontend のビルド処理が `expense-format` を正常に解決できるよう、`substitutions = { _NPM_REGISTRY = "http://<IP>:4873/" }` の環境変数定義も併せて設定します。接続の新規作成時や初回ビルド実行時には P4SA 権限の浸透遅延により権限エラーが発生する場合があります。その場合は数分待機した後に再実行してください。

**deploy トリガーの追加設定**（イベント配線は実環境で挙動を確認しながら設定します）:
- **Artifact Registry への push イベントを Pub/Sub 通知**へ発行し、`<repo>-image-pushed` トピック宛に送信するよう設定します（`gcloud artifacts` の通知機能および Eventarc を利用）。この通知配線設定は Terraform 管理外となります。
- Cloud Build の P4SA に対して、deploy SA への `roles/iam.serviceAccountTokenCreator` ロールを付与します（トリガーが deploy SA 権限で実行されるため。build SA と同様の設定が必要です）。
- 初期状態における deploy トリガーの動作は**検証処理なし**の構成となっています。attestation 検証ステップの追加（パイプライン内チェック）および Binary Authorization によるデプロイ時強制検証については演習コンテンツ内で扱います。

### 環境ごとに設定を変更する手法（環境明示モード）
参加者ごとに別プロジェクトを割り当てる構成、参加者ごとに個別リポジトリを割り当てる構成、または個別にアクセス権限を管理する運用を行う場合は、`app_count = 0` と設定した上で `environments` ブロックを `terraform.tfvars` ファイルへ直接記述します。設定記述のフォーマット例は [terraform.tfvars.example](../infra/terraform.tfvars.example) を参照してください。`members` に定義されたアカウントに対しては、frontend の `run.invoker` ロール（proxy 閲覧権限）が自動付与されます。個別プロジェクト構成を採る場合は、各環境定義内の `project_id` を環境ごとに変更します。参加者ごとの個別リポジトリを作成する場合は [make-student-repo.sh](../infra/scripts/make-student-repo.sh) スクリプトを用いてリポジトリ内容を生成します。
