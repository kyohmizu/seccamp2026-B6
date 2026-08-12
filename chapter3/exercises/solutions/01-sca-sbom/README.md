# 解答: SCA / SBOM

- [cloudbuild.yaml](./cloudbuild.yaml) — **課題4の組み込み版**。baseline のビルドパイプラインに対して Trivy によるスキャンステップ（SCA / コンテナイメージスキャン / SBOM 生成）を追加した構成です。参加者用リポジトリの `cloudbuild.yaml` を本ファイルの内容に差し替えることで、既存の push トリガー（`<repo>-push`）が自動起動し、**push のたびに自動でスキャン結果が出力**されます。SCA は push 直前、イメージスキャンおよび SBOM 生成は push 直後に配置されています。
- [cloudbuild.scan.yaml](./cloudbuild.scan.yaml) — **単体実行用**の参照実装ファイルです。ビルドおよび push 処理は行わず、既存の Artifact Registry（AR）上のコンテナイメージおよびソースコードの検査のみを実行します。`gcloud builds submit` や手動トリガー経由でオンデマンド実行する用途に使用します。
- [cloudbuild.gate.yaml](./cloudbuild.gate.yaml) — **品質ゲート化版（発展課題）**。CRITICAL 重大度の脆弱性を検出した際に `push` 処理の前にビルドを自動停止させる構成です。コンテナイメージは `docker save` コマンドで tar 化し、`trivy image --input` によって外部公開前に検査・検証します。

上記2つの定義ファイル（`cloudbuild.yaml` / `cloudbuild.scan.yaml`）は初期導入段階として `--exit-code 0`（レポート出力のみ・ビルドは失敗させない）に設定しています。一方、`cloudbuild.gate.yaml` では `--exit-code 1` を指定し、リリース阻害判定を行う品質ゲートとして機能させています。

## コマンド手順

```bash
# 事前準備: export PROJECT=<your-google-cloud-project> REGION=asia-northeast1
IMG=$REGION-docker.pkg.dev/$PROJECT/flowpay

# 依存関係のスキャン（SCA）
trivy fs --scanners vuln backend
trivy fs --scanners vuln frontend

# コンテナイメージのスキャン
trivy image --severity HIGH,CRITICAL $IMG/backend:latest
trivy image --severity HIGH,CRITICAL $IMG/frontend:latest

# SBOM（CycloneDX）の生成
# ※ CycloneDX フォーマットはデフォルトで脆弱性情報を含まないため、
#   脆弱性情報を含めた SBOM を生成する場合は --scanners vuln を明示的に指定します。
trivy image --format cyclonedx --output frontend.sbom.cdx.json $IMG/frontend:latest
jq '.components | length' frontend.sbom.cdx.json

# CI（Cloud Build）で実行する（<NN> は自身の環境番号、<IP> は演習用 npm レジストリ）
# A) 組み込み版: リポジトリのルートで実行（build → push → scan までを一貫実行。frontend ビルドに _NPM_REGISTRY が必要）
gcloud builds submit . --region asia-northeast1 --config cloudbuild.yaml \
  --substitutions _REPO=app-<NN>,_NPM_REGISTRY=http://<IP>:4873/
#    本番運用では push トリガーにより自動実行されるため、上記の手動 submit コマンドは動作確認用となります。

# B) 単体スキャンのみ: build/push は実行せず、既存の AR イメージおよびソースコードのみを検査
gcloud builds submit . --region asia-northeast1 --config solutions/01-sca-sbom/cloudbuild.scan.yaml \
  --substitutions _REPO=app-<NN>
```

## 実行結果（参考値）
Trivy で `--severity HIGH,CRITICAL` を指定した際の検出内訳の例です（**検出件数は脆弱性データベースの更新や対象バージョンにより変動します**）。スキャン処理は「OS パッケージ層」および「アプリケーション依存関係層（Go バイナリ / npm）」の両方を対象として実行される点に留意してください。

| スキャン対象 | 検出対象のレイヤー | HIGH / CRITICAL 検出数 |
| --- | --- | --- |
| backend の `go.mod`（SCA / fs） | アプリケーション依存（Go） | **19件**（HIGH: 19 / CRITICAL: 0） |
| frontend の `package-lock.json`（SCA / fs） | アプリケーション依存（npm） | 0件 |
| backend コンテナイメージ（distroless） | OS パッケージ ＋ Go バイナリ埋め込み依存 | **34件**（HIGH: 33 / CRITICAL: 1） |
| frontend コンテナイメージ（node:22-slim） | Debian OS ＋ `node_modules` | Debian OS: **22件**（HIGH: 17 / CRITICAL: 5）＋ node-pkg: **8件**（HIGH: 7 / CRITICAL: 1） |

- backend は distroless イメージであっても 34件の脆弱性が検出されます。これは Trivy が **Go バイナリに静的リンクされた依存パッケージ**（`golang.org/x/crypto` や `golang.org/x/net` 等）まで深層検査を実行するためであり、OS パッケージ層が極少であってもアプリケーション依存が古ければ脆弱性が残存します。
- frontend はマニフェストファイル（fs スキャン）では 0件ですが、コンテナイメージスキャンでは node-pkg 階層において 8件検出されます。これはアプリケーション本体の依存関係（`/app/node_modules`）ではなく、**ベースイメージ `node:22-slim` に同梱された npm や corepack 由来の `node_modules` に起因するもの**です（アプリケーション本体の依存関係はイメージスキャンにおいても 0件です）。**ベースイメージが内包する構成要素までイメージスキャンによって捉えられる**点を示す重要な観察ポイントです。

### ポイント
- **脆弱性は「OS パッケージ層」と「アプリケーション依存関係層」の2層に大別され、層ごとに独立した対策が必要となります。** ベースイメージの選定は OS パッケージ層に効果を発揮し、依存関係の更新はアプリケーション依存関係層に効果を発揮します。
- **OS パッケージ層 — ベースイメージの選定によって検出数が劇的に変化します。** frontend で使用している `node:22-slim` は 88パッケージを含み Debian OS 由来で 22件検出される一方、backend の distroless は OS パッケージが極少数であるため OS 由来の脆弱性はほぼ検出されません。**ベースイメージを最小構成化するのみで OS 階層の攻撃対象領域（アタックサーフェス）を大幅に縮小可能です**（→ 発展課題: frontend の distroless 化・最小イメージ化）。
- **アプリケーション依存関係層 — ベースイメージの種類に関わらず残存します。** distroless を採用した backend であっても、Go バイナリ内部に静的結合された `x/crypto` や `x/net` が古ければ脆弱性が検出されます。このレイヤーの脆弱性は**依存パッケージの明示的更新によってのみ解消可能です**（→ 発展課題: backend の `x/crypto` / `x/net` を更新して再スキャンし、SCA ゲートの題材とする）。
- 「現状把握」の本質は、脆弱性がどのレイヤーに何件存在するかという内訳を精密に追跡・把握することです。検出総数（絶対値）のみにとらわれず、どのレイヤーが根本要因かを特定・分析し、各層に応じた適切な対策（ベースイメージ最小化 / 依存関係更新）を選択することが重要です。

## 品質ゲート化（発展課題）
単なるレポート出力（`--exit-code 0`）から、**CRITICAL 重大度を検出した際にビルドを失敗・停止させる**自動制御へ移行する参照実装が [cloudbuild.gate.yaml](./cloudbuild.gate.yaml) です。

- Trivy に対して `--exit-code 1` フラグを指定すると、対象重大度の脆弱性が1件でも検出された場合にコマンドが非ゼロ（エラー）終了し、該当の Cloud Build ステップおよびビルド全体が失敗状態となります（後続ステップは実行されません）。
- **Artifact Registry（AR）への不正公開自体を未然に防止する**ため、コンテナイメージの検査ステップを `push` の直前に配置しています。ローカルビルド済みのイメージを `docker save` で tar ファイル化し、`trivy image --input` で検査を行います（AR から pull しないため、Docker 認証設定が不要となります）。ゲートの検査をクリアした場合のみ、後続の `push-images` ステップへ到達します。
- 本構成では CRITICAL のみをブロック対象（`--severity CRITICAL`）としています。HIGH 重大度まで拡張する場合は `--severity HIGH,CRITICAL` を指定します。
- 初期導入時からすべての検出結果を拒否条件に設定すると開発生産性や運用が停滞するため、まずはレポート出力のみから開始し、段階的に適用する重大度を絞り込んで導入する運用（リスクベース運用）が現実的です。
- 実運用環境においては `--ignore-unfixed` を指定して「修正バージョンがリリース済みの脆弱性」に限定し、恒久的な例外適用については `.trivyignore` または VEX 情報を用いて CVE 単位で個別に許可・管理します（品質ゲートの判定基準を不当に緩めない運用）。
- distroless を採用した backend であっても、Go ツールチェーン（標準ライブラリ）や埋め込まれた依存関係が古ければ CRITICAL が検出されて品質ゲートでビルドが停止します（ベースイメージの最小化のみでは防げないアプリケーション依存関係層の構造的問題）。

## CI ステップにおける認証構成に関する補足
CI パイプライン内部からコンテナイメージスキャンを実行する場合、Trivy が対象イメージを取得する通信経路によって認証設定の要否が異なります。

- `trivy fs`（依存関係スキャン）の実行にはレジストリ認証は不要です。
- **AR から pull して検査する場合（認証が必要）**: `trivy image <AR上のイメージパス>` を実行する場合は AR に対する pull 権限（認証）が必要です。本解答例では、ビルド用 SA のアクセストークンから Docker 認証設定ファイル（`config.json`）を動的に生成し、環境変数 `DOCKER_CONFIG` を介して Trivy へ引き渡す構成としています（[cloudbuild.scan.yaml](./cloudbuild.scan.yaml) 内の `auth` ステップを参照）。本仕組みは、AR が「ユーザー名: `oauth2accesstoken`・パスワード: アクセストークン」による Basic 認証を受け付ける仕様を利用し、`config.json` の `auth` フィールドへ `base64("oauth2accesstoken:<token>")` を書き込むことで実現しています。前提としてビルド用 SA に対象リポジトリの `roles/artifactregistry.reader` ロールが付与されている必要があります。
- **ローカルビルド済みイメージを直接検査する場合（認証不要）**: `docker save` コマンドで tar ファイル化されたローカルビルド済みイメージを `trivy image --input <tarファイル名>` で検査する場合、AR からの pull 処理が発生しないため認証設定は不要となります（[cloudbuild.gate.yaml](./cloudbuild.gate.yaml) の `save-images` → `gate-image-*` ステップを参照）。コンテナイメージの push 前に品質ゲートを配置したい構成においては、本手法がシンプルかつ合理的です。
