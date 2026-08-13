# 演習

CI/CD パイプラインのソフトウェアサプライチェーン対策を、独立した演習として用意しています。

## 前提
コマンド例は環境変数を前提としています。あらかじめ設定してください。
```bash
export PROJECT=<your-google-cloud-project>
export REGION=asia-northeast1
```

## 進め方
- 各演習は Markdown（`NN-name.md`）を開いて取り組みます。各演習の解答例は `solutions/<演習名>/` にあり、動作確認の手順まで含みます。
- 各演習は、関連（対応する事例・対策）、課題（取り組む内容）、ヒント、検証（対策が効いたことの確認）、発展の順に並びます。
- 各演習は独立していて、上から順に進めても、任意の演習から始めても構いません。
- 出発点は、対策を導入する前の状態（`src/` の現状）です。前提が必要な演習には、前提を満たした開始用ブランチを用意しています（該当演習に明記）。
- 時間内にすべてを終える必要はありません。完了した範囲が成果となり、残りは各自で継続できます。

## 演習一覧

| # | 演習 | 関連 |
| --- | --- | --- |
| 01 | [SCA/SBOM](./01-sca-sbom.md) | 2-2 対策の枠組み、axios / Shai-Hulud（依存の把握） |
| 02 | [イメージ digest 固定](./02-pin-digests.md) | tj-actions（タグ書き換え） |
| 03 | [依存パッケージの固定（lockfile ＋ npm ci）](./03-npm-ci-lockfile.md) | 2-2 マルウェア・悪性依存対策（依存の固定）、Shai-Hulud / axios |
| 04 | [ビルド SA の最小権限化](./04-build-sa-least-privilege.md) | 最小権限、Shai-Hulud / TanStack |
| 05 | [provenance ＋ Binary Authorization でデプロイ時検証](./05-provenance-binauthz.md) | TanStack（署名の限界） |
| 06 | [cosign keyless 署名](./06-cosign-keyless.md) | 1-1 TanStack、Sigstore |
| 07 | [frontend の最小イメージ化](./07-distroless-frontend.md) | 2-2 対策選定の観点（攻撃面の縮小） |
| 08 | [公開直後の依存を避ける（cooldown）](./08-cooldown-dependencies.md) | 1-1 axios、2-2 事後スキャンから事前検証へ |
| 09 | [Policy-as-Code](./09-policy-as-code.md) | 2-2 対策選定の観点（Policy-as-Code） |
| 10 | [実行時の監視](./10-runtime-protection.md) | 1-1 Shai-Hulud / TanStack（実行時の資格情報窃取） |
| 11 | [Cloud Deploy で承認付きデプロイ](./11-cloud-deploy-approval.md) | 2-2 デプロイ・実行時の検証と保護（リリース承認）、ビルドとデプロイの分離 |
| 12 | [Secret Scanning](./12-secret-scanning.md) | 2-2 アカウント・秘密情報の保護、1-1 axios（認証情報の窃取） |
| 13 | [OpenSSF Scorecard](./13-scorecard.md) | 2-2 マルウェア・悪性依存対策（OSS 健全性評価）、1-1 axios（依存先の管理体制） |
| 14 | [攻撃デモのフォレンジック](./14-forensics.md) | 1-3 攻撃デモ、1-1 Shai-Hulud / axios、2-2 実行時の検証と保護 |
