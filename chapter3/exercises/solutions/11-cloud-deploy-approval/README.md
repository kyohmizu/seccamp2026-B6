# 解答: Cloud Deploy による承認付きデプロイの構築

- [clouddeploy.yaml](./clouddeploy.yaml) — デリバリーパイプラインおよび prod ターゲット定義例（`requireApproval: true`）
- [skaffold.yaml](./skaffold.yaml) — Cloud Run への raw マニフェストデプロイ構成
- [run-service.yaml](./run-service.yaml) — Cloud Run サービス定義（完全 spec。環境変数・Ingress・ポート設定等を漏れなく定義）

構築済み環境（Cloud Run・デプロイ用 SA・Artifact Registry）に合わせた実行手順例です。使用する `gcloud` CLI のバージョンによってサブコマンドや操作フラグが異なる場合があります。必要に応じて `gcloud deploy --help` 等を参照しながら手順を進めてください。

## 0. 環境変数の設定

```bash
export PROJECT=<your-google-cloud-project>
export REGION=asia-northeast1
export PREFIX=<your-name-prefix>     # 例: student01
export REPO=flowpay
export DEPLOY_SA=$PREFIX-deploy-sa@$PROJECT.iam.gserviceaccount.com
export IMG=$REGION-docker.pkg.dev/$PROJECT/$REPO/frontend

# frontend から呼び出す backend サービスの URL を取得（マニフェスト定義に反映するため）
export BACKEND_URL=$(gcloud run services describe $PREFIX-backend --region=$REGION --project=$PROJECT --format='value(status.url)')
cd chapter3/exercises/solutions/11-cloud-deploy-approval
```

## 1. API の有効化と IAM ロール設定

```bash
gcloud services enable clouddeploy.googleapis.com --project $PROJECT

# 実行用 SA（デプロイ用 SA）に対して Cloud Deploy のジョブ実行ロールを付与
gcloud projects add-iam-policy-binding $PROJECT \
  --member="serviceAccount:$DEPLOY_SA" --role=roles/clouddeploy.jobRunner

# レンダリング成果物を保管する GCS バケットへの読み書き権限を付与（デフォルトバケット利用。スコープを限定する場合はバケット単位で付与）
gcloud projects add-iam-policy-binding $PROJECT \
  --member="serviceAccount:$DEPLOY_SA" --role=roles/storage.objectUser

# 実行ユーザー（自身）に対する Cloud Deploy 操作権限および実行用 SA の成り代わり権限（actAs）を付与
gcloud projects add-iam-policy-binding $PROJECT \
  --member="user:$(gcloud config get-value account)" --role=roles/clouddeploy.operator
gcloud iam service-accounts add-iam-policy-binding $DEPLOY_SA \
  --member="user:$(gcloud config get-value account)" --role=roles/iam.serviceAccountUser --project $PROJECT
```

※ デプロイ用 SA には、すでに `roles/run.developer`、Artifact Registry の閲覧権限、およびランタイム SA への `actAs` 権限が付与されている前提となります（事前環境構築モジュールにて付与済み）。未付与の場合は、演習04・演習05 の権限設定をあらかじめ完了させてください。

## 2. マニフェストパラメータの置換と登録

定義ファイル内の `PROJECT` および `PREFIX` を実環境の値に置換した上で適用します。

```bash
# clouddeploy.yaml の PROJECT/PREFIX を置換。run-service.yaml の BACKEND_URL_VALUE/PROJECT/PREFIX を置換（env 変数名 BACKEND_URL は保持）。
sed -e "s/PROJECT/$PROJECT/g" -e "s/PREFIX/$PREFIX/g" clouddeploy.yaml > .clouddeploy.yaml.rendered
sed -e "s#BACKEND_URL_VALUE#$BACKEND_URL#g" -e "s/PROJECT/$PROJECT/g" -e "s/PREFIX/$PREFIX/g" run-service.yaml > .run-service.yaml.rendered

gcloud deploy apply --file=.clouddeploy.yaml.rendered --region=$REGION --project=$PROJECT
```

※ `run-service.yaml` には、稼働中サービスの `spec` 定義を漏れなく転記してください（Cloud Deploy は Cloud Run サービス全体を完全置換するため、定義が欠落している場合、該当する環境変数・Ingress・ポート等の設定が失われます）。現在の設定値は `gcloud run services describe $PREFIX-frontend --region=$REGION --format=yaml` コマンドで確認できます。

## 3. リリースの作成（イメージ参照を digest に固定）

```bash
# :latest タグに対応する digest を取得（tags list コマンドが確実です。images describe は :latest タグの参照で失敗する場合があります）。
DIGEST=$(gcloud artifacts docker tags list $IMG --project $PROJECT --format='value(version)' --filter='tag:latest' | head -1)
echo "release image: $IMG@$DIGEST"

# skaffold.yaml および run-service.yaml を含む構成情報を用いてリリースを作成
# run-service.yaml 内のプレースホルダー（イメージ名 `frontend`）を実際の digest 参照へ差し替えます
cp .run-service.yaml.rendered run-service.yaml   # レンダリング済みファイルを配置
gcloud deploy releases create rel-001 \
  --delivery-pipeline=$PREFIX-frontend \
  --region=$REGION --project=$PROJECT \
  --source=. \
  --images=frontend=$IMG@$DIGEST
```

## 4. 承認待ち状態の確認と手動承認および適用結果の検証

```bash
# リリース作成直後のロールアウトステータスは PENDING_RELEASE です。承認可能状態（NEEDS_APPROVAL）へ遷移するのを待機してから承認を実行します。
# ※ PENDING_RELEASE ステータスのまま approve を実行すると 400エラー（invalid rollout state）が発生します。
until [ "$(gcloud deploy rollouts describe rel-001-to-prod-0001 \
  --delivery-pipeline=$PREFIX-frontend --release=rel-001 \
  --region=$REGION --project=$PROJECT --format='value(approvalState)')" = "NEEDS_APPROVAL" ]; do
  echo "waiting for approval-ready..."; sleep 5
done

# この時点では承認ゲートにより処理が保留されているため、Cloud Run へは未反映であることを確認します
gcloud deploy rollouts list \
  --delivery-pipeline=$PREFIX-frontend --release=rel-001 \
  --region=$REGION --project=$PROJECT --format='value(name.basename(), state, approvalState)'

# ロールアウトを承認（デフォルトのロールアウト名は rel-001-to-prod-0001）
gcloud deploy rollouts approve rel-001-to-prod-0001 \
  --delivery-pipeline=$PREFIX-frontend --release=rel-001 \
  --region=$REGION --project=$PROJECT

# Cloud Run に新しいリビジョンが正常に反映されたことを確認
gcloud run services describe $PREFIX-frontend --region=$REGION --project=$PROJECT \
  --format='value(status.latestReadyRevisionName, spec.template.spec.containers[0].image)'
```

## 5. ロールバックの実行

過去のリリースの状態へ復元します。ロールバック実行時も対象ターゲット（`prod`）に対する新規ロールアウトとして作成されるため、同様に承認操作が必要となります。

```bash
# 過去のリリースが存在する状態において（例: rel-002 をデプロイした後に rel-001 の状態へ復元する場合）
# --release フラグで復元対象のリリースを指定します。ロールバック用のロールアウトが作成されます（例: rel-001-to-prod-0002 のように連番がカウントアップします）
gcloud deploy targets rollback prod \
  --delivery-pipeline=$PREFIX-frontend --release=rel-001 \
  --region=$REGION --project=$PROJECT

# ロールバック用のロールアウトも承認待ちステータスとなります。承認可能状態への遷移を確認した上で approve を実行します。
until [ "$(gcloud deploy rollouts describe rel-001-to-prod-0002 \
  --delivery-pipeline=$PREFIX-frontend --release=rel-001 \
  --region=$REGION --project=$PROJECT --format='value(approvalState)')" = "NEEDS_APPROVAL" ]; do
  echo "waiting..."; sleep 5
done
gcloud deploy rollouts approve rel-001-to-prod-0002 \
  --delivery-pipeline=$PREFIX-frontend --release=rel-001 \
  --region=$REGION --project=$PROJECT
```

## 6. Cloud Build の自動デプロイトリガーの停止

デプロイ経路を Cloud Deploy へ一本化するため、コード push 等を契機とする自動デプロイトリガーを無効化します。

```bash
gcloud builds triggers list --project $PROJECT --region=$REGION \
  --format='table(name,disabled)' | grep -i deploy
gcloud builds triggers update <deploy-trigger-name> --project $PROJECT --region=$REGION --disable
```

## 後片付け（リソース削除）

```bash
gcloud deploy delivery-pipelines delete $PREFIX-frontend \
  --region=$REGION --project=$PROJECT --force
rm -f .clouddeploy.yaml.rendered .run-service.yaml.rendered
git checkout run-service.yaml
```
