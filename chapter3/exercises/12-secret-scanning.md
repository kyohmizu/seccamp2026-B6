# 演習12: Secret Scanning

[Trivy](https://trivy.dev/) の secret スキャナを使用して、ソースコードやコンテナイメージに認証情報（API キー・トークン・秘密鍵など）が混入していないかを機械的に検出します。検出を CI に組み込み、秘密情報を含んだままのコミットやイメージ公開を止められる状態を目指します。

## 関連
- 1-1 axios（メンテナアカウントの奪取）。攻撃の起点は認証情報の窃取であり、リポジトリやログへの認証情報の混入はそれを容易にします。
- 2-2「アカウント・秘密情報の保護」（Secret Scanning）

## 課題
1. **ソースを secret scan**: リポジトリ全体を Trivy の secret スキャナで検査し、現状で検出される秘密情報がないかを確認してください。
2. **検出を体験する**: ダミーの認証情報（実在しない API キーや秘密鍵の文字列）を一時的にファイルへ追加し、スキャンで検出されることを確認してください。確認後は必ず削除します。
3. **イメージを secret scan**: ビルド済みのコンテナイメージを検査し、ビルド成果物に認証情報が焼き込まれていないかを確認してください。
4. **CI に組み込む**: パイプライン（`pipelines/cloudbuild.yaml`）に secret スキャンのステップを追加してください。初期はレポート出力のみ（`--exit-code 0`）とし、慣れたら検出時にビルドを失敗させる（`--exit-code 1`）品質ゲートにします。

<details>
<summary>ヒント</summary>

```bash
# 事前準備: export PROJECT=<your-google-cloud-project> REGION=asia-northeast1
IMG=$REGION-docker.pkg.dev/$PROJECT/flowpay

# 1. ソース（作業ツリー全体）の secret スキャン。認証不要。
trivy fs --scanners secret .

# 2. 検出確認用のダミー（実在しない例。確認後に必ず削除する）
#    ファイルに以下のような行を一時的に追加してスキャンする
#      aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
trivy fs --scanners secret .

# 3. イメージの secret スキャン（成果物への焼き込みを検出）
trivy image --scanners secret $IMG/frontend:latest
trivy image --scanners secret $IMG/backend:latest

# Trivy をローカルに入れていない場合（docker で実行）
docker run --rm -v "$PWD:/work" aquasec/trivy fs --scanners secret /work
```

</details>

## 検証
- ダミーの認証情報を追加した状態でスキャンし、その箇所が検出されることを確認してください。削除後は検出されないことも確認します。
- パイプラインに secret スキャンステップが組み込まれ、ビルドログに結果が出力されていることを確認してください。ゲート化（`--exit-code 1`）した場合は、検出時にビルドが失敗することを確認します。

## 発展
- **手元での事前検出**: pre-commit hook（gitleaks 等）を導入し、コミット前にローカルで検出して混入自体を防ぎます。
- **履歴の検査**: Trivy の `fs` スキャンは作業ツリー（現在のファイル）を対象とするため、過去に一度でもコミットした秘密情報は git 履歴に残ります。履歴全体の検査には gitleaks（`gitleaks detect`）を用います。
- **プラットフォーム側の防御**: GitHub の secret scanning / push protection を有効化し、push の時点でも二重に防ぎます。
- **事後対応**: 検出された認証情報は、リポジトリから削除するだけでなく必ず無効化・ローテーションします（コミット履歴やログから復元され得るため、削除だけでは漏洩が続きます）。
