# ローカル版: オフラインで完結する攻撃サンドボックス

[実環境デモの解説](../../../../chapter1/attack-demo.md) で扱った攻撃シナリオと同等の検証を、ネットワーク経由の実パイプラインを使用せずローカル（オフライン）環境のみで再現します。localhost 上に立ち上げた npm プライベートレジストリ（Verdaccio＝公開 npm レジストリの代替）と、データ受信状況を可視化するモック攻撃者 C2 サーバーを用いて、`npm update` 実行時に悪性バージョンを取り込んでしまう挙動を手元で確認できます。攻撃シナリオおよび依存関係の更新経路は実環境デモと同一であり、違いは実行環境のみです。

## 本構成の位置づけ
- 講義等で提示する実環境デモ（GitHub → Cloud Build → Cloud Run）については [攻撃デモの解説](../../../../chapter1/attack-demo.md) を参照してください。
- ローカル版は、Google Cloud 環境を用意することなく攻撃のプロセスを解説・学習したい場合に使用する構成です。クラウド環境のアイデンティティ（メタデータサーバー）が存在しないため、サービスアカウント（SA）トークンのアクセス証明（`saTokenProof`）は `null` となります。それ以外の挙動や検証プロセスは実環境デモと同一です。

## 前提条件
- Node.js / npm
- Docker（推奨）または npx（`npx verdaccio` での代用も可能）
- ネットワーク接続環境（Verdaccio が `express` や `picocolors` 等の依存パッケージを公開 npm レジストリから取得するために使用）

## 構成ファイル一覧
- `up.sh` / `down.sh` … Verdaccio（公開 npm レジストリの代替）およびモック C2 サーバーの起動・停止スクリプト
- `demo.sh` … 攻撃デモ本編実行スクリプト（正規バージョンのパブリッシュ → 悪性バージョンのパブリッシュ → 依存更新による取り込み）
- `defenses.sh` … 対策の実演スクリプト（3種類の防衛パターン）
- `publish.sh good|evil` … レジストリに対してバージョン 1.0.0 または 1.0.1 をパブリッシュするスクリプト
- `victim/` … `expense-format@^1.0.0` に直接依存する被害アプリケーション
- `mock-attacker/` … データ受信用モック C2 サーバー（localhost で動作し、受信データログを表示）
- 正規版（good）および悪性版（evil）のパッケージソース本体は実環境デモと共有（[../registry/](../registry/)）

## 実行手順
```bash
cd src/demos/malicious-dependency

local/up.sh            # Verdaccio（公開 npm の代替）およびモック C2 サーバーの起動
local/demo.sh          # 攻撃デモ本編の実行（正規版パブリッシュ → 悪性版パブリッシュ → 更新による取り込み）
local/defenses.sh      # 対策実演の実行（3パターン）
local/down.sh          # クリーンアップ（リソース停止）

# 1ステップずつ停止させて詳細解説を行う場合:
PAUSE=1 local/demo.sh
```

## 攻撃デモの実行フロー
`demo.sh` は以下の6つのステップを順次実行します（`PAUSE=1` を指定すると各ステップの実行直前で処理が一時停止します）。以下に各ステップにおける内部動作と実行出力例を示します（出力例はローカル実行用に簡略化し、ホスト名・ユーザー名・一時パス等はマスク処理を行っています）。

### 1. 攻撃前: 正規バージョンが公開されている状態
攻撃者はまだ動作を開始していません。レジストリ上には正規のパッケージ `expense-format@1.0.0` のみが存在する状態です。

```text
+ expense-format@1.0.0
publish 完了: expense-format@1.0.0 (good)
```

### 2. 被害アプリケーションが依存関係を取得し、ロックファイルで 1.0.0 に固定
`^1.0.0` の範囲に従いバージョン 1.0.0 が解決・インストールされ、`package-lock.json` に固定されます（実稼働アプリと同様に、この lockfile を Git にコミットする運用を想定します）。この時点では正常な状態です。

```text
added 2 packages in 218ms
→ ロックファイルに固定されたバージョン: expense-format@1.0.0
```

### 3. アプリケーションの実行
金額の整形処理が正常に機能し、経費サマリが出力されます。この時点で攻撃者 C2 サーバーへのデータ受信は存在しません。

```text
FlowPay 経費サマリ
  羽田-伊丹 出張往復            ￥12,000
  チームランチ                ￥3,200
  モニター・キーボード            ￥45,800
```

### 4. 攻撃者が悪性バージョン 1.0.1 を公開
同一パッケージ `expense-format` に対し、既存の金額整形処理は維持しつつ、インストール時（`postinstall`）および実行時の双方にデータ送信コードを埋め込んだバージョン 1.0.1 を公開します。`^1.0.0` の指定範囲内であるため、利用者側からは通常のマイナーバージョン更新に見えます。

```text
+ expense-format@1.0.1
publish 完了: expense-format@1.0.1 (evil)
```

### 5. 依存関係の更新に伴い悪性バージョン 1.0.1 へ切り替わる
依存更新処理（`npm update` や Dependabot 等）を実行すると、`^1.0.0` の許容範囲内で最新となる 1.0.1 へ切り替わり、`package-lock.json` 内の記述が 1.0.0 から 1.0.1 へ書き換わります。公開直後の悪性バージョンが検証なしで適用され、インストール時に `postinstall` スクリプトが自動実行されます。

```text
changed 1 package in 4s
npm warn allow-scripts 1 package has install scripts not yet covered by allowScripts:
npm warn allow-scripts   expense-format@1.0.1 (postinstall: node postinstall.js)
→ 更新後にインストールされたバージョン: expense-format@1.0.1
```

### 6. アプリケーション実行とデータ送信（持ち出し）の確認
アプリケーション自体は正常に動作しているように見えますが、内部では以下の2段階でデータ送信が実行されます。
- **インストール時（`postinstall`）**: 環境変数から機密情報のキー名を収集してマーカーを生成し、localhost の攻撃者 C2 サーバーへ送信（Shai-Hulud 型の CI / ビルド時 RCE）。
- **実行時**: `formatYen` 関数が呼び出されるたびに、入力値（処理経費額）を攻撃者 C2 サーバーへ継続送信。

アプリケーション出力（正常動作に見える状態）:
```text
FlowPay 経費サマリ
  羽田-伊丹 出張往復            ￥12,000
  チームランチ                ￥3,200
  モニター・キーボード            ￥45,800
```

インストール時マーカー（`postinstall` により生成。キー名のみを収集し、実際の値は取得しない仕様）:
```json
{
  "stage": "postinstall",
  "host": "<ホスト名>",
  "user": "<ユーザー>",
  "cwd": "/tmp/.../node_modules/expense-format",
  "secretEnvKeys": ["GCP_SA_KEY", "NPM_TOKEN", "GITHUB_TOKEN"],
  "saTokenProof": null
}
```

攻撃者 C2 サーバー側の受信用ログ（`local/.work-mock.log`）:
```text
mock attacker listening on http://127.0.0.1:9099 (POST /steal)
[攻撃者受信 #1] postinstall  {"secretEnvKeys":["GCP_SA_KEY","NPM_TOKEN","GITHUB_TOKEN"],"saTokenProof":null}
[攻撃者受信 #2] runtime      {"event":"formatYen","stolen":12000,"saTokenProof":null}
[攻撃者受信 #3] runtime      {"event":"formatYen","stolen":3200,"saTokenProof":null}
[攻撃者受信 #4] runtime      {"event":"formatYen","stolen":45800,"saTokenProof":null}
```
> ローカル環境で `saTokenProof` が `null` となるのは、クラウド環境のアイデンティティ（メタデータサーバー）が存在しないためです。実環境デモ版（[攻撃デモの解説](../../../../chapter1/attack-demo.md)）では、ここにアクセスに成功した SA トークンの証明情報（メールアドレス、トークン長、SHA-256 ハッシュ値、接頭辞）が挿入されます。

**要点**: ロックファイルによりバージョンを固定している場合であっても、依存関係の更新操作を行うことで公開直後の悪性バージョンが検証なしで取り込まれ、インストール時および実行時の両段階において不正なデータ送信が成立します。

## 対策の実演
`defenses.sh` は以下の3つの防御パターンを順次実演します。各対策の適用効果は以下のとおりです。

| 対策 | 効果 | 対応する演習/解説 |
| --- | --- | --- |
| コミット済み `package-lock.json` ＋ `npm ci` | lockfile の定義どおり 1.0.0 をインストール。明示的な更新操作を行わない限り悪性 1.0.1 は取り込まれず、`postinstall` も実行不可 | 演習03（依存の固定） |
| `npm install --ignore-scripts` | インストール時 RCE（`postinstall`）を無効化。ただし実行時におけるデータ送信は別途対策が必要 | 第2章 2-2（対策選定の観点） |
| cooldown / min-release-age（`cooldown-check.js`） | 公開直後の最新バージョンを自動採用しない。公開されたばかりの 1.0.1 を検出してブロック | 演習08（cooldown） |

**対策1: コミット済み `package-lock.json` ＋ `npm ci`**。悪性バージョン 1.0.1 が公開されている状態であっても、lockfile に記録された 1.0.0 のみがインストールされます。`postinstall` スクリプトも実行されません。
```text
ロックファイル生成時のバージョン: expense-format@1.0.0（1.0.0 に固定）
→ 悪性 1.0.1 が公開済みであっても、npm ci はロックファイルの定義に従って導入:
added 2 packages in 130ms
  結果: expense-format@1.0.0 / インストール時マーカー: なし(postinstall 実行されず)
```

**対策2: `npm install --ignore-scripts`**。バージョン 1.0.1 自体はインストールされますが、`postinstall` スクリプト（インストール時 RCE）の実行は遮断されます。ただし実行時におけるデータ送信は対象外であるため、アプリケーション動作時には runtime ビーコンが発生します。
```text
added 2 packages in 314ms
  取得されたバージョン: expense-format@1.0.1（1.0.1 自体は導入される）/ マーカー: なし(postinstall 実行されず)
  ※ --ignore-scripts が遮断するのはインストール時のみ。実行時における動作は別途レイヤーでの対策が必要
```

**対策3: cooldown / min-release-age**。公開直後のパッケージバージョンを自動採用しません。公開直後の 1.0.1 は経過日数が指定しきい値未満であるため、採用がブロックされます。
```text
候補: expense-format@1.0.1  公開日時: <timestamp>  経過日数: 0.00日  しきい値: 14日
BLOCK: 1.0.1 は公開から 0.00日（< 14日）。cooldown 設定により不採用。
```

各対策が更新経路のどの段階に作用するか、および各演習との対応関係については、第2章「脅威モデリングと対策」（2-2 対策の枠組みと観点）および第3章の演習で扱います。
