# 解答: 実行時の監視

本演習は概念整理および考察が主な内容となりますが、課題1（ビルドログにおける可視性の検証）については実環境での動作確認が可能です。

## 課題1: ビルドログの可視性（`--foreground-scripts` の適用）
`postinstall` スクリプトを保持する依存パッケージを取り込んだ状態で、`frontend-deps` ステップの npm コマンドに `--foreground-scripts` オプションを付与すると、デフォルト構成では非表示となる install スクリプトの標準出力がログ上に明示表示されるようになります。

```yaml
# pipelines/cloudbuild.yaml の frontend-deps ステップ
      npm install --omit=dev --no-audit --no-fund --foreground-scripts
```

> [!NOTE]
> 本検証は install スクリプトが実行される npm の挙動（既定では標準出力のみ抑制）に依存します。ビルドに使用する `node:22-slim` は npm 10.x を同梱するため、記述通りの動作となります。なお npm v12（2026年7月）以降は install スクリプト（`preinstall` / `install` / `postinstall`）が既定で実行されなくなり、`npm approve-scripts` コマンドによる明示的な許可が必要となります（npm 11.16.0 以降では実行自体は行われますが、仕様変更への移行を促す警告が出力されます）。ベースイメージに同梱される npm バージョンが v12 以降へ更新された場合は、課題の主眼が「非表示化された出力の可視化」から「既定の実行停止と明示的な許可手順」へ移行します。詳細は 2-2「npm ベンダー対応」を参照してください。

## 再現手順

課題1の可視性は、`frontend-deps` ステップを「デフォルト構成」と「`--foreground-scripts` 付与」の2パターンで実行して比較します。実運用環境の `cloudbuild.yaml` を書き換えると build → イメージ push → deploy までの一連の処理が実行されるため、ここでは**その2パターンを1回のビルドで実行する隔離用の設定ファイル** [cloudbuild.demo.yaml](./cloudbuild.demo.yaml)（イメージ push および deploy 処理なし）を使用します。

前提として、1-3 の攻撃デモで構築した Verdaccio が稼働し、悪性バージョン `expense-format@1.0.1`（`postinstall` スクリプトあり）を配信している状態を利用します。

1. **隔離ビルドを実行します。** リポジトリルート（`frontend/` ディレクトリを含む階層）から以下のコマンドを実行します。
   ```bash
   gcloud builds submit \
     --config chapter3/exercises/solutions/10-runtime-protection/cloudbuild.demo.yaml \
     --substitutions=_NPM_REGISTRY=http://<verdaccio-ip>:4873/ \
     --project $PROJECT --region asia-northeast1 .
   ```
2. **ビルドログにおける2つのステップの出力を比較します。**
   - **`frontend-deps-DEFAULT`**: `added N packages` 等の要約のみが出力され、postinstall の実行出力（`[DEMO] expense-format postinstall executed ...`）は**表示されません**（スクリプト自体は実行されており、C2 サーバーへのビーコンは送信されています）。
   - **`frontend-deps-FOREGROUND`**: `> expense-format@1.0.1 postinstall` バナー表示とともに、postinstall の実行出力（`[DEMO] ...` や収集された環境変数キー、取得された SA トークンの証拠等）が明示的に**表示されます**。

ビルドログは Cloud Build コンソール、`gcloud builds log <BUILD_ID>` コマンド、または Cloud Logging コンソールのいずれからでも確認可能です。

> [!NOTE]
> 実運用のパイプライン構成で確認する場合は、`cloudbuild.yaml` 内の `frontend-deps` ステップの npm コマンドに `--foreground-scripts` オプションを付与して再ビルドを実行します（この場合、build → イメージ push → deploy までの一連の処理が実行されます）。

### ローカル環境で動作のみ確認する場合（無害なパッケージの使用）

攻撃デモの受信サーバーを構築せずに npm の動作のみを手元環境で確認する場合は、postinstall で文字列を出力するのみの無害パッケージ [harmless-postinstall/](./harmless-postinstall/)（外部通信および情報収集処理なし）を使用します。悪性パッケージのインストールは不要です。

```bash
# 解答ディレクトリ（本 README が存在する場所）から実行
SRC=$(pwd)/harmless-postinstall
mkdir -p /tmp/pi-check && cd /tmp/pi-check && npm init -y >/dev/null
npm install "$SRC" --no-audit --no-fund                       # → postinstall の出力なし（`added 1 package` のみ）
rm -rf node_modules package-lock.json
npm install "$SRC" --no-audit --no-fund --foreground-scripts  # → `> pi-demo postinstall` バナーとメッセージが表示
```

検証判定は `> pi-demo postinstall` バナー表示の有無で行います（デフォルトでは postinstall の標準出力が抑制され、`--foreground-scripts` オプションの付与により表示されます）。手元環境の npm バージョンが 11.16 以降の場合、デフォルト実行時に `npm warn allow-scripts ...`（コマンド文字列を含む移行警告）も併記されますが、これはスクリプト自体の出力ではありません。なお npm v12 以降はデフォルトで install スクリプトが実行されなくなります。

### 検知策としての位置付け

`--foreground-scripts` オプションが可視化対象とするのは、install スクリプトが実行された事実、その**コマンド行**（例: `> node postinstall.js`）、およびスクリプトが**自ら標準出力に書き出した内容**のみです。スクリプト内部の具体的な挙動（トークン窃取、外部通信、ファイルアクセス等）は、スクリプト側が出力を行わない限りログ上には出力されません。

本デモにおいて `[DEMO] ... SA トークン証拠 ...` が表示されたのは、デモ用パッケージが `console.log` を用いて明示的に出力処理を行っているためです。実際の攻撃においては出力を抑制する設計が一般的なため、出力を伴わない `postinstall`（例: `node postinstall.js` 内部で非同期かつ静かにトークンを窃取・送信する実装）の場合、`--foreground-scripts` を付与しても `> node postinstall.js` という実行行のみが表示され、攻撃挙動そのものを検知することはできません。

したがって `--foreground-scripts` は、「install スクリプトが実行されたことおよびそのコマンド」を把握するための補助的手段であり（同等の情報は lockfile 内の `hasInstallScript: true` フィールドからも取得可能です）、**悪性挙動に対する直接の検知手段ではありません**。攻撃者側の出力有無に依存せず挙動を捕捉するには、ランタイムにおける監視メカニズムが必要です（eBPF によるシステムコールの観測やメタデータサーバー（`169.254.169.254`）への接続検知、Egress 制限による C2 サーバー・メタデータ通信の遮断など。これらは課題2以降で扱います）。

## 動作確認
- `--foreground-scripts` オプションを付与しないデフォルトのビルド実行では、`frontend-deps` ステップのログ画面に `postinstall` の実行出力が表示されない挙動を確認します。
- `--foreground-scripts` オプションを追加して再ビルドを実行すると、`postinstall` の出力内容がログ上に明示的に表示されることを確認します。

## 課題2〜4（概念整理と考察）
実行時監視の主要アプローチ（Egress 通信制御・プロセスメモリ空間の保護・eBPF システム挙動監視）、代表的な監視ツール（StepSecurity Harden-Runner・cicd-sensor・GMO Flatt Security Takumi Runner）、および静的解析・事前検証のみでは対応できない技術的限界については、解説ドキュメント 2-2「事後スキャンから事前検証へ」および演習ドキュメント本文内の関連リンクを参照の上、整理・考察を行います。
