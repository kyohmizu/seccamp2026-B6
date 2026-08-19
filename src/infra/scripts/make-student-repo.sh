#!/usr/bin/env bash
# src から「実行者ごとの演習用リポジトリ」の中身を生成する。
# 生成物はアプリをリポジトリ直下に配置し、cloudbuild.yaml はルート相対（backend / frontend）。
# これを実行者ごとの GitHub リポジトリに push すると、トリガーの filename は "cloudbuild.yaml" 固定で済む。
#
# 使い方: REG=http://<IP>:4873/ scripts/make-student-repo.sh <出力先ディレクトリ>
#   例:   REG=http://<IP>:4873/ scripts/make-student-repo.sh /tmp/seccamp-b6-student01
#   REG は演習用 npm レジストリURL。frontend の lockfile を正規のバージョン 1.0.0 で固定するために使用する。
set -euo pipefail

DEST="${1:?出力先ディレクトリを指定してください（例: /tmp/seccamp-b6-student01）}"
SRC="$(cd "$(dirname "$0")/../.." && pwd)"   # src

[ -e "$DEST" ] && { echo "既に存在します: $DEST（空のパスを指定してください）" >&2; exit 1; }
mkdir -p "$DEST"

# アプリ本体（リポジトリ直下に配置）
cp -R "$SRC/backend" "$DEST/backend"
cp -R "$SRC/frontend" "$DEST/frontend"
# 作者ローカルの生成物は持ち込まない（node_modules と stale な lockfile を除去）。
rm -rf "$DEST/frontend/node_modules" "$DEST/frontend/package-lock.json"

# 実アプリと同じく lockfile をコミット済みにする（正規のバージョン 1.0.0 で固定）。
# expense-format は公開npmに無いので、演習用レジストリ(REG)から解決する。
if [ -n "${REG:-}" ]; then
  ( cd "$DEST/frontend" && npm install --package-lock-only --omit=dev --registry "$REG" >/dev/null )
  echo "生成: frontend/package-lock.json（$REG から expense-format 1.0.0 を固定）"
else
  echo "WARN: REG 未指定のため package-lock.json を生成していません。" >&2
  echo "      REG=http://<IP>:4873/ を指定して再実行するか、演習リポで手動生成・コミットしてください。" >&2
fi

# CIパイプライン: ルート相対のまま配置（push 版・PRチェック版・deploy版）。
# frontend-deps は npm install（＝演習03で npm ci に是正する）。
cp "$SRC/pipelines/cloudbuild.yaml" "$DEST/cloudbuild.yaml"
# PRチェックは src/frontend 前提なので、ルート相対（frontend）に書き換えて配置。
sed 's#src/frontend#frontend#g' "$SRC/pipelines/cloudbuild.pr.yaml" > "$DEST/cloudbuild.pr.yaml"
# デプロイ用（deploy トリガーがリポから取得）。src/ パスを含まないためそのまま配置。
cp "$SRC/pipelines/cloudbuild.deploy.yaml" "$DEST/cloudbuild.deploy.yaml"

cat > "$DEST/.gitignore" <<'EOF'
node_modules/
*.sbom.cdx.json
# 演習用レジストリURL（環境固有）はコミットしない。ビルド時に _NPM_REGISTRY で注入する。
frontend/.npmrc
EOF

cat > "$DEST/.gcloudignore" <<'EOF'
.git/
**/node_modules/
**/.DS_Store
EOF

cat > "$DEST/README.md" <<'EOF'
# FlowPay（演習用リポジトリ）

main に push すると、Cloud Build トリガーがこのリポジトリの `cloudbuild.yaml` を実行します。
pull_request を開くと `cloudbuild.pr.yaml` が検証ジョブとして走ります。
演習では `cloudbuild.yaml` を編集して、CI/CD のサプライチェーン対策を段階的に加えていきます。

- `backend/` … Go の経費 API
- `frontend/` … Node の Web UI（依存 `package-lock.json` はコミット済み）
- `cloudbuild.yaml` … CIパイプライン
- `cloudbuild.pr.yaml` … PRチェック（依存install＋検証ビルド）
- `cloudbuild.deploy.yaml` … デプロイ（イメージ push を契機に Cloud Run へ反映）

演習の手引きは、第3章の演習資料を参照してください。

## ローカルで依存を扱う場合
frontend の依存 `expense-format` は公開 npm には無く、演習用レジストリ（Verdaccio）から取得します。
手元で `npm install` などを実行する場合は、`frontend/.npmrc` を作成してレジストリ URL を指定してください
（CI はビルド時に `_NPM_REGISTRY` から自動生成するため、この手順は不要です）。

    cp frontend/.npmrc.example frontend/.npmrc
    # frontend/.npmrc の REPLACE_WITH_REGISTRY_IP を演習用レジストリの IP に変更する
EOF

echo "生成しました: $DEST"
echo "  backend/ frontend/ cloudbuild.yaml cloudbuild.pr.yaml cloudbuild.deploy.yaml .gitignore .gcloudignore README.md"
echo
echo "次の手順:"
echo "  1) $DEST を実行者ごとの GitHub リポジトリに push（package-lock.json も含める）"
echo "  2) terraform.tfvars の各 env（environments）に github_repo と以下を設定:"
echo "       cloudbuild_config        = \"cloudbuild.yaml\""
echo "       pr_cloudbuild_config     = \"cloudbuild.pr.yaml\""
echo "       deploy_cloudbuild_config = \"cloudbuild.deploy.yaml\""
echo "  3) 各 env の Artifact Registry 名は cloudbuild.yaml の _REPO 既定値（flowpay）に合わせる"
