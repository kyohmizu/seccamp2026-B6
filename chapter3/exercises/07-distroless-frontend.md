# 演習07: frontend の最小イメージ化

frontend のベースイメージ（`node:22-slim`）を、より軽量かつ最小限の構成を持つイメージに置き換えることで、攻撃対象領域（アタックサーフェス）および既知の脆弱性検出数を削減します。演習01 で確認した backend（distroless）と frontend（`node:22-slim`）における検出件数の格差を、frontend 側の最小イメージ化によって縮小させます。

## 関連
- 2-2「対策選定の観点」（早い段階・共通基盤で対処、攻撃面の縮小）
- 演習01（SCA/SBOM）の継続課題

## 課題
1. frontend の実行用ランタイムを最小構成イメージへ変更してください（採用候補例）。
   - `gcr.io/distroless/nodejs22-debian12`（distroless が提供する Node.js ランタイム）
   - Chainguard が提供する最小 Node.js イメージ等
2. 必要な依存パッケージは CI パイプラインの先行ステップ（`frontend-deps`）にて導入済みのため、実行用イメージには配置済みの `node_modules` をコピー・配置するのみの構成としてください。
3. ベースイメージ変更の前後で Trivy による脆弱性スキャンを実行し、検出数がどの程度削減されたか比較・確認してください。

<details>
<summary>ヒント</summary>

- distroless の Node.js イメージにはシェル（`sh` や `bash`）が含まれていないため、`CMD` には実行対象スクリプトのパスを直接指定します（`node` バイナリはイメージのエントリポイント側に定義されています）。
- 依存パッケージは `frontend-deps` ステップの `npm ci` によって用意された `node_modules` ディレクトリを `COPY` します。

</details>

## 検証
- 最小化後の frontend イメージにおける脆弱性検出数が、従来の `node:22-slim` 版と比較して大幅に削減されていることを確認してください。
