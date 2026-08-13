# 演習13: OpenSSF Scorecard

[OpenSSF Scorecard](https://github.com/ossf/scorecard) を使用して、リポジトリのセキュリティ実践を自動評価します。依存先 OSS の健全性を数値で把握し、あわせて自分たちのリポジトリの弱点を点検します。

Scorecard は、ブランチ保護・コードレビュー・依存の固定・トークン権限・リリース署名・危険なワークフローなどの観点を自動でチェックし、項目ごとと総合（0〜10）のスコアを出します。

## 関連
- 2-2「マルウェア・悪性依存対策」（OSS 健全性評価 / Scorecard）
- 1-1 axios。依存先の管理体制（レビュー・ブランチ保護など）の弱さが、アカウント奪取や悪性コード混入の入口になります。

## 課題
1. **依存先 OSS を評価**: 主要な依存パッケージのスコアを確認し、健全性の高いものと低いものを比較してください。項目別に、どのチェックが低いか（＝どういうリスクがあるか）を確認します。
2. **自リポジトリを評価**: 自分たちのリポジトリを評価し、低スコアの項目（Branch-Protection・Token-Permissions・Pinned-Dependencies など）を確認してください。
3. **弱点を1つ改善**: 低スコアの項目を1つ選び、改善してください。例として、Pinned-Dependencies は演習02 のダイジェスト固定、Token-Permissions はワークフロー権限の最小化と対応します。
4. **（任意）継続評価**: Scorecard を CI や GitHub Action で定期実行し、スコアの変化を追える状態にします。

<details>
<summary>ヒント</summary>

```bash
# 公開リポジトリの評価には read 権限の GITHUB_TOKEN（PAT）が必要
export GITHUB_TOKEN=<your-personal-access-token>

# npm パッケージ名から評価（ソースリポジトリを自動解決）
docker run --rm -e GITHUB_AUTH_TOKEN=$GITHUB_TOKEN \
  gcr.io/openssf/scorecard:stable --npm=axios

# リポジトリを直接指定して評価
docker run --rm -e GITHUB_AUTH_TOKEN=$GITHUB_TOKEN \
  gcr.io/openssf/scorecard:stable --repo=github.com/<org>/<repo>

# 特定のチェックだけ実行する例
docker run --rm -e GITHUB_AUTH_TOKEN=$GITHUB_TOKEN \
  gcr.io/openssf/scorecard:stable --repo=github.com/<org>/<repo> \
  --checks=Branch-Protection,Token-Permissions,Pinned-Dependencies
```

</details>

## 検証
- 依存先の項目別スコアを確認し、どのチェックが低いか、それがどのようなリスクに対応するかを説明できることを確認してください。
- 自リポジトリの弱点を1つ改善し、再評価でその項目のスコアが上がることを確認してください。

## 発展
- **継続評価**: Scorecard GitHub Action を導入し、PR やスケジュールで自動評価してスコアの推移を追います。
- **既存対策との対応整理**: Pinned-Dependencies（演習02）・Token-Permissions（最小権限）・Signed-Releases（演習06）・Dangerous-Workflow など、Scorecard のチェック項目と、座学・他の演習で扱った対策との対応を整理します。
- **スコアの限界**: スコアは「実践の有無」の目安であり、高スコアが安全を保証するわけではありません（TanStack のように、実践が整っていてもビルド環境の侵害は別問題として起こり得ます）。判断材料の一つとして扱います。
