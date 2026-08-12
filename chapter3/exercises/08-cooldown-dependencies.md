# 演習08: cooldown で公開直後の依存を避ける

レジストリに公開された直後のパッケージバージョンを一定期間インストール対象から外す制御メカニズム（cooldown / 最小リリース経過期間）を導入します。axios のセキュリティインシデントで発生したような、パッケージ公開直後のわずかな時間を狙うサプライチェーン攻撃を構造的に回避・防衛します。

## 関連
- 1-1 axios（パッケージ公開直後の数時間で悪性コードが拡散された事例）
- 2-2「事後スキャンから事前検証へ」（cooldown 期間の設定）

## 課題
1. frontend（npm）に対して cooldown 設定を適用してください。
   - npm: `.npmrc` ファイル内で `min-release-age` を設定（npm 11.10.0 以降対応）
   - pnpm: `minimumReleaseAge` を設定（pnpm 11 では既定で1日に設定）

> [!NOTE]
> Dependabot や Renovate などの自動依存更新ツールを併用する場合は、それらツール側の cooldown 設定（Renovate の `minimumReleaseAge` 等）も揃えてください。揃えないと、更新 PR は新バージョンへ上げようとする一方でインストール側の cooldown が弾くため、install できない更新 PR が作られ続けます。

> [!NOTE]
> 個々のリポジトリ単位ではなく組織全体へ横断的に適用する場合は、この cooldown 設定を共通構成や組織ポリシーとして全リポジトリに展開します（[解説 2-2「共通基盤で対処」（シフトダウン）](../../chapter2/countermeasures.md#セキュリティの基本原則)）。

<details>
<summary>ヒント</summary>

- npm は `frontend/.npmrc`、pnpm は `pnpm-workspace.yaml` に cooldown 設定を記述します。

</details>

## 検証
- 設定の反映後、公開された直後の最新バージョンが自動では取り込まれず、指定した一定期間は直前のバージョンが継続して使用されることを確認してください。

> 出典:
> - [cooldowns.dev](https://cooldowns.dev/)
> - [npm config（min-release-age）](https://docs.npmjs.com/cli/v11/using-npm/config/)
> - [pnpm 11.0 リリース（minimumReleaseAge を既定で1日有効化）](https://pnpm.io/blog/releases/11.0)
