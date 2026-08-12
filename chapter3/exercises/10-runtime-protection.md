# 演習10: 実行時の監視

ビルド時およびデプロイ時の静的検証対策に加え、実行時（CI ランナー環境や Cloud Run 稼働環境）における不審な動作や攻撃挙動を動的に監視・検知する手法を扱います。まず「既定のビルドログのみでは悪性コードの実行挙動が不可視化される」事実を実機で検証し、続けて、事前の静的検証を回避して侵入した攻撃活動を動的なシステム挙動から検知・監視する多層防衛アプローチを整理します。

## 関連
- 1-1 Shai-Hulud / TanStack（CI ランナー上で悪性コードが実行され、資格情報を収集して外部へ不正送信したインシデント事例）
- 1-3 攻撃デモ（`postinstall` スクリプトによる CI 環境上での悪性コード実行シミュレーション）
- 2-2「事後スキャンから事前検証へ」（ランナー環境の保護および eBPF を活用した動的モニタリング）

## 課題
1. **ビルドログにおける可視性の検証**: `postinstall` スクリプトを保持する依存パッケージを取り込んだ状態で Cloud Build を実行し、Cloud Logging からビルドログを確認してください。デフォルト構成では `frontend-deps` ステップに `postinstall` の出力ログが現れない挙動を確認します。続いて `frontend-deps` の npm コマンドに `--foreground-scripts` フラグを付与して再実行し、`postinstall` の出力がログに明示表示されることを確認します。「実行ログは記録されているものの、デフォルトでは install スクリプトの詳細挙動が不可視化される」現象を実機で体感します。
2. CI/CD ランナー環境における実行時監視（Runtime Monitoring）の基本概念と主要なアプローチを整理してください。
   - アウトバウンド通信（Egress）の制御（許可された特定のドメイン・エンドポイント以外の外部通信を遮断）
   - プロセスメモリ空間の保護（`/proc/<pid>/mem` 等を介した不審なプロセスアクセスやメモリ走査動作の防止）
   - eBPF を活用したシステム挙動監視（不審なシステムコールの発行や C2 通信のリアルタイム検知）
3. 以下のいずれかのテーマを選択して取り組んでください。
   - 代表的な監視ソリューション（Harden-Runner（StepSecurity）、cicd-sensor（OSS）、Cloud Run 側の標準監視機能等）を実際に導入・検証する
   - 各監視ツールの検知メカニズム、アーキテクチャ、およびログ収集・相関の仕組みを比較整理する
4. コードの難読化や多段ペイロードのロードなどの観点から、静的解析・事前検証のみでは攻撃を完全に防ぎきれない技術的理由を考察・整理してください。

<details>
<summary>ヒント</summary>

- ビルドログは Cloud Build コンソール画面、`gcloud builds log <BUILD_ID>` コマンド、または Cloud Logging コンソールから確認できます。
- npm はデフォルト仕様において、依存パッケージの install スクリプト（`postinstall` 等）の標準出力を非表示（実行自体は実施）とします。`frontend-deps` ステップの npm コマンドに `--foreground-scripts` オプションを追加することで標準出力が表示されるようになります（`pipelines/cloudbuild.yaml` および PR チェック用トリガー定義ファイルを参照）。
- `postinstall` を保持するテスト用依存パッケージは、1-3 の攻撃デモ（[malicious-dependency](../../src/demos/malicious-dependency/)）で提供されている悪性バージョンを利用するのが容易です。悪性コードを実行させたくない場合は、`postinstall` 内で単純なメッセージを出力する無害なローカルテストパッケージを作成・利用しても同様の挙動を検証できます。

</details>

## 検証
- デフォルトのビルドログ構成では `frontend-deps` ステップにおける `postinstall` の出力が表示されず、`--foreground-scripts` オプションを適用することで出力が現れることを確認してください。

## 発展
- StepSecurity Harden-Runner や GMO Flatt Security Takumi Runner のような eBPF ベースのランナー監視ツールを用いて、パイプラインのどのステップがどの外部通信や子プロセス生成を引き起こしたかを相関分析する内部メカニズムについて調査します。
- Cloud Build の Private Pool を VPC に接続し、ビルドの外向き通信を記録・制限する構成を検討します。Private Pool のワーカーはピアリング先のサービスプロデューサーネットワークにあり Cloud NAT を直接使えないため、`NO_PUBLIC_EGRESS` でインターネットへの直接経路を断ち、外向き通信を自 VPC 内の egress プロキシ／ゲートウェイ経由に集約して、そのゲートウェイのログ（VPC Flow Logs やプロキシログ）で記録・許可リスト化します（事前構築された VPC が前提）。

> 出典:
> - [Private pools overview](https://cloud.google.com/build/docs/private-pools/private-pools-overview)
> - [Using Cloud Build in a private network](https://cloud.google.com/build/docs/private-pools/use-in-private-network)
> - [Private pool configuration file schema（egressOption / NO_PUBLIC_EGRESS）](https://cloud.google.com/build/docs/private-pools/private-pool-config-file-schema)
> - [VPC Flow Logs](https://cloud.google.com/vpc/docs/flow-logs)
> - [StepSecurity Harden-Runner](https://docs.stepsecurity.io/harden-runner)
> - [Takumi byGMO — Runner 機能（eBPF によるビルド時トレース）](https://flatt.tech/takumi/features/runner)
