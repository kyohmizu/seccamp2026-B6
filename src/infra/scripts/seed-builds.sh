#!/usr/bin/env bash
# apply 直後の Cloud Run はプレースホルダ(hello)イメージなので、各 env で実イメージをビルド＆デプロイする。
# terraform output の environments を元に、env ごとに
#   gcloud builds submit（build+push） → gcloud run services update（backend/frontend）
# を繰り返す。
#
# 使い方: scripts/seed-builds.sh          （全 env）
#         scripts/seed-builds.sh app-01 （特定 env のみ）
set -euo pipefail

cd "$(dirname "$0")/.."                 # src/infra
SRC_DIR="$(cd .. && pwd)"               # src
ONLY="${1:-}"

rows="$(terraform output -json environments | python3 -c '
import json,sys
only = sys.argv[1] if len(sys.argv) > 1 else ""
for k,v in json.load(sys.stdin).items():
    if only and k != only:
        continue
    print("\t".join([k, v["project_id"], v["region"], v["repo_id"],
                     v["backend_name"], v["frontend_name"], v["artifact_registry"]]))
' "$ONLY")"

[ -z "$rows" ] && { echo "対象 env なし（apply 済みか、キー名を確認）" >&2; exit 1; }

while IFS=$'\t' read -r key project region repo bname fname ar; do
  echo "=========================================="
  echo "### seed: $key ($project)"
  subs="_REGION=$region,_REPO=$repo"
  # 演習用レジストリ（expense-format 供給元）を使用する場合は NPM_REGISTRY=http://<IP>:4873/ を渡す
  [ -n "${NPM_REGISTRY:-}" ] && subs="$subs,_NPM_REGISTRY=$NPM_REGISTRY"
  gcloud builds submit "$SRC_DIR" \
    --config "$SRC_DIR/pipelines/cloudbuild.yaml" \
    --project "$project" \
    --substitutions="$subs" \
    --quiet
  gcloud run services update "$bname" --image "$ar/backend:latest"  --project "$project" --region "$region" --quiet
  gcloud run services update "$fname" --image "$ar/frontend:latest" --project "$project" --region "$region" --quiet
  echo "  → done: $bname / $fname を実イメージへ更新"
done <<< "$rows"
