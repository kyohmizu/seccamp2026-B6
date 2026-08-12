# 解答: 依存パッケージの固定（lockfile ＋ npm ci）

`frontend-deps` ステップにおける `npm install` コマンドを `npm ci` へ変更・置換します（`pipelines/cloudbuild.yaml` および PR チェック用トリガー定義ファイルの双方に適用します）。

## 変更内容（frontend-deps ステップ）
```yaml
- id: frontend-deps
  name: node:22-slim
  entrypoint: bash
  args:
    - -c
    - |
      cd frontend
      npm ci --omit=dev --no-audit --no-fund
```

## ポイント
- `npm ci` コマンドは `package-lock.json` に記録された定義に**完全一致**する依存パッケージのみをインストールし、記録済みの integrity（ハッシュ値）に基づいてコンテンツを不変検証します。lockfile と `package.json` の間に不整合が存在する場合は処理を失敗させます。
- （任意設定）`package.json` 内における直接依存パッケージのバージョン指定を exact（`^` などのキャレット記号を除外した完全固定）に変更することで直接依存関係も固定化されますが、推移的依存関係（Transitive dependencies）の決定論的固定とハッシュ検証を担う本質的なメカニズムは lockfile（`package-lock.json`）です。
- cooldown 期間の設定（演習08）や lockfile 差分のレビューと組み合わせることで、パッケージ更新経路を経由する悪性コードの侵入リスクを多層防御で遮断します。

## 動作確認
- ビルド実行ログにおいて、`frontend-deps` ステップが `npm install` ではなく `npm ci` コマンドを実行して依存パッケージを導入していることを確認します。
- `package.json` または `package-lock.json` の内容を意図的に変更して定義の不整合（ドリフト）を発生させた状態でビルドを実行し、`npm ci` コマンドがエラーを出力して処理を失敗させること（ドリフトおよび改ざんの自動検知機能）を確認します。
  - lockfile に未収録の依存パッケージを `package.json` に追加した場合は、同期エラー `EUSAGE`（`Missing: <pkg> from lock file`）で失敗します。lockfile が満たせないバージョン範囲（例: `^1.0.0` → `^2.0.0`）へ変更した場合は、バージョン解決エラー `ETARGET`（`No matching version found`）で失敗します。いずれの場合も `npm ci` コマンドはレビュー済みの lockfile と一致しない導入を拒否します。
