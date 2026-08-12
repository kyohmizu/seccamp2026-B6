# 演習06: cosign keyless 署名

コンテナイメージに対し、Sigstore を用いた keyless 署名を付与します。長寿命の秘密鍵を保持・管理せず、OIDC による身元証明（アイデンティティ）に基づいて一時的な証明書（Fulcio）を取得して署名を行い、その検証可能性を透明性ログ（Rekor）へ記録します。本演習では解説 2-2 で触れた Sigstore の仕組みを実際に操作します。なお、Google Cloud 環境におけるコンテナ署名・検証の実務では演習05の provenance ＋ Binary Authorization が一般的ですが、本演習は Sigstore を直接操作する発展的なアプローチを扱います。

## 関連
- 1-1 TanStack（署名の限界） / 2-2「主要なフレームワーク」（Sigstore）
- keyless 署名の意義: 長寿命の秘密鍵の管理自体を不要とします。Shai-Hulud 等の攻撃手法が長寿命の暗号鍵や資格情報の窃取を狙うのに対し、そもそも窃取対象となる鍵を保管しない（攻撃対象領域を無効化する）という根本的な対策アプローチとなります。

## 課題
1. Cloud Build のビルドステップ内に cosign keyless 署名の処理を組み込み、正常に実行・完了させてください。
2. 署名結果を検証してください（`cosign verify` コマンドを使用し、期待する身元＝ビルド用 SA の identity と一致することを確認します）。
3. （発展）Binary Authorization の検証ポリシーを cosign 署名の検証へ置き換える、あるいは併用する構成を検討・構築してください。

## 注意点
Cloud Build パイプライン上で cosign keyless 署名を正常に成立させるには、以下の要件・設定を順に適用する必要があります。
1. **`HOME=/tmp` の指定**: cosign は Sigstore の信頼ルート（Fulcio および Rekor の公開鍵情報）を TUF 経由で取得し、`$HOME` ディレクトリ配下にキャッシュします。Cloud Build の実行環境では `$HOME` が書き込み不可となっている場合があるため、明示的に書き込み可能な `/tmp` を環境変数として指定します。
2. **Artifact Registry（AR）の認証設定**: cosign は独立したコンテナプロセスとして実行されるため、Docker の認証情報をそのまま引き継ぎません。ビルド用 SA のアクセストークンを取得し、適切な `DOCKER_CONFIG` を生成して渡す必要があります。
3. **OIDC ID トークンの取得手順**: トークン取得の際は、以下の点に注意してください。
   - ❌ メタデータサーバーの identity エンドポイントによる取得は Cloud Build ではサポートされていません（デフォルト SA 扱いとなり、`please provide a user-specified service account` エラーが発生します。`--service-account` オプションを指定した場合も同様です）。
   - ✅ IAM Credentials API のインパーソネーション（impersonation / `generateIdToken`）を用いて取得します。
     ```bash
     gcloud auth print-identity-token \
       --impersonate-service-account=<SA> --audiences=sigstore --include-email
     ```
     - 実行 SA（`<SA>`）に対して自分自身への `roles/iam.serviceAccountTokenCreator` ロールが付与されている必要があります。
     - `--include-email` フラグの指定が必須です（未指定の場合、Fulcio 側で 400エラー: "error processing the identity token" が発生します）。
4. **署名コマンドの実行**: `cosign sign --yes --identity-token=<取得したトークン> <IMAGE>@<digest>` を実行して署名を付与します。

## 検証
- ビルドパイプラインが正常終了（SUCCESS）し、透明性ログ（Rekor）へ署名エントリが記録されたことを確認してください。
- `cosign verify` コマンド（オプション: `--certificate-identity=<SA>` および `--certificate-oidc-issuer=https://accounts.google.com`）を実行し、検証が正常に成功することを確認してください。検証フェーズでは以下の項目がチェックされます。
  - cosign claims（クレーム情報）の検証
  - 透明性ログ（Rekor）における署名ログの存在確認
  - Fulcio によって発行された一時証明書のルート検証

> [!NOTE]
> Rekor は**公開型の透明性ログ**です。記録された署名エントリは <https://search.sigstore.dev/> で参照可能であり（署名者のメールアドレス、コンテナイメージの digest、`logIndex` 等で検索可能）、**署名者の identity（プロジェクト名を含むビルド用 SA のメールアドレス）が公開されます**。これは「いつ、誰が、どの digest のイメージに署名したか」を第三者が独立して検証可能にするための、透明性を目的とした設計です。したがって、共有環境や本番運用においては、署名を実行する SA のメールアドレス（プロジェクト名を含む）が公開ログ上に記録・残存する点に留意してください。
