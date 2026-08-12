# 演習04: ビルド SA の最小権限化

ビルドを実行するサービスアカウント（SA）の権限を、必要最小限に絞ります。CI の実行主体が広範な権限を持っていると、そこを侵害されたときの被害が大きくなります（GitHub Actions での `GITHUB_TOKEN` 最小化に相当する Google Cloud 版）。

## 関連
- 最小権限（人・プロセス・技術の「技術」）
- 1-1 Shai-Hulud / TanStack（CI / ランナーの権限や認証情報が窃取されるとクラウド全体が掌握されうる）

## 課題
1. 現在ビルドを実行している SA と、その IAM ロール（過剰なロール、例: `roles/editor` が付与されていないか）を確認してください。
2. 専用の最小権限 SA（例: `flowpay-build-sa`）を作成し、ビルドに必要なロールだけ付与してください。
3. まず `gcloud builds submit --service-account=...` でその SA を指定してビルドが成功すること（＝付与したロールで必要十分であること）を確認してください。
4. 確認できたら、**push / PR トリガーの実行 SA をこの最小権限 SA に変更**し、実際のパイプラインが最小権限で動くようにしてください。変更後に push（または PR）してビルドが成功することを確認します。手動 submit は「ロールの十分性チェック」、トリガー SA の変更が「本番への適用」にあたります。

<details>
<summary>ヒント</summary>

課題2で付与するのは、ビルドに必要な「イメージを AR に push」「ビルドログを Cloud Logging に書く」「ソース（GCS ステージング）を読む」の 3 つに対応する最小ロールです。それぞれに対応する `roles/...` を割り出してください（ユーザー SA ＋ `options.logging: CLOUD_LOGGING_ONLY` のときはログ書き込みロールが必須）。

課題4でトリガーの実行 SA は、コンソールのトリガー設定で選択するか、gcloud で変更します（GitHub 接続トリガーは `gcloud builds triggers update github <trigger> --region=... --service-account=...`。既存の substitutions は保持されます）。

> [!NOTE]
> 署名（cosign keyless）を追加する発展では、専用 SA で OIDC ID トークン発行が必要になります。本演習が対象とするのはビルドの基本範囲です。

</details>

## 検証
- 最小ロールだけを持つ SA でビルドが成功することを確認してください。
- SA に過剰なロール（editor 等）が付与されていないことを確認してください。

## 発展
- ビルド SA をリポジトリ / サービス単位で分離します（frontend / backend で別 SA）。
- PR チェック用のビルドは、`main` への push 用ビルドとは別に、さらに権限を絞った SA で実行します。
