# 解答: OpenSSF Scorecard

Scorecard はリポジトリのセキュリティ実践を自動評価するツールです。依存先 OSS の健全性把握と、自リポジトリの弱点点検に用います。

## コマンド手順

```bash
# 公開リポジトリの評価には read 権限の GITHUB_TOKEN（PAT）が必要
export GITHUB_TOKEN=<your-personal-access-token>

# 1. 依存先 OSS を評価（npm パッケージ名からソースリポジトリを自動解決）
docker run --rm -e GITHUB_AUTH_TOKEN=$GITHUB_TOKEN \
  gcr.io/openssf/scorecard:stable --npm=axios

# 2. 自リポジトリを評価
docker run --rm -e GITHUB_AUTH_TOKEN=$GITHUB_TOKEN \
  gcr.io/openssf/scorecard:stable --repo=github.com/<org>/<repo>

# 3. 特定のチェックだけを実行
docker run --rm -e GITHUB_AUTH_TOKEN=$GITHUB_TOKEN \
  gcr.io/openssf/scorecard:stable --repo=github.com/<org>/<repo> \
  --checks=Branch-Protection,Token-Permissions,Pinned-Dependencies
```

## 主なチェック項目（抜粋）

| チェック | 見ている内容 | 対応する演習・座学 |
| --- | --- | --- |
| Branch-Protection | 保護ブランチ設定（直接 push 禁止・レビュー必須など） | 2-2 ガバナンス |
| Code-Review | 変更へのレビューの実施 | 2-2 ガバナンス |
| Pinned-Dependencies | 依存・Action のダイジェスト固定 | 演習02 |
| Token-Permissions | ワークフローのトークン権限 | 最小権限（演習04） |
| Dangerous-Workflow | 危険なワークフローパターン | 1-1 tj-actions |
| Signed-Releases | リリースへの署名 | 演習06 |
| Maintained / Vulnerabilities | 保守状況・既知の脆弱性 | 演習01 |

## 期待される結果

- 依存先ごとにスコアと項目別評価が得られ、健全性の高低を比較できる。
- 自リポジトリの低スコア項目を改善（例: 依存の固定、トークン権限の最小化）すると、再評価でその項目のスコアが上がる。

## 補足

- スコアは「実践の有無」の目安であり、高スコアが安全を保証するわけではありません。TanStack のように、実践が整っていてもビルド環境の侵害は別問題として起こり得ます。判断材料の一つとして扱います。
- 大量の評価を短時間に行うと GitHub API のレート制限にかかることがあります。対象を絞るか、時間を空けて実行します。
