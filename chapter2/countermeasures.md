# 2-2 対策の枠組みと観点

対策を体系化したフレームワークや基準と、個々の対策を目的（対象とする脅威）別に整理した分類を示します。選定時に共通して意識すべき観点もあわせて解説します。SBOM、署名、provenance、VEX などの核心技術は複数の分類にまたがって使用するため、目的別の各区分内で定義とともに紹介します。

## 目次
- [2-2 対策の枠組みと観点](#2-2-対策の枠組みと観点)
  - [目次](#目次)
  - [セキュリティの基本原則](#セキュリティの基本原則)
    - [最小権限（Least Privilege）](#最小権限least-privilege)
    - [職務分掌（Separation of Duties）](#職務分掌separation-of-duties)
    - [多層防御（Defense in Depth）](#多層防御defense-in-depth)
    - [ゼロトラスト（Zero Trust）](#ゼロトラストzero-trust)
    - [セキュリティ・バイ・デザイン（Security by Design）](#セキュリティバイデザインsecurity-by-design)
    - [責任共有とシフトダウン（Shared Responsibility）](#責任共有とシフトダウンshared-responsibility)
  - [主要なフレームワーク](#主要なフレームワーク)
    - [SLSA](#slsa)
    - [TUF](#tuf)
    - [S2C2F](#s2c2f)
    - [OSPS Baseline](#osps-baseline)
    - [CSSC](#cssc)
    - [CIS SSC Guide](#cis-ssc-guide)
    - [CNCF Software Supply Chain Best Practices v2](#cncf-software-supply-chain-best-practices-v2)
    - [NIST SSDF](#nist-ssdf)
    - [NIST SP 800-161（C-SCRM）](#nist-sp-800-161c-scrm)
  - [攻撃テクニックと対策の対応](#攻撃テクニックと対策の対応)
  - [事後スキャンから事前検証へ](#事後スキャンから事前検証へ)
  - [ベンダー・エコシステム側の対応](#ベンダーエコシステム側の対応)
    - [cooldown（待機期間）機能の普及](#cooldown待機期間機能の普及)
    - [npm レジストリの認証・パブリッシュ経路の強化](#npm-レジストリの認証パブリッシュ経路の強化)
    - [install スクリプトのデフォルト無効化（npm v12）](#install-スクリプトのデフォルト無効化npm-v12)
    - [GitHub Actions セキュリティロードマップの展開](#github-actions-セキュリティロードマップの展開)
    - [レジストリ・ベンダーによるマルウェア検知の高度化](#レジストリベンダーによるマルウェア検知の高度化)
    - [インストール前の依存関係ファイアウォール](#インストール前の依存関係ファイアウォール)
    - [堅牢化ベースイメージ（Hardened Images）の普及](#堅牢化ベースイメージhardened-imagesの普及)
    - [クラウドプラットフォームの取り込み・実行時防御](#クラウドプラットフォームの取り込み実行時防御)
    - [AI モデル・成果物の改ざん／マルウェア検査](#ai-モデル成果物の改ざんマルウェア検査)
    - [AI 起点の脆弱性に対する協調的防御](#ai-起点の脆弱性に対する協調的防御)
  - [対策選定の観点](#対策選定の観点)
  - [目的別の対策](#目的別の対策)
    - [脆弱性対策](#脆弱性対策)
    - [マルウェア・悪性依存対策](#マルウェア悪性依存対策)
    - [アカウント・秘密情報の保護](#アカウント秘密情報の保護)
    - [ビルド・パイプラインの保護](#ビルドパイプラインの保護)
    - [デプロイ・実行時の検証と保護](#デプロイ実行時の検証と保護)
    - [横断的なガバナンス・プロセス](#横断的なガバナンスプロセス)
  - [目的別対策の一覧](#目的別対策の一覧)
  - [現実的な制約と対応の落とし所](#現実的な制約と対応の落とし所)
    - [直面する現実的な制約](#直面する現実的な制約)
    - [対応の落とし所](#対応の落とし所)

---

## セキュリティの基本原則

サプライチェーンに固有の対策を検討する前提として、あらゆるセキュリティに共通する基本原則を確認します。これらは新しい考え方ではありませんが、サプライチェーン対策の基盤であり、個々の具体策はこの原則のいずれかを具現化したものです。

### 最小権限（Least Privilege）

人・サービス・プロセスに対し、必要最小限の権限のみを付与します。万が一侵害された場合でも影響範囲（影響半径）を限定できます。サプライチェーンにおいては、ビルドを実行するサービスアカウント、パッケージ公開や実行に使用するトークン・実行アイデンティティを制限することが該当し、Shai-Hulud や TanStack のようなトークン窃取後の横展開（ラテラルムーブメント）を抑止します。

### 職務分掌（Separation of Duties）

権限を一意の主体に集中させず、役割と責任を明確に分離します。重要な操作は複数人・複数系統によって成立させ、単独では処理が完結しないよう設計します。サプライチェーンにおいては、ビルド用とデプロイ用のサービスアカウントおよびワークフローを分離し、重要なリリース処理には複数人の承認を必須とすることで、CI パイプラインが単独で本番環境への反映まで到達できない制御を実装します。

### 多層防御（Defense in Depth）

単一の対策に依存せず、複数のセキュリティレイヤーで保護します。特定の対策が突破された場合でも後続の層で進行を遮断します。サプライチェーンにおいては、パッケージ取得時・ビルド時・デプロイ時・実行時の各段階で検証処理を重ねます。TanStack の事例が示すとおり、単一の署名検証のみでは十分な防御になり得ません。

### ゼロトラスト（Zero Trust）

内部・外部を問わず、暗黙の信頼を置かずに明示的に検証します。サプライチェーンにおいては、「公式レジストリに存在しているから」「署名が付加されているから」という事実のみで信用せず、署名や provenance が正当であり、期待する発行者・ソース・ビルド経路を指していることを確認した上で信頼を付与します（Verify, then Trust）。なお、署名や provenance は成果物の出所を保証するものであり、コンテンツそのものが安全であることを保証するものではありません。TanStack のようにビルド環境自体が侵害された場合、正当な署名・provenance を保持する悪性成果物が生成されるリスクが存在します。

### セキュリティ・バイ・デザイン（Security by Design）

運用開始後の後付けではなく、アーキテクチャ設計段階からセキュリティ対策を組み込みます。サプライチェーンにおいては、パイプラインや依存関係管理を構築する段階で、依存パッケージの固定・署名と検証メカニズム・ビルドとデプロイの分離を前提として実装します。

### 責任共有とシフトダウン（Shared Responsibility）

セキュリティ確保は開発者個人のみの責任ではなく、開発・プラットフォーム・セキュリティの各チームで分担・協力して取り組みます。個々の開発者の判断に依存せず、レジストリプロキシや組織ポリシーなどの共通基盤側で一括適用（シフトダウン）することにより、運用の負担軽減と設定漏れの防止を実現します。また、脆弱性やセキュリティリスクは下流工程ほど修正コストが高大化するため、コミット時や取得時などの早期段階で遮断します（シフトレフト）。

> 出典:
> - [CNCF Cloud Native Security Whitepaper](https://github.com/cncf/tag-security/blob/main/community/resources/security-whitepaper/v2/cloud-native-security-whitepaper.md)
> - [Kubernetes SIG-Security Shift-Down Security Paper](https://github.com/kubernetes/sig-security/blob/main/sig-security-docs/papers/shift-down/shift-down-security.md)

## 主要なフレームワーク

セキュリティフレームワークは、保護対象や適用範囲によって異なります。成果物やビルド処理に焦点を当てた技術指向のものから、OSS プロジェクトやコンテナ運用、開発プロセス、組織・調達管理までを網羅する包括的なモデルが存在します。近年はソースコード管理・コンテナ・OSS プロジェクトを対象とした基準の整備が急速に進んでいます。代表的なフレームワークを対象分野別に分類して示します。

### SLSA

SLSA（Supply-chain Levels for Software Artifacts）は、成果物の完全性と来歴（provenance）を段階的なレベルで定義するガイドラインであり、OpenSSF によって策定されています。最新仕様である v1.2（2025年11月に承認）では、従来の Build Track に加えて Source Track が新設され、ソースコード管理からビルドフェーズまでを一貫して管理できるようになりました。

- Build Track: ビルドの完全性と provenance 生成の要件を L1〜L3 の段階で定義します。L1 は provenance の存在、L2 はホスト型ビルドサービスによる改ざん耐性のある provenance 生成、L3 はビルド環境の完全な分離と他プロセスやテナントからの干渉防止を要求します。
- Source Track（v1.2 で新設）: ソースコードの変更履歴とレビュー運用の要件を L1〜L3 の段階で定義します。L2 以上ではブランチ履歴の連続性・不変性と、各リビジョンに対する source provenance attestation の発行を要求します。

対象領域はビルド〜成果物およびソースコード管理であり、provenance 運用における中核的な標準規格です。GitHub Actions と `slsa-github-generator` を組み合わせることで Build L2 相当までは迅速に導入可能であり、検証処理は `slsa-verifier` が担います。

### TUF

TUF（The Update Framework）は、ソフトウェアアップデートの配布経路を保護するためのセキュリティフレームワークです。暗号署名鍵を役割ごとに分離し、しきい値署名（Threshold Signatures）構造を採用することで、一部の鍵が漏洩した場合でも更新プロセス全体を防衛し、ロールバック・凍結・すり替えといったアップデート特有の攻撃を阻止します。NotPetya に見られるような更新配信経路の乗っ取りに対応するレイヤーであり、CNCF の Graduated プロジェクト（PyPI・Sigstore・Docker 等で採用）に指定されています。なお Sigstore は、自身の信頼の起点（Root of Trust）と信頼メタデータ・公開鍵の配信に内部で TUF を利用しており、両者は代替関係ではなく依存関係にあります。

### S2C2F

S2C2F（Secure Supply Chain Consumption Framework）は、OSS を消費・利用する側のリスク低減に特化したフレームワークです。Microsoft が原案を策定し、現在は OpenSSF が管理しています。取り込み（Ingest）・スキャン・インベントリ管理・更新・監査・ポリシー強制・再ビルド・修正およびアップストリーム貢献という 8つの実践プロセスを、成熟度 L1〜L4 で定義しています（L4 は自前構築コストが高く現実的でないとされる最上位段階）。実際の攻撃事例に基づく脅威ベースの設計であり、各要件が具体的なツールや他標準（SLSA・SSDF）とマッピングされています。供給側を対象とする SLSA に対し、消費・調達側を体系化した標準です。

### OSPS Baseline

OSPS Baseline（Open Source Project Security Baseline）は、OSS メンテナーおよびプロジェクト向けのセキュリティ基準であり、OpenSSF が2025年2月に初版を公開しました。約 40〜50の必須コントロール要件（推奨ではなく遵守必須の MUST）を、プロジェクトの規模およびリスクに応じて 3段階（L1〜L3）で定義しています。EU Cyber Resilience Act（CRA）や NIST SSDF への準拠基盤として設計されており、GUAC・OpenVEX・bomctl・OpenTelemetry などの主要プロジェクトがパイロット導入しています。個々のビルド成果物ではなく、OSS プロジェクト自体の最低限備えるべきセキュリティ水準を標準化・平準化する点が特徴です。

### CSSC

CSSC（Containers Secure Supply Chain Framework）は、コンテナ運用環境向けにライフサイクル全体を対象としたフレームワークであり、Microsoft によって策定されました。取得（Acquire）・カタログ（Catalog）・ビルド（Build）・デプロイ（Deploy）・実行（Run）の 5ステージに、全ステージを透過的に監視する可観測性（Observability）を加えて構成されています。各ステージにおいて、信頼できるソースからの取得・署名検証・SBOM 生成・アドミッション制御・ランタイム監視の実装を求めています。一般的なサプライチェーンセキュリティの観点と共通しつつ、コンテナ技術に特化した具体的なガイダンスと実行時保護まで言及している点が特徴です。

### CIS SSC Guide

CIS Software Supply Chain Security Guide は、CI/CD パイプラインにおける具現的な実装手順に特化したチェックリストであり、CIS と Aqua Security が共同で作成しています。ビルド環境（専用化・不変インフラ・ログ監査）、パイプラインの不変性（成果物署名・依存関係の事前検証・再現可能なビルド）、コードセキュリティ（シークレットスキャン・SAST・SCA・SBOM）などのカテゴリごとに具体的な推奨設定を定義しています。概念的な要件を示す多くの枠組みに対し、実装レベルに踏み込んだ実用ガイドであり、`chain-bench` などのツールを用いて準拠状況を機械的に監査・判定可能です。

### CNCF Software Supply Chain Best Practices v2

CNCF Software Supply Chain Best Practices は、開発者・提供者・利用者の全ロールを対象とした包括的なベストプラクティス集であり、CNCF TAG Security が発行しています。サプライチェーンを Source → Materials → Build → Artifacts → Deploy の各フェーズで捉え、フェーズごとの署名・検証・環境隔離を要求します。2024年11月の v2 においては、役割（ペルソナ）ごとの関連章の明確化、監査データの取り扱い、ツールおよび運用の最新化が盛り込まれています。

### NIST SSDF

NIST SSDF（Secure Software Development Framework、SP 800-218）は、セキュア開発プロセスの標準フレームワークです。PO（組織の準備）・PS（ソフトウェアの保護）・PW（適切に保護された開発）・RV（脆弱性対応）の 4グループから構成され、開発チームの体制構築や教育訓練までカバーするため、パイプライン技術にとどまらない広い領域を扱います。米国政府調達における必須遵守要件として位置づけられています。

### NIST SP 800-161（C-SCRM）

NIST SP 800-161（Cybersecurity Supply Chain Risk Management）は、サプライヤー管理・調達プロセス・サードパーティ評価・全社ガバナンスまでを包摂する、最も包括的な枠組みです。SSDF を開発プロセス側の入力要素として包含します。

これらのフレームワークは対象範囲および適用レイヤーが異なります。SLSA・TUF・CSSC は成果物・更新配信・コンテナ環境を対象とする技術指向のモデルであり、S2C2F・OSPS Baseline は OSS の消費・プロジェクト管理を対象とし、CNCF・CIS は各パイプラインフェーズの実践、NIST SSDF・SP 800-161 は開発プロセスから組織ガバナンス・調達管理まで広くカバーします。「人・プロセス・技術」の 3軸で整理することで、技術対策に偏りやすい施策に対し、人や組織プロセスの観点を補強できます。

また、攻撃者視点で CI/CD 環境特有のリスクを分類・整理した指標として OWASP Top 10 CI/CD Security Risks があり、依存チェーンの悪用（CICD-SEC-3）、パイプライン実行汚染（CICD-SEC-4）、認証情報の適切な管理（CICD-SEC-6）、アーティファクトの完全性検証（CICD-SEC-9）などの 10類型を定義しています。防御側のフレームワークと対比させることで、各セキュリティ対策がどの脅威シナリオに効力を発揮するかを確認できます。

国内の技術資料としては、デジタル庁策定の DS-202「CI/CDパイプラインにおけるセキュリティの留意点に関する技術レポート」が存在します。CI/CD パイプラインをローカル作業・ビルド・デリバリーの 3段階に区分し、SLSA・NIST SP 800-204D・NSA/CISA・OWASP CI/CD 等の標準を踏まえた対策を提示し、政府統一基準に紐付けて整理しています。別添の IaC 実装例（AWS・Terraform・GitHub Actions）では、署名・SBOM・provenance 検証・GitHub Action の固定などの具体的手順が示されています。

> 出典:
> - [SLSA v1.2 Specification](https://slsa.dev/spec/v1.2/) / [v1.2 発表](https://slsa.dev/blog/2025/11/announce-slsa-v1.2)
> - [S2C2F（OpenSSF）](https://github.com/ossf/s2c2f) / [OpenSSF S2C2F プロジェクト](https://openssf.org/projects/s2c2f/)
> - [TUF（The Update Framework）](https://theupdateframework.io/)
> - [OSPS Baseline](https://baseline.openssf.org/)
> - [CSSC（Containers Secure Supply Chain, Microsoft）](https://learn.microsoft.com/en-us/azure/security/container-secure-supply-chain/)
> - [CIS Software Supply Chain Security Guide](https://www.cisecurity.org/insights/white-papers/cis-software-supply-chain-security-guide)
> - [CNCF Software Supply Chain Best Practices v2](https://tag-security.cncf.io/community/working-groups/supply-chain-security/supply-chain-security-paper-v2/)
> - [NIST SSDF（SP 800-218）](https://csrc.nist.gov/projects/ssdf)
> - [NIST SP 800-161（C-SCRM）](https://csrc.nist.gov/pubs/sp/800/161/r1/final)
> - [OWASP Top 10 CI/CD Security Risks](https://owasp.org/www-project-top-10-ci-cd-security-risks/)
> - [デジタル庁 DS-202 CI/CDパイプラインにおけるセキュリティの留意点に関する技術レポート](https://www.digital.go.jp/resources/standard_guidelines)
> - [NSA/CISA Defending CI/CD Environments](https://www.cisa.gov/news-events/alerts/2023/06/28/cisa-and-nsa-release-joint-guidance-defending-continuous-integrationcontinuous-delivery-cicd)

## 攻撃テクニックと対策の対応

第1章の段階モデルおよび SITF の攻撃テクニックを起点として、代表的な攻撃手法とそれらを抑止・遮断するセキュリティ対策の対応関係を示します。

| 段階 | 代表的な攻撃テクニック（SITF ID） | 抑止・遮断する対策（対応演習） |
| --- | --- | --- |
| Source | Imposter Commits（T-V002）、タグ・参照の改ざん・書き換え（T-V011） | コミット署名、ブランチ保護ルール、依存パッケージ・GitHub Action のコミット SHA/digest 固定（演習02） |
| Build | Pwn Request（T-C003）、`toJson(secrets)` によるシークレット漏洩（T-C015）、セルフホストランナーからの横展開（T-C017） | ビルド用サービスアカウントの最小権限化（演習04）、未検証依存関係の CI 上での非実行、ビルドとデプロイの明確な分離 |
| Package / Distribution | 悪性バージョンのパブリッシュ（T-R004）、ライフサイクルスクリプト悪用（T-R012）、タイポスクワッティング（T-R010） | cooldown（待機期間設定）、依存関係の完全固定と `npm ci`（演習03）、SCA スキャン / SBOM 生成（演習01） |
| Deploy・Runtime | メタデータサーバーの不正利用（T-P007）、サービスアカウントトークンの窃取（T-P006） | provenance 生成とデプロイ時検証（演習05）、実行時監視と Egress 通信制御（発展課題） |

本対応関係は、OWASP Top 10 CI/CD のリスク項目（依存チェーンの悪用: CICD-SEC-3、PPE: CICD-SEC-4、認証情報管理: CICD-SEC-6 等）とも直接的に連動します。攻撃手法を起点に対策の技術的根拠を理解することが、第3章の演習課題に取り組む上での重要指針となります。

## 事後スキャンから事前検証へ

プロダクト取り込み後に検査を行う従来の「事後スキャン」による対応には構造的な限界が存在します。悪性コードはパッケージの取り込みやインストールの瞬間に即座に被害を発生させるため、取り込み・実行の前に検証して遮断する「事前検証」への転換が不可欠となっています。「検証した上で信頼する（Verify, then Trust）」を基本原則とし、単一の対策に過度に依存することなく、取得時・ビルド時・デプロイ時・実行時の各フェーズで防御層を重ねます。

> [!NOTE]
> 保護すべき対象はソースコードやコンテナイメージのみにとどまりません。AI モデルの重みファイル（Weight files）や学習用データセットもサプライチェーンの重要構成要素です。例えば、Python の pickle 形式（`.pkl`）で保存されたモデルファイルは、読み込み処理（`unpickle`）の実行と同時に任意のコードを実行できる構造的リスクが存在するため、Hugging Face 等で悪意のあるモデルが配布されたインシデントが報告されています。これに対する防衛策として、任意コード実行リスクのない安全なシリアライズ形式（`.safetensors`）への変換および検証プロセスの導入が進んでいます。PayLoad が買収した AI 関連企業 Halluc 社においても、出所不明のモデルファイルや重みデータをそのまま利用している課題が存在します。

> 出典:
> - AIモデル形式 — [Hugging Face safetensors](https://huggingface.co/docs/safetensors)

## ベンダー・エコシステム側の対応

2025年から2026年にかけて、セキュリティベンダーおよびパッケージエコシステム側においても、各種サプライチェーン防衛機能の実装が急速に進展しました。以下に示す項目は各組織で独自構築する対策ではなく、前提条件として活用可能な外部環境・プラットフォームの最新動向です。

> [!NOTE]
> 以下は2026年8月時点の情報です。

### cooldown（待機期間）機能の普及

pnpm・npm・Yarn・Bun などの主要ツールが最小リリース経過期間（`min-release-age` 等）の設定に相次いで対応し、公開直後の悪性バージョンを構造的に遮断・回避できるようになりました。

### npm レジストリの認証・パブリッシュ経路の強化

GitHub による「より安全な npm サプライチェーン計画」の一環として、従来の classic トークンの完全失効、FIDO ベースの多要素認証強制、デフォルト状態でのトークン無効化、および Trusted Publishing の適用拡大が推進されています。これは Shai-Hulud 等に見られるトークン窃取および不正パブリッシュ攻撃への直接的な対抗策です。

### install スクリプトのデフォルト無効化（npm v12）

GitHub（npm 運営元）が2026年6月に発表し、npm v12（2026年7月8日に GA）において、依存パッケージの `preinstall`・`install`・`postinstall`、git/file/link 依存の `prepare`、および暗黙的な `node-gyp` リビルドを**デフォルトで実行しない（無効化）**仕様へと変更しました。スクリプトを実行するには `allowScripts` による明示的な許可（`npm approve-scripts` コマンドで保留中のスクリプトを確認・承認し、`package.json` に記録）が必要となり、CI パイプライン環境では `strict-allow-scripts` オプションにより未承認スクリプトの実行をエラーとして検出・停止できます。2025年後半以降に発生したワーム拡散や認証情報窃取の多くが install 時に実行された背景を踏まえたセキュリティ対応であり（GitHub は install 時のライフサイクルスクリプトを「npm エコシステムにおける最大のコード実行面」と定義しています）、第1章の攻撃デモで検証する `postinstall` スクリプトを悪用した侵入手法をエコシステム全体のデフォルト仕様として構造的に遮断する機能強化です。

### GitHub Actions セキュリティロードマップの展開

CI/CD プラットフォーム自体をデフォルトでセキュア化する構造改革が進行しています。(1) ワークフローの依存関係におけるコミット SHA による完全ロック（推移的依存関係の固定含む）、(2) Ruleset ベースのパイプライン実行保護および細粒度なスコープ付きシークレット、(3) 実行テレメトリのリアルタイム配信とランナーレベルでのネイティブ Egress ファイアウォール（L7 制御・監視から段階的ブロック）が順次提供・適用されています。tj-actions 侵害で悪用された可変タグ参照のリスクや、CI 環境からのデータ流出（exfiltration）に対処します。

### レジストリ・ベンダーによるマルウェア検知の高度化

悪性パッケージをプラットフォーム・レジストリ層で事前検知・遮断する動きが拡大しています。Chainguard Libraries では npm パッケージをソースから再ビルドし、マルウェアやグレイウェアを検知・遮断しています。また、GitHub Advisory Database では OpenSSF の `malicious-packages` リポジトリの知見を組み込み、既知の悪性パッケージ情報を主要エコシステムへ配信しています。

### インストール前の依存関係ファイアウォール

依存関係を取り込む前に悪性コードを遮断する軽量ソリューションが登場しています。Socket Firewall 等は、パッケージマネージャーのアウトバウンド通信をプロキシ経由で検査し、ディスクへの書き込み前に安全性を評価して npm・pip・cargo 等の悪性パッケージを推移的依存関係まで含めて遮断します。事後スキャンと異なり `install` 前に停止させるため、`postinstall` スクリプトの発火を根本から防止します。

### 堅牢化ベースイメージ（Hardened Images）の普及

Docker Hardened Images が2025年末に1,000超のイメージを無償・オープンソースで公開しました。ソースコードから再ビルドした最小構成で、不要なシェルやツール類を徹底排除することで既知の脆弱性をほぼゼロに抑え、非 root 実行・SLSA Build L3・署名付き SBOM/VEX を標準で備えます。国内においても GMO Flatt Security による Takumi Images（2026年7月）が展開されており、シェルやパッケージマネージャーを除去した最小構成で脆弱性を最小化し、既知の悪性パッケージを排除した検証済みイメージが提供されています。Dockerfile 内の `FROM` 句を差し替えるのみで適用可能であり、基盤イメージ側で攻撃対象領域と脆弱性を削減する手法が定着しつつあります。

### クラウドプラットフォームの取り込み・実行時防御

主要クラウドプロバイダーが取り込み時および実行時におけるマルウェア・脆弱性対策を強化しています。AWS は CodeArtifact において公開直後のバージョンをブロックする経過時間ゲート（cooldown 同等機能）を提供し、Inspector のイメージスキャンに Chainguard の再ビルド済みライブラリを取り込んでいます。Azure は Defender for Containers によりコンテナ実行時におけるマルウェア検知・遮断機能を実装しています。

### AI モデル・成果物の改ざん／マルウェア検査

サプライチェーンの保護対象が AI モデル分野へ拡張されています。OpenSSF の Model Signing プロジェクトは Sigstore を用いてモデルの完全性と来歴をデジタル署名・検証し、Azure の AI モデルスキャン機能（Defender for Cloud）は pickle 形式等に埋め込まれた悪意のあるコードを配信・導入前に自動検出します。

### AI 起点の脆弱性に対する協調的防御

AI を活用した自動脆弱性探索の高速化に対抗するため、未公開の脆弱性情報を業界横断で共有し、影響を受けるプロジェクトを開示前に修正・配信する協調的防御（Coordinated Defense）の枠組みが機能しています。Chainguard 主導の Athena プロジェクト等は、複数組織から持ち寄られた事前開示の知見をプールし、ハード化されたビルド構成を開示前に参加メンバーへ提供します。さらに、ネットワーク・プラットフォーム層でのバーチャルパッチ（Virtual Patching）を併用することで、自前修正が困難な環境を含めて多層的に防衛します。

> 出典:
> - [Dependency Cooldowns（各PMの設定一覧）](https://cooldowns.dev/)
> - [npm classic トークン失効・セッション認証（GitHub Changelog, 2025-12-09）](https://github.blog/changelog/2025-12-09-npm-classic-tokens-revoked-session-based-auth-and-cli-token-management-now-available/)
> - [Our plan for a more secure npm supply chain（GitHub Blog）](https://github.blog/security/supply-chain-security/our-plan-for-a-more-secure-npm-supply-chain/)
> - [npm v12 Ships With Install Scripts Off by Default（Socket）](https://socket.dev/blog/npm-12)
> - [GitHub Actions 2026 Security Roadmap](https://github.blog/news-insights/product-news/whats-coming-to-our-github-actions-2026-security-roadmap/)
> - [Mitigating Malware in the npm Ecosystem with Chainguard Libraries](https://www.chainguard.dev/unchained/mitigating-malware-in-the-npm-ecosystem-with-chainguard-libraries)
> - [OpenSSF malicious-packages](https://github.com/ossf/malicious-packages)
> - [Introducing Socket Firewall](https://socket.dev/blog/introducing-socket-firewall)
> - [Docker makes Hardened Images free, open, and transparent](https://www.docker.com/press-release/docker-makes-hardened-images-free-open-and-transparent-for-everyone/)
> - [Takumi byGMO、Takumi Images を提供開始（GMO）](https://group.gmo/news/article/10093/)
> - [AWS CodeArtifact: Package version age gating](https://docs.aws.amazon.com/codeartifact/latest/ug/package-version-age-gating.html) / [Amazon Inspector × Chainguard Libraries](https://www.chainguard.dev/unchained/announcing-aws-inspector-scanner-support-for-chainguard-libraries)
> - [Microsoft Defender for Cloud リリースノート](https://learn.microsoft.com/en-us/azure/defender-for-cloud/release-notes) / [Defender for Cloud: AIモデルスキャン](https://learn.microsoft.com/en-us/azure/defender-for-cloud/ai-model-security)
> - [OpenSSF model-signing](https://pypi.org/project/model-signing/)
> - [Chainguard Athena](https://www.chainguard.dev/athena)

## 対策選定の観点

セキュリティ原則に加え、サプライチェーン対策を選択・選定する際に特に意識すべき重要な観点を提示します。

- **開発フェーズと「人・プロセス・技術」を掛け合わせて不備を検証する。** ソフトウェア開発ライフサイクルの各段階と、人・プロセス・技術の 3要素をマトリクスで点検することにより、技術的対策のみに偏重し、人やプロセスの管理が形骸化している構造的課題を抽出・手当てできます。
- **内製ソフトウェアとサードパーティ製外部ツールの双方を保護対象とする。** 自社開発のソースコードや依存ライブラリにとどまらず、CI/CD 基盤・監視エージェント・開発プラグイン・SaaS 連携など、前提として信頼して導入している外部ツールのサプライチェーンも等しく評価対象とします。外部ツールの脆弱性や侵害は盲点となりやすいため注意が必要です。
- **予防・遮断のみならず、検知および事後対応の体制を整備する。** 対策施策は侵入を事前に防止するもの（依存の完全固定・署名や provenance の検証・アドミッション制御）に偏る傾向があります。事前予防をすり抜けた攻撃活動を迅速に把握する検知機能（実行時監視・Egress 通信制限）と、インシデント発生後の事後対応（影響を受けた成果物・バージョンの即時特定、証明書の失効・差替・鍵ローテーション、ロールバック手順）まで一貫して揃えることで、初めて実効性のある多層防御が完成します。
- **可能な限り早期の段階で阻止・遮断する（シフトレフトの徹底）。** 多層防御の構成においても、悪性コード対策はパッケージ取得時・導入時の予防策に最大の重点を置きます。悪性パッケージは `postinstall` などのライフサイクルスクリプトを介してインストール時に即座に実行されるため、`install` 処理の直前に遮断できれば不正実行自体を未然に防止できます。一度環境内に取り込まれた場合、影響は下流の成果物へと順次伝播し、失効手続き・再ビルド・鍵ローテーション等、工程が下るほど被害範囲と対処コストが高大化します。ただし、初期段階の予防も完全ではないため（署名・provenance の偽装や未知のゼロデイ攻撃等）、後段における検知・隔離メカニズムをバックストップ（最終防衛線）として配置します。
- **リスクベースアプローチによる優先順位付けを実施する。** すべてのセキュリティ対策を同時に導入・適用することは運用上困難です。各種フレームワークが定義するベースラインを一律に適用するルールベースの管理を基盤としつつ、「発生可能性 × 発生時の影響度」に基づきリスクを精密に評価します。対策の費用対効果（導入・運用負担、開発生産性への影響）を勘案した上で、機密データへ最短で到達する攻撃経路や、被害が広範囲に波及するハイリスクな経路から優先的に着手します。

## 目的別の対策

個々の要素技術やセキュリティフレームワークは、「どのような脅威に対して効果を発揮するか（何のための対策か）」という目的軸で捉えることで全体構造を正しく把握できます。本節では対策を目的別に 5つのカテゴリに区分し、それらを組織的に継続運用するための横断的取り組みを加えて解説します。これは、第1章で提示した「段階（どこが狙われるか）」および「人・プロセス・技術（どこが弱いか）」という軸に対し、「何に効くか」を定義する直交した第3の視点です。

### 脆弱性対策

コンテナイメージやアプリケーションが依存するパッケージに含まれる既知の脆弱性（CVE）を検知し、修正・リスク低減を図るための対策群です。

**依存関係の脆弱性スキャン**

- **SCA（Software Composition Analysis）**: OS パッケージ層および言語固有の依存ライブラリに含まれる既知の脆弱性を検出します。Trivy、Grype、OSV-Scanner、Snyk、GitHub Dependabot alerts 等のツールが活用されます。
- **コンテナイメージスキャン**: ビルドされたコンテナイメージに対し、OS パッケージ層および言語依存ライブラリの両面から脆弱性をスキャンします。CI パイプライン内での実行に加え、Google Artifact Registry や Amazon ECR などのコンテナレジストリが提供する自動スキャン機能を併用します。
- **継続的スキャン機能の運用**: 単回のビルド時スキャンで完結させず、新たに公開される CVE データベースに追随して既存の保存イメージを定期的に再スキャン・照合します。
- **自社コードの静的解析（SAST）**: サードパーティ依存関係の脆弱性検知（SCA）に加え、自社で実装するアプリケーションコード自体の脆弱性を静的解析によって検出します（CodeQL や Semgrep 等）。外部から取り込む依存関係のみならず、ファーストパーティ側の実装不備や脆弱性の作り込みも検知対象に含めます。

**SBOM と脆弱性情報の統合管理**

- **SBOM（ソフトウェア部品表）の生成と保持**: ソフトウェアを構成するコンポーネント一覧を機械可読な標準形式で生成・保管し、インシデント発生時の後追い照合を可能にします。標準フォーマットとして CycloneDX および SPDX が使用され、Syft や cdxgen 等の生成ツールが利用されます。
- **脆弱性データベースの活用**: 照合基盤となる脆弱性情報源を保持・参照します。OSV（Open Source Vulnerabilities）、NVD、GitHub Advisory Database 等が該当します。
- **VEX（Vulnerability Exploitability eXchange）による優先度判定**: 検出された脆弱性が対象環境において実際に悪用可能（到達可能）であるかを表明・共有し、真に対応を要する脆弱性へ対処リソースを集中させます。OpenVEX などの標準フォーマットや、コードの到達可能性解析（Reachability Analysis）を組み合わせて運用します。到達可能性の判定には、静的コールグラフ解析によって脆弱な関数が実際に呼び出されるかを追跡する手法（Snyk や Endor Labs 等）と、実行時に eBPF 等でライブラリのロードや呼び出しをトレースする手法が存在し、「CVE を含むライブラリの該当関数が実際に実行されているか」を根拠に対応要否を判断します。

**攻撃対象領域（アタックサーフェス）の最小化**

- **ベースイメージの最小構成化**: 実行に不要なパッケージやシェルをイメージから徹底排除し、潜在的な CVE 検出数の母数自体を削減します。distroless、Chainguard/Wolfi、`slim` タグ、`scratch` などの最小イメージを採用します。

**運用プロセスの自動化とゲート化**

- **CI パイプラインにおける品質ゲート化**: 検出された脆弱性の重大度（CVSS スコア等）に応じて、ビルドやデプロイ処理を自動停止させます。初期運用ではレポート出力のみから開始し、段階的にブロック条件を厳格化する漸進的な導入が現実的です。
- **自動更新運用の定着（MTTR の短縮）**: 依存ライブラリやベースイメージの更新処理を自動化し、脆弱性の検出から修正適用までの平均修復時間（MTTR）を短縮します。Dependabot や Renovate による Pull Request の自動生成・テスト実行が代表的です。

> 出典:
> - [Trivy](https://trivy.dev/)
> - [OSV](https://osv.dev/)
> - [CycloneDX](https://cyclonedx.org/) / [SPDX](https://spdx.dev/)（SBOM 標準形式）
> - [OpenVEX](https://github.com/openvex)
> - [Renovate](https://docs.renovatebot.com/)

### マルウェア・悪性依存対策

依存パッケージへの悪意あるコードの混入経路（アカウント乗っ取りによる不正公開、タイポスクワッティング、依存関係の混同/Dependency Confusion、ビルド・公開パイプラインの侵害等）に対し、取り込み前の遅延・検証・遮断と、取り込み後の動的検知を多層で組み合わせて防衛します。

**取り込み対象の決定論的固定**

- **依存関係バージョンの完全固定**: ロックファイル（`package-lock.json`、`pnpm-lock.yaml`、`poetry.lock` 等）を用いて推移的依存関係を含めたバージョンを固定し、コンテナイメージや外部アーティファクトは可変タグではなく digest（`@sha256:` / コミット SHA）でピン留めします。CI 環境ではロックファイルの完全再現インストール（`npm ci`、`pnpm install --frozen-lockfile`）を徹底します。
- **リリース経過期間（cooldown）の設定**: パッケージレジストリに公開された直後の新バージョンを、一定期間インストールの対象から除外する待機ルールを導入します。具体的には、pnpm の `minimumReleaseAge`、npm CLI 11.10.0 の `min-release-age`、Yarn 4.10 の `npmMinimalAgeGate`、Bun 1.3 の `minimumReleaseAge`、および Renovate や Dependabot が提供する cooldown 機能などが該当します。
- **依存関係差分および lockfile 差分の明示的レビュー**: パッケージ更新時において、lockfile の diff および新規追加された推移的依存関係を精査し、意図しないライブラリの追加や参照レジストリのすり替えを検知します。

**侵入経路の遮断**

- **typosquatting および dependency confusion 対策**: スコープ付きパッケージ名（`@org/...`）の厳格な利用、組織内固有パッケージ名のパブリックレジストリ上での予防的プレースホルダー予約、`.npmrc` 等におけるスコープ別レジストリルーティング設定、および Python インストーラーにおける index 固定を行い、社内用パッケージが外部公開レジストリへ解決されるリスクを排除します。
- **レジストリプロキシと許可リスト（allowlist）管理**: JFrog Artifactory、Verdaccio、Google Artifact Registry の remote repository 機能等を用いて外部レジストリへのアクセスを一元プロキシ化し、許可リストに基づいて取得元および取得可能パッケージを制限します。
- **依存関係ファイアウォール（取り込み前ブロック）**: レジストリプロキシ層において、取得しようとするパッケージの悪意・危険性を判定し、ローカル環境のディスクに書き込まれる前に事前遮断します。CI や手元での事後スキャンと異なり `install` 前に停止するため、`postinstall` 等の任意コード実行スクリプトを発火させません。takumi guard（GMO Flatt Security）、Sonatype Nexus Firewall、GitLab Dependency Firewall、JFrog Curation 等が該当します。
- **取り込み前の検疫（Quarantine）プロセス**: 新規導入および更新パッケージを検疫用レジストリ領域に一時隔離し、セキュリティスキャン通過後に本番用フィードへ昇格（プロモーション）させます。
- **ライフサイクルスクリプトの無効化**: パッケージインストール時における任意コード実行処理を停止します。npm v12 以降は既定でスクリプトが無効化され `allowScripts` による許可制に移行しています（v12 未満では `--ignore-scripts` を明示的に指定）。pnpm の `onlyBuiltDependencies` による個別許可制、`@lavamoat/allow-scripts` 等も同様の目的で使用します。

**信頼性と来歴の検証**

- **デジタル署名および provenance の検証**: npm provenance、PyPI の Trusted Publishing と PEP 740 デジタル attestation、Sigstore 等を活用し、配布パッケージが正当なソースコードおよび指定のビルドワークフローから生成されたことを検証します。
- **OSS プロジェクトの健全性評価（採用前）**: 依存パッケージを新規採用・追加する前に、対象 OSS のセキュリティ健全性を評価します。**OpenSSF Scorecard** は、ブランチ保護・コードレビュー・保守状況（Maintained）・署名付きリリース（Signed-Releases）・危険なワークフロー（Dangerous-Workflow）・ワークフロートークン権限（Token-Permissions）・依存関係のピン留め（Pinned-Dependencies）・SAST・セキュリティポリシーの定義・既知の未修正脆弱性など、多数のセキュリティ実践項目を自動評価し、0〜10のスコアで可視化します（CLI・GitHub Action・REST API 経由で実行可能であり、結果は deps.dev 経由でも参照可能です）。あわせて **deps.dev**（依存グラフと OSV 脆弱性情報の横断参照サービス）や **OpenSSF Criticality Score**（プロジェクトの重要度スコア）を活用し、採用候補の比較および選定を行います。
- **メンテナ健全性・bus factor の評価**: スコア数値のみならず、開発・保守体制における構造的な弱点も評価します。単独メンテナによる運用、保守停止（放置状態）、後継者不在といった重要依存パッケージでは、ソーシャルエンジニアリングによるアカウント乗っ取りや、悪意ある第三者への保守権限譲渡が発生するリスクが高まります（第1章で解説した **xz Utils**（単独メンテナへ長期的に取り入って権限を奪取した事例）や **event-stream**（保守権限の譲渡事例）が代表例です）。リリース頻度・セキュリティポリシーの有無・CVE への対応速度・コントリビューターの分散度合い（bus factor）を確認し、リスクが高い依存パッケージについては代替候補への切り替えや重点的な継続監視を検討します。

**悪性挙動および既知マルウェアの検知**

- **静的・動的振る舞い解析および install スクリプト解析**: Socket、Phylum、Endor Labs 等の解析ソリューションを用い、コードの難読化・不審な外部通信・環境変数や資格情報へのアクセス動作を早期検知します。
- **既知マルウェアデータベースとの照合**: OSV や GitHub Advisory Database の悪性パッケージデータベースと照合し、既知のマルウェアを自動遮断します。

> 出典:
> - [pnpm supply chain security](https://pnpm.io/supply-chain-security)
> - [PyPI Trusted Publishing](https://docs.pypi.org/trusted-publishers/) / [PEP 740](https://peps.python.org/pep-0740/)
> - [OpenSSF Scorecard](https://securityscorecards.dev/) / [Scorecard checks](https://github.com/ossf/scorecard/blob/main/docs/checks.md)
> - [deps.dev](https://deps.dev/) / [OpenSSF Criticality Score](https://github.com/ossf/criticality_score)
> - [OSV](https://google.github.io/osv.dev/)

### アカウント・秘密情報の保護

axios のメンテナアカウント乗っ取りインシデント、Shai-Hulud による npm トークン窃取、tj-actions における CI シークレット漏洩などは、いずれも「認証情報が奪取され、不正利用された」ことが共通の根本原因です。ここでは、認証情報の漏洩・悪用を根絶するための対策を提示します。

- **多要素認証（MFA）の厳格な義務化**: パッケージメンテナおよび開発者アカウントに対して、フィッシング耐性を備えた 2要素認証を強制適用します。passkey / WebAuthn（FIDO2）やハードウェアセキュリティキー（YubiKey 等）を採用し、SMS や TOTP などの過信を避けます。npm は主要パッケージのメンテナに対して 2FA を義務化しており、GitHub も全開発者アカウントに対して 2FA を必須化しています。
- **Trusted Publishing / OIDC パブリッシュへの移行**: 長寿命の API トークンをパッケージのパブリッシュ処理に使用せず、CI/CD パイプラインから OIDC 連携により発行された短命な一時トークンを用いて公開します。npm Trusted Publishers や PyPI Trusted Publishing が該当し、パブリッシュと同時にビルドのアテステーション（provenance）を自動生成できます。crates.io や NuGet においても導入が進んでおり、盗用された固定トークンによる不正パブリッシュのリスクを構造的に遮断しています。
- **静的暗号鍵を保存しない OIDC 認証連携**: クラウドインフラや外部サービスとの認証において長寿命の静的アクセスキーを保存・運用せず、OIDC フェデレーションを用いて一時的なアクセス資格情報を動的取得します。GitHub Actions の OIDC と AWS IAM Roles / Google Cloud Workload Identity Federation / Azure Workload Identity との連携が代表例です。
- **トークン権限の最小化と有効期限管理**: トークンは細粒度なスコープ制限（fine-grained PAT 等）を付与して発行し、有効期限の設定、定期的なローテーション、および即時失効プロセスを確立します。npm では従来の classic token の廃止が進められています。CI パイプラインにおいては `GITHUB_TOKEN` の `permissions` 定義を明示的に最小化し、シークレットの参照範囲を環境・リポジトリ単位で絞り込みます。
- **シークレットスキャンおよび Push Protection の導入**: ソースコードリポジトリや CI 設定内に誤ってコミット・露出された認証情報を自動検出します。GitHub Secret Scanning とその Push Protection 機能、gitleaks、TruffleHog 等を組み合わせ、コミット前・プッシュ時・コミット履歴の全フェーズで検出体制を維持します。
- **シークレットの集中管理とログ出力を防ぐ秘匿化**: 認証情報をソースコードや CI ワークフロー定義内に平文で保持させず、専用のシークレット管理システム（HashiCorp Vault、AWS Secrets Manager、GitHub Actions Secrets 等）で一元管理し、CI 実行ログにおけるマスキング表示を徹底します。
- **アカウントの公私分離と専用 CI アイデンティティの利用**: 個人の開発者アカウントとリリース運用・自動化用アカウントを明確に分離し、CI 処理には専用の bot / サービスアカウントを割り当てることで、個人アカウント侵害時の影響範囲を局所化します。
- **SSO / IdP による組織統合管理**: 組織内の全アカウントを Identity Provider（IdP）に集約し、SAML SSO、条件付きアクセスポリシー、定期的なアクセス権限レビュー、および退職・組織変更時の一括アクセス失効を自動適用します（GitHub Organization の SAML SSO 等）。
- **Just-In-Time（JIT）アクセス制御の適用**: 特権アクセス権限を常時付与（Standing Privilege）せず、作業発生時にのみ申請・承認を経て一時的に権限を昇格させ、作業完了後は自動的に権限を剥奪します。認証情報が万が一漏洩した場合でも、定常的に悪用可能な権限を最小化できます。
- **リスクベース（適応型）認証の導入**: ログイン要求時のコンテキスト（接続元 IP アドレス、デバイスの健全性、地理的異常等）をリアルタイム評価し、異常検知時に追加認証の要求や接続ブロックを動的に課します。
- **ソーシャルエンジニアリングに対する防衛プロセスの確立**: メンテナ権限の移譲、アカウント追加、緊急アクセス時の対応手順を標準化し、なりすましやフィッシング攻撃による権限奪取を防ぐため、別チャネルでの本人確認や複数人による承認プロセスを義務付けます。

> 出典:
> - [npm Trusted Publishers](https://docs.npmjs.com/trusted-publishers)
> - [GitHub Actions の OIDC](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
> - [GITHUB_TOKEN の permissions](https://docs.github.com/en/actions/security-for-github-actions/security-guides/automatic-token-authentication)
> - [GitHub secret scanning push protection](https://docs.github.com/en/code-security/secret-scanning/push-protection-for-repositories-and-organizations)

### ビルド・パイプラインの保護

SolarWinds におけるビルド環境の侵害、tj-actions におけるサードパーティ Action の汚染、TanStack におけるパイプライン不正利用が突いた「成果物の組み立て工程」の不変性と完全性を防衛する対策群です。ソースコードからデプロイに至る中間フェーズでの改ざんや、CI 環境上の権限奪取を遮断します。

**実行権限とアイデンティティの最小化**

- **ビルド用 SA および実行アイデンティティの最小権限化**: CI パイプラインが使用するサービスアカウントや OIDC 実行アイデンティティに対し、該当ジョブの実行に必要な権限のみを付与します。OIDC フェデレーション設定により、トークン発行対象をリポジトリ・ブランチ・環境単位で厳格に限定し、長期的なクラウドアクセスキーの利用を廃止します。
- **ビルド処理とデプロイ処理の厳格な分離**: ビルド実行用とデプロイ実行用でサービスアカウント・起動トリガー・ワークフロー定義を完全に分離し、ビルドの成功が自動的にデプロイ権限の昇格に繋がらないパイプライン構造を構築します。

**ビルド環境の分離と無菌化**

- **環境隔離・使い捨てランナー・Hermetic Build の実現**: ジョブの実行ごとに完全にクリーンなビルド環境を用意し、外部ネットワークへの不要な依存や過去の実行状態の残留を排除した完全隔離ビルド（Hermetic Build）を確立します。入力要素を決定論的に固定できるため、再現可能なビルド（Reproducible Build）の必要条件となります。適用目安は SLSA Build L3 です。
- **使い捨て型（ephemeral）セルフホストランナーの運用**: セルフホストランナーを運用する場合は、1ジョブの実行完了ごとに環境を破棄・再生成する ephemeral runner として構成し、永続ランナー上に未検証の外部コードやステートが残留しないよう管理します。

**provenance の自動生成と暗号検証**

- **provenance（来歴情報）の生成とアテステーション発行**: 成果物が「どのソースコードから・どのビルド環境で・どのような入力を用いて」生成されたかを示す機械可読な記録（provenance）を自動生成します。これに対してデジタル署名を付与し、改ざん防止および真正性の検証を可能とした構造が attestation（アテステーション）です。ここで in-toto Attestation Framework は、検証・署名対象を Statement（対象成果物の記述）と Predicate（主張内容）に構造化する汎用フォーマットであり、SLSA provenance・SBOM・VEX はいずれもこの Predicate の種別として標準化されています（in-toto がメタデータ署名・検証の共通枠組みであり、SLSA/SBOM/VEX がその内部に格納される具体的なデータ構造という階層関係となります）。具現化された実装手段としては、SLSA provenance、in-toto attestation、GitHub artifact attestations、Cloud Build の `built-by-cloud-build` provenance などを活用します。
- **コンテナイメージおよび成果物への暗号署名**: 生成されたビルド成果物やコンテナイメージに対し暗号署名を付与し、検証を必須条件として配信・運用します。`cosign` / Sigstore によるキーレス署名（Keyless Signing）を採用し、透明性ログ（Rekor）への記録と検証を実施します。
- **再現可能なビルド（Reproducible Build）の検証**: 同一のソースコードおよびビルド入力から常にバイナリレベル（bit-for-bit）で一致する成果物が生成されることを検証・担保します。これは「環境の隔離（Hermetic Build による入力固定）」と「ビルド処理の決定論化」の両輪で達成されます。後者においては、タイムスタンプの埋め込み固定（`SOURCE_DATE_EPOCH`）、ファイル読み込み順序の正規化、乱数シードの固定など、コンパイラやビルドスクリプト側の非決定性をコード側で排除する必要があります。provenance やデジタル署名と組み合わせることで、第三者が同一成果物を独立して再構築し、妥当性を検証することが可能となります。

**依存関係およびパイプライン定義の固定・保護**

- **サードパーティ製 GitHub Action および依存関係の完全固定**: ワークフロー内で利用する Action や外部ビルドステップを可変タグ（`v1` や `latest`）ではなく、コミット SHA または digest で固定（ピン留め）し、改ざん不能な不変アクション（immutable actions）として運用します。
- **ビルド定義およびパイプライン設定ファイルの保護**: ワークフロー定義ファイル（`.github/workflows/*` 等）を `.github/CODEOWNERS` およびブランチ保護ルールで厳重に保護し、パイプライン定義の変更に対して手動コードレビューを必須化します。
- **コミット署名と組織的な保護ルールの一括強制**: コミットやタグへの署名（GPG に加え、鍵管理を簡素化する SSH 署名や Sigstore/gitsign によるキーレス署名）により、作成者と変更内容の完全性を検証可能にします。従来のブランチ保護（Branch Protection）に代えて GitHub Repository Rulesets を活用することで、必須署名・必須レビュー・線形履歴などの保護ルールを組織単位で一括強制でき、リポジトリごとの設定漏れを防止します。
- **重要設定変更に対する電子署名および複数人承認**: パイプライン設定の変更やリリース定義の更新に対し、デジタル署名の付与と複数人の事前承認を必須化します（NSA/CISA ガイダンスに準拠）。

**未検証入力およびイベントトリガーの制御**

- **PPE（Poisoned Pipeline Execution）攻撃の防止**: サードパーティからの未検証な Pull Request コードを、特権コンテキスト（シークレット参照権限や書き込み権限を保有する環境）で直接 checkout・実行させない構造とします。`pull_request_target` イベントを安全に定義し、フォーク由来のトリガーに対してシークレットや書き込み権限が渡らないよう制限します。
- **ビルドキャッシュ汚染の防止**: ビルドキャッシュ領域をブランチ・実行スコープごとに分離・隔離し、未検証ジョブによって書き込まれた悪意のあるキャッシュデータを信頼性の高いビルドジョブが読み込まないよう制御します。
- **CI ワークフロー定義の静的解析**: `.github/workflows/*` などのパイプライン定義自体を静的解析し、`GITHUB_TOKEN` への過剰な権限付与、`pull_request_target` の不適切な利用、コミット SHA 未固定の Action 参照といった設定上の不備を検出します（zizmor や actionlint 等）。PPE（Poisoned Pipeline Execution）のリスク混入を CI ゲートで検出・阻止します。

**実行時ネットワーク制御とランナーの挙動監視**

- **Egress（アウトバウンド）通信制限の適用**: ビルドランナーからの外部送信通信を事前承認されたドメイン・IP のみに制限し、不審な C2 サーバーへのデータ持ち出し経路を遮断します。ネットワーク層（プロキシ、ファイアウォール、DNS フィルタ、Kubernetes NetworkPolicy 等）およびランナー上の通信制御エージェントを用いて適用します。
- **eBPF を活用したランナー挙動のリアルタイム監視**: ネットワーク通信・ファイル書き込み・プロセス生成処理を eBPF（Extended Berkeley Packet Filter）を用いてカーネルレベルで監視し、各システムコールをワークフローの実行ステップと紐付けて可視化・監査します（StepSecurity Harden-Runner、GMO Flatt Security Takumi Runner、OSS の cicd-sensor 等）。宛先許可リストによる異常通信遮断に加え、想定外のプロセス起動やメモリ走査動作の検知に活用されます。tj-actions のセキュリティインシデントは、この Egress 通信の異常検知機能によって発見・解明されました。

**IaC（Infrastructure as Code）のサプライチェーン保護**

Terraform 等の IaC コードも、外部のプロバイダーやモジュールを取り込み、広範なクラウドインフラ権限で実行されるため、アプリケーションコードと同様にサプライチェーン対策の対象となります。

- **モジュールおよびプロバイダーの固定とチェックサム検証**: 利用するプロバイダーのバージョンおよびチェックサムを依存関係ロックファイル（`.terraform.lock.hcl`）に記録して固定します。外部モジュールは可変な Git 参照ではなく明確なバージョン指定で取得し、社内共有モジュールはプライベートレジストリで管理します。
- **plan 処理と apply 処理の最小権限分離**: インフラ変更内容を評価する読み取り権限（`plan`）と、実際の変更を適用する書き込み権限（`apply`）で実行権限を分離し、`apply` 処理は OIDC による短命な資格情報と最小権限のみで実行します。未検証の Pull Request 段階で `apply` を自動実行させない構成とします（PPE リスクの排除）。
- **ステートファイル（tfstate）の暗号化とアクセス制御**: tfstate ファイルには平文のシークレットが含まれる可能性があるため、適切なアクセス権限が設定されたリモートバックエンド（GCS バケット等）で暗号化して保管し、参照権限を限定します。
- **変更差分のレビュー強制と静的スキャン**: インフラ変更に対し第三者レビューを必須化し、Policy-as-Code ツール（OPA/Conftest、Sentinel 等）および IaC 用静的スキャンツール（Checkov、Trivy 等）を用いて、危険な設定変更を CI ゲートで未然に遮断します。

> 出典:
> - [SLSA Build Levels](https://slsa.dev/spec/v1.0/levels)
> - [Sigstore / cosign](https://www.sigstore.dev/)
> - [GitHub Artifact Attestations](https://docs.github.com/en/actions/security-guides/using-artifact-attestations-to-establish-provenance-for-builds)
> - [StepSecurity Harden-Runner](https://docs.stepsecurity.io/harden-runner)
> - [Takumi byGMO — Runner 機能（eBPF によるビルド時トレース）](https://flatt.tech/takumi/features/runner)
> - [cicd-sensor（CI/CD ランナー向け eBPF ランタイムセキュリティ）](https://github.com/cicd-sensor/cicd-sensor)
> - [CI/CD Build Hardening: eBPF, Runtime SBOMs, and SLSA Attestation（Cycode）](https://cycode.com/blog/cicd-build-hardening/)
> - [Bomfather: eBPF-based Kernel-level Monitoring for Software Supply Chains（arXiv 2503.02097）](https://arxiv.org/abs/2503.02097)
> - [in-toto](https://in-toto.io/)
> - [Terraform Dependency Lock File（.terraform.lock.hcl）](https://developer.hashicorp.com/terraform/language/files/dependency-lock)
> - [Checkov](https://www.checkov.io/)

### デプロイ・実行時の検証と保護

ビルドフェーズで生成された暗号署名や provenance をデプロイ時に検証して受け入れる仕組み、実行環境における不正動作の監視・遮断、および万が一の侵害発生を前提としたクラウド環境側での被害局所化（影響半径の限定）を扱います。

**デプロイ前検証プロセス**

- **provenance およびデジタル署名の検証**: デプロイ対象のコンテナイメージに付与された暗号署名および provenance（SLSA provenance）を検証し、正規のビルドパイプラインを経由して生成された成果物であることをデプロイ直前に確認します（`cosign verify` / `verify-attestation`、`slsa-verifier`）。
- **検証ルールの明示的定義**: 署名の有無のチェックにとどまらず、要求する attestation の種別、遵守すべき SLSA レベル、信頼するアテスター（署名者の Identity および OIDC Issuer）をポリシーとして明示的に定義し、ソースリポジトリ URI や実行ワークフローの完全一致まで検証します。

**デプロイフェーズにおけるポリシー強制**

- **アドミッション制御（Admission Control）による自動検証**: Kubernetes クラスタ等へのデプロイ時において、アドミッションコントローラーによりポリシー検証を強制適用し、検証未完了および不適合なアーティファクトのデプロイを遮断・拒否します（Sigstore policy-controller、Kyverno `verifyImages`、OPA/Gatekeeper）。
- **プラットフォーム統合型のデプロイ検証機能**: マネージドクラウド環境が提供する署名検証機能を有効化し、インフラレベルでデプロイ制限を強制します（Google Cloud Run / GKE Binary Authorization、AWS Signer / ECR 連携等）。
- **信頼できるコンテナレジストリの限定と digest ピン留め**: 組織で承認された正規レジストリ・リポジトリからのイメージのみデプロイを許可し、ダイジェスト（`@sha256:`）によるピン留めを強制することで、可変タグの差し替え攻撃を無効化します。
- **リリース管理と段階的プロモーション・手動承認プロセス**: デプロイ処理を「リリース」単位で透過的に管理し、本番環境への適用前に明示的な手動承認（Approval）を要求する仕組み、環境間での段階的なプロモーション、および障害発生時の過去リリースへのロールバック手順を整備します。ビルド成功が即座に本番反映へ直結しない職務分掌をデプロイフェーズで担保します（Google Cloud Deploy、Argo CD/Argo Rollouts）。

**実行時（Runtime）の保護と動的監視**

- **eBPF を活用した実行時動作監視**: 実行中ワークロードのシステムコール、プロセス生成、外部ネットワーク通信をリアルタイム監視し、不審なアクティビティ（想定外のシェル実行、C2 通信、権限昇格の試み等）を検知・即座に遮断します（Falco、Tetragon）。
- **Egress 通信制限とネットワークポリシー**: 実行中ワークロードからのアウトバウンド通信を事前承認された接続先にのみ限定し、C2 サーバーへの接続やデータの外部流出経路を遮断します（Kubernetes / Cilium NetworkPolicy、FQDN ベースの Egress 制御）。
- **実行アイデンティティの最小権限化と Workload Identity の適用**: 実行プロセスに対して長期的な静的アクセスキーを持たせず、短命なアクセス資格情報による OIDC 連携と最小権限を徹底します（GKE Workload Identity、EKS Pod Identity、SPIFFE/SPIRE）。
- **イミュータブルインフラおよび読み取り専用実行環境の維持**: コンテナのルートファイルシステムを読み取り専用（Read-only）に設定し、非 root ユーザー実行・Linux Capability の剥奪・特権昇格の禁止（`allowPrivilegeEscalation: false`）と組み合わせることで、実行時におけるコンテナ環境の改変を不可能にします。
- **設定ドリフトおよび差分の継続検知**: 稼働中のデプロイメント状態が宣言された定義ファイル（Git）から乖離していないかを継続的に監視・検証します（GitOps ツールによるドリフト検知: Argo CD/Flux、実行コンテナイメージの digest 照合）。

**クラウド環境全体の防衛（侵害発生を前提とした影響局所化）**

依存関係や CI パイプラインの侵害により正規のデプロイ経路を経由して攻撃が侵入した場合であっても、クラウドプラットフォーム側のセキュリティ設定によって被害範囲を局所化し、異常動作を早期検知します。予防策をすり抜けることを前提としたインフラ層での堅牢化です。短命な資格情報（OIDC/Workload Identity）の利用は有効ですが、攻撃者が環境内に足場を確立し継続的に資格情報を再取得できる状況においては完全な防御となり得ません。そのため、マルチアカウント分離・予防的ガードレール・監査検知の多重化を適用します。

- **マルチアカウント/プロジェクトによる環境隔離**: 本番環境・ステージング環境・開発環境をクラウドのアカウント / プロジェクト / サブスクリプション単位で物理的に分離し、単一環境の侵害が他環境へ波及（ラテラルムーブメント）しない構成とします（AWS アカウント分離、Google Cloud プロジェクト分離、Azure サブスクリプション分離）。
- **予防的ガードレール（組織ポリシー）の全社適用**: クラウド組織全体に適用される予防的統制ルールを設定します。未承認サービスや未指定リージョンの利用制限、管理者アカウントへの MFA 強制、監査ログおよびセキュリティ機能の無効化禁止、リソースの意図しないパブリック公開の制限等を実施します（Google Cloud 組織ポリシー、AWS SCP/Service Control Policies、Azure Policy）。
- **コントロールプレーン層における操作異常検知**: クラウド基盤の操作監査ログ（Google Cloud Cloud Audit Logs、AWS CloudTrail）をリアルタイム解析し、平常と異なるリージョンや国外からのアクセス、短時間での多数の認証失敗、新規 API キーの発行、未知のデバイス登録などの不審な操作を即座に検知します。ワークロード内部の監視とは独立した、管理プレーン層での監視体制を構築します。
- **コスト異常検知および予算アラートの設定**: クラウド利用料金およびリソース消費量の急速な増加を監視・検知します。攻撃者による暗号資産マイニングや不正な計算リソースの乱用は、構成上の異常が判明するより前にコストの異常高騰として顕在化することが多く、インシデントの早期発見につながります（予算アラート、コスト異常検知機能）。

> 出典:
> - [Sigstore cosign（verify）](https://docs.sigstore.dev/cosign/verifying/verify/)
> - [Kyverno（verify images）](https://kyverno.io/docs/writing-policies/verify-images/)
> - [GKE Binary Authorization](https://cloud.google.com/binary-authorization/docs)
> - [Falco](https://falco.org/docs/)
> - [Kubernetes Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
> - [Google Cloud Organization Policy Service](https://docs.cloud.google.com/organization-policy/overview) / [AWS Organizations SCP](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_scps.html)
> - 参考: [Software Supply Chain Attack からクラウド環境を守るためにできること（lhazy）](https://speakerdeck.com/lhazy/software-supply-chain-attackkarakuraudohuan-jing-woshou-rutamenidekirukoto)

### 横断的なガバナンス・プロセス

脆弱性対策、マルウェア対策、アカウント保護、ビルド保護、デプロイ検証の各技術施策を、一時的な取り組みに終わらせず、組織全体として継続運用・改善していくための横断的ガバナンス構造を確立します。

**ポリシーおよびコードレビューの機械的強制**

- **Policy-as-Code による統制**: セキュリティ要求仕様をコードとして定義し、CI/CD パイプラインおよびクラスタ環境へ機械的に適用・検証します。定義したポリシーコード自体もバージョン管理・ピアレビュー・自動テストの対象とします（OPA/Rego、Kyverno 等）。
- **コードレビューの厳格な強制**: すべてのコード変更に対し、必ず第三者によるレビューを経てからマージするプロセスを固定化します。保護ブランチルール、必須レビュー数指定、複数人承認ポリシー、`CODEOWNERS` の定義を組み合わせます。
- **改ざん耐性のある操作監査ログの保持**: リポジトリ、CI/CD パイプライン、クラスタ、およびクラウドインフラの操作ログを自動記録し、改ざん不能なストレージへ長期間保管して追跡性およびインシデント発生時の事後フォレンジック調査に利用します。

**成果物構成の透明化と可視性追跡**

- **SBOM の全社運用プロセス**: すべての構築成果物に対して SBOM を自動生成・集約保管・配布する体制を整え、新規 CVE が公開された際に過去の全成果物から影響対象を即座に特定できる状態を維持します。
- **VEX 運用の標準化**: 検出された脆弱性について、自社プロダクトでの悪用可能性の有無を公式に整理・表明・配布し、影響しない脆弱性への無駄な修正対応や混乱を防ぎます（OpenVEX、CSAF VEX）。
- **リスクベースによる対応優先順位付け**: 脆弱性の深刻度（CVSS）、実際の悪用状況（EPSS、CISA KEV カタログ）、コード上の到達可能性を総合評価し、修正対応の優先順位を決定します。

**サプライチェーン調達管理と組織統制**

- **サプライヤーセキュリティ評価および調達管理**: 導入・依存する外部コンポーネントおよびベンダーのセキュリティ管理体制を事前評価し、調達プロセス全般にサプライチェーンリスク管理（C-SCRM）を組み込みます（NIST SP 800-161 に準拠）。
- **開発者および運用者向け教育訓練の継続実施**: 開発者、メンテナ、インフラ運用者を対象に、セキュアコーディングおよびサプライチェーンセキュリティリスクに関する教育・トレーニングを継続的に提供します。

**継続的改善とインシデント対応体制**

- **サプライチェーンインシデント対応プレイブックの整備**: サプライチェーン侵害の発生を想定した具体的な対応要領（プレイブック）を作成し、provenance や SBOM を用いて影響を受けた成果物・バージョンを即座に特定し、証明書の失効・差し替え・鍵ローテーション・任意コードの隔離を迅速に遂行できる体制を構築します。
- **成熟度モデルに基づく継続的評価と改善**: 到達目標とするフレームワーク（NIST SSDF、SLSA、S2C2F 等）を選択し、自社の現状を定期的に評価・測定することで、段階的にセキュリティ成熟度を引き上げます。

> 出典:
> - [CISA Known Exploited Vulnerabilities](https://www.cisa.gov/known-exploited-vulnerabilities-catalog)
> - [EPSS](https://www.first.org/epss/)
> - [NIST SP 800-161r1（C-SCRM）](https://csrc.nist.gov/pubs/sp/800/161/r1/final)

## 目的別対策の一覧

本章で扱った各種セキュリティ対策を、「目的（どのような脅威に効力を持つか）」および対応する事例・演習課題と対比させて一覧で示します。第1章で定めた「段階」「人・プロセス・技術」に対する「何に効くか」の評価軸による整理です。

| 分類 | 効く脅威（対象リスク） | 代表的なセキュリティ対策 | 事例・対応演習 |
| --- | --- | --- | --- |
| 1. 脆弱性対策 | 依存ライブラリやベースイメージに含まれる既知の脆弱性（CVE） | SCA スキャン、SBOM 生成、VEX 運用、継続的スキャン、最小構成イメージ（distroless 等）、パッチ適用・自動更新運用 | Log4Shell / 演習01・演習07 |
| 2. マルウェア・悪性依存対策 | 悪意あるコードの混入（悪性バージョンの公開、typosquatting、dependency confusion、ビルド/公開系の侵害等） | 依存関係の決定論的固定（lockfile/digest）、cooldown（min-release-age）、レジストリプロキシ/許可リスト管理、依存関係ファイアウォール（取り込み前ブロック）、OSS 健全性評価（Scorecard）、`--ignore-scripts`、悪性振る舞い検知 | Shai-Hulud / axios / 演習03・演習08 |
| 3. アカウント・秘密情報の保護 | アカウントのなりすまし・認証情報の窃取および不正利用 | 多要素認証（MFA/passkey）、Trusted Publishing/OIDC 連携、短命トークン利用、JIT アクセス/リスクベース認証、Secret Scanning、公私アカウント分離 | axios（メンテナ乗っ取り） / tj-actions / 演習04 |
| 4. ビルド・パイプラインの保護 | 成果物組み立て工程の乗っ取り（PPE・ビルド改ざん・キャッシュ汚染等） | ビルド用 SA の最小権限化、完全隔離・使い捨てビルド環境（SLSA Build L3）、provenance の自動生成、成果物への暗号署名、Action・依存関係のコミット SHA/digest 固定、ランナー保護（eBPF 監視）、ビルドとデプロイの分離、IaC モジュール/プロバイダー固定および plan/apply 権限分離 | SolarWinds / tj-actions / TanStack / 演習02・演習04・演習06 |
| 5. デプロイ・実行時の検証と保護 | 未検証成果物のデプロイ・実行時における不正動作・侵入後の被害拡大 | provenance/暗号署名の事前検証、Binary Authorization・アドミッション制御、eBPF による実行時動作監視、Egress 通信制限、ネットワークポリシー、環境分離・組織ポリシーによるガードレール設定、コントロールプレーン監視・コスト異常検知 | TanStack / 演習05・演習10・演習11 |
| 横断: ガバナンス・プロセス | 各対策を組織的・継続的に運用・改善していく仕組み | Policy-as-Code の適用、レビューの機械的強制（複数人承認）、SBOM/VEX 全社運用、インシデント対応プレイブック、リスクベース優先順位付け | 演習09 / 対策選定の観点 |

## 現実的な制約と対応の落とし所

本章ではあるべき対策を網羅的に整理しました。しかし実際の導入は、限られた予算・人員・時間の中で行われます。すべての対策を同時に、全システム・全ユーザーへ網羅的に適用することは現実には困難です。理想と現実のギャップを踏まえ、どこを優先し、どこを落とし所とするかを整理します。

### 直面する現実的な制約

- **すべてを一度に導入できない。** 予算・人員・時間が有限であり、各種フレームワークが定義する対策を一律に満たすには長い期間を要します。
- **網羅的に強制することが難しい。** 有効な対策であっても、レガシー環境・例外運用・新規リポジトリなどに設定漏れが生じやすく、組織全体へ継続的に反映させ続けることは困難です。
- **残余リスクは必ず残る。** 予防手法のみでは限界があり（署名や provenance の偽装、ビルド環境の侵害、未知のゼロデイ攻撃など）、対策を重ねても発生確率をゼロにすることはできません。
- **開発生産性とのトレードオフがある。** 過度な検証やブロックは開発の摩擦・誤検知・アラート疲れを生み、かえって形骸化や迂回を招きます。
- **自社の統制が直接及ばない領域がある。** 外部 OSS のメンテナ、サードパーティ Action、業務委託先など、直接管理できない領域が常に残ります。

### 対応の落とし所

- **特定の対策を全システム・全ユーザーに漏れなく適用することは難しいため、共通基盤側で一律に強制する。** SHA/digest のピン留めや cooldown のように有効な対策であっても、各開発者・各リポジトリの個別設定に委ねる限り、レガシー環境・例外運用・新規リポジトリなどに設定漏れが生じ、組織全体へ継続的に反映させ続けることは困難です。個々の開発者の裁量に依存させず、レジストリプロキシ・組織ポリシー・アドミッション制御・Policy-as-Code などの共通基盤側で一括適用（シフトダウン）することで、設定漏れと迂回を構造的に防ぎます。
- **効果が高く低コストな基盤対策から優先的に徹底する。** サプライチェーン攻撃は件数・規模ともに急増し、自己増殖するワーム（Shai-Hulud）や公開直後の短時間を突く手口（axios 型）のように自動化・高速化が進んでいるため、統制体制の整備完了を待たずに早期のリスク低減を図る必要があります。すべての対策を一度に一括適用することは困難であるため、まずは費用対効果が高い基盤対策——依存関係およびコンテナイメージの不変固定（lockfile ＋ digest/コミット SHA のピン留め）、cooldown（`min-release-age` 等による公開直後バージョンの回避）、install スクリプトの既定無効化、MFA/Trusted Publishing——を横断的に適用します。導入・運用コストが高い、あるいは文脈依存の強い対策（provenance 署名・Binary Authorization・eBPF 実行時監視等）は、これに続けて段階的に導入します。
- **残余リスクは検知・事後対応をバックストップとし、リスク受容も明示的な選択肢とする。** 予防で防ぎきれない部分は、実行時監視・Egress 通信制限などの検知と、影響範囲の特定・証明書の失効・鍵ローテーション・ロールバックといった事後対応で受け止めます。対策コストに見合わない低リスク領域は、リスクを受容することも判断のうちとします。
- **短期間での網羅を目指さず、段階的に成熟度を高める。** 初期はレポート出力のみとし段階的にブロックへ、監査モードから強制モードへ、というように既存環境への影響を確認しながら移行します。成熟度モデル（SSDF・SLSA・S2C2F）で定期的に現状を評価し、優先度の高い領域から継続的に改善します。
- **Shift Left と Shift Down を対立させず組み合わせる。** 取得時・コミット時などの早期段階で検証して開発者に即時フィードバックする Shift Left と、それをすり抜けたものを共通基盤側でポリシー強制してガードする Shift Down は、二者択一ではなく両輪で機能させます。前者で予防と学習を促し、後者で設定漏れを構造的に塞ぐ、という役割分担で施策全体を設計します。
