# 演習01: SCA/SBOM

[Trivy](https://trivy.dev/) を使用して、現在どのようなコンポーネントを使用しており、どこに既知の脆弱性が存在するかを可視化し、**SBOM**（部品表）を作成します。

FlowPay は2サービス構成で、backend と frontend で使用するベースイメージが異なります。
- backend: `distroless`
- frontend: `node:22-slim`

ベースイメージの構成の違いが、脆弱性スキャン結果にどのような影響を与えるかを確認します。

## 関連
- 2-2「主要なフレームワーク」「事後スキャンから事前検証へ」
- 1-1 axios / Shai-Hulud。依存関係の深層に何が導入されているかを把握できていないと、悪性パッケージの混入を察知できません。

## 課題
1. **依存関係をスキャン（SCA）**: backend（Go）と frontend（npm）のマニフェストを Trivy でスキャンし、既知の脆弱性を確認してください。
2. **イメージをスキャン**: 2つのイメージをスキャンし、distroless と node:22-slim の間で検出される脆弱性件数の違いを観察・比較してください。
3. **SBOM を生成**: コンテナイメージの SBOM（CycloneDX 形式）を生成し、含まれるコンポーネントの一覧と構成を確認してください。
4. **CI に組み込む**: パイプライン（`pipelines/cloudbuild.yaml`）に Trivy スキャンのステップを追加し、ビルドのたびに結果が出力されるように設定してください。初期段階ではレポート出力のみにとどめ、脆弱性が検出されてもビルドは失敗させない構成とします。
5. **（任意）AR ネイティブスキャン**: Artifact Registry の自動脆弱性スキャン機能を有効化し、`gcloud` コマンドでスキャン結果を確認してください。※ コンテナイメージ1個あたり少額の課金が発生します。

<details>
<summary>ヒント</summary>

```bash
# 1. 依存のスキャン（SCA）: マニフェスト（go.mod / package.json）を解析
trivy fs --scanners vuln backend
trivy fs --scanners vuln frontend

# 2. イメージのスキャン（OS パッケージ＋言語依存を含む）
IMG=$REGION-docker.pkg.dev/$PROJECT/flowpay
trivy image $IMG/backend:latest
trivy image $IMG/frontend:latest

# 3. SBOM（CycloneDX）を生成して中身を見る
trivy image --format cyclonedx --output frontend.sbom.cdx.json $IMG/frontend:latest
jq '.components | length' frontend.sbom.cdx.json    # 部品の数

# Trivy をローカルに入れていない場合（podman/docker で実行）
docker run --rm -v "$PWD:/work" aquasec/trivy fs /work/backend
```

</details>

## 検証
- backend と frontend の脆弱性検出数を比較し、差が生じる理由を確認してください。
- CycloneDX 形式の SBOM を出力し、含まれるコンポーネントの総数を確認してください。
- パイプラインに Trivy スキャンステップが正しく組み込まれ、ビルドログにスキャン結果が出力されていることを確認してください。

## 発展
- **品質ゲート化**: 脆弱性の重大度が `CRITICAL`（慣れたら `HIGH,CRITICAL`）の場合にビルドを失敗させ（`--exit-code 1`）、パイプラインの品質ゲートとして機能させます。このとき、**脆弱なイメージがレジストリに公開されないよう、ゲートを AR への push より前に配置**してください（ヒント: ローカルでビルド済みのイメージを検査する方法を考えます）。distroless の backend でも、Go ツールチェーン（stdlib）が古いと CRITICAL で停止し得ます（＝ベースイメージ最小化だけでは防げないアプリ依存層の問題）。運用では `--ignore-unfixed` や `.trivyignore` / VEX で対象を制御します。
- 生成した SBOM をビルド成果物として保存・配布する構成とし、VEX（Vulnerability Exploitability eXchange）運用の基盤を整えます。
