# 解答: ビルド SA の最小権限化

```bash
# 事前準備: export PROJECT=<your-google-cloud-project>
: "${PROJECT:?set PROJECT}"; REGION="${REGION:-asia-northeast1}"

# 1. 現在ビルドを実行している主体と付与されているロールを確認
#    （デフォルトの Cloud Build SA、または Compute Engine のデフォルト SA）
gcloud projects get-iam-policy $PROJECT \
  --flatten="bindings[].members" \
  --format="table(bindings.role, bindings.members)" \
  | grep -iE "cloudbuild|compute@" || true

# 2. ビルド専用の最小権限 SA を作成
gcloud iam service-accounts create flowpay-build-sa \
  --display-name="FlowPay build (least privilege)" --project $PROJECT
SA=flowpay-build-sa@$PROJECT.iam.gserviceaccount.com

# 3. 必要な最小限のロールのみを付与（push / ログ出力 / ソース読み取り）
for role in roles/artifactregistry.writer roles/logging.logWriter roles/storage.objectViewer; do
  gcloud projects add-iam-policy-binding $PROJECT \
    --member="serviceAccount:$SA" --role="$role" --condition=None
done

# 4. 作成した SA を指定してビルドを実行（成功すれば最小権限で必要十分であることの検証となります）
gcloud builds submit . --config pipelines/cloudbuild.yaml \
  --service-account=projects/$PROJECT/serviceAccounts/$SA --project $PROJECT
```

## トリガーの実行 SA を最小権限 SA に変更（本適用）
上記の手動 `gcloud builds submit` 実行は、付与したロールが必要十分であるかを事前検証するステップです。実運用環境においては、パイプラインを自動起動する **push / PR トリガーの実行 SA** を作成した最小権限 SA へ差し替えることで、初めて本番環境におけるハードニング（最小権限化）が有効化されます（未変更の場合はデフォルト SA での実行が継続されます）。

**gcloud コマンド**: GitHub 連携トリガーは `triggers update github` コマンドを用いて実行 SA を差し替えます（既存の substitutions 変数は維持されます）。

```bash
SA=projects/$PROJECT/serviceAccounts/flowpay-build-sa@$PROJECT.iam.gserviceaccount.com
for trg in <repo>-push <repo>-pr; do
  gcloud builds triggers update github $trg --region=$REGION --service-account=$SA
done
```

**コンソール画面**: 各トリガーの設定画面において、実行主体となるサービスアカウントに最小権限 SA（`flowpay-build-sa`）を選択します。

設定変更後に push（または PR 作成）を実行し、実際の CI パイプラインが最小権限 SA の権限コンテキストで実行され正常完了することを確認します。

## ポイント
- **デフォルトのビルド用 SA は過剰に広範な権限を保有しているケースが多く存在します**（Google Cloud プロジェクトのデフォルト設定等により `roles/editor` 相当の強力な権限が付与されている場合があります）。この SA の資格情報が奪取された場合、プロジェクト全体の制御権を攻撃者に握られる重大なリスクが生じます。
- 上記手順で作成した最小権限 SA は「Artifact Registry への push、Cloud Logging へのログ出力、Cloud Storage からのソースコード読み取り」のみに権限が制限されています。**万が一この SA の資格情報が漏洩した場合であっても、被害範囲（blast radius / 影響半径）をビルド処理の範囲内のみに局限化**できます。
- Shai-Hulud や TanStack のインシデント事例は、**CI / ランナー環境上の資格情報を窃取し、クラウドインフラ全体へ横展開（ラテラルムーブメント）を仕掛ける**攻撃手法でした。ビルド用 SA の権限を過不足なく最小化することは、このような横展開攻撃による被害影響範囲を極小化する直接的かつ効果的な防御策となります。

## 注意（ログ可視化に関する挙動）
- ユーザー定義 SA と `options.logging: CLOUD_LOGGING_ONLY` を組み合わせたパイプライン構成では、デフォルトの GCS バケットを参照する `gcloud builds log` コマンド経由でのログ参照・取得ができません。
  - Google Cloud コンソール（Cloud Logging）上でログを確認するか、または `gcloud builds submit --default-buckets-behavior=regional-user-owned-bucket` オプションを指定してユーザー所有の GCS バケットへログを出力・保存する構成へ変更して対応します。
