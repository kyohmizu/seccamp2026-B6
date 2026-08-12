#!/usr/bin/env bash
# 各 env の frontend に proxy で疎通し、UI と frontend→backend(サービス間認証) を確認する。
# 外部公開せず、ローカル proxy 経由（実行者は各 frontend の run.invoker が必要）。
#
# 使い方: [PORT=8085] scripts/smoke-test.sh          （全 env）
#         scripts/smoke-test.sh app-01            （特定 env のみ）
set -euo pipefail

cd "$(dirname "$0")/.."                 # src/infra
PORT="${PORT:-8085}"
ONLY="${1:-}"

rows="$(terraform output -json environments | python3 -c '
import json,sys
only = sys.argv[1] if len(sys.argv) > 1 else ""
for k,v in json.load(sys.stdin).items():
    if only and k != only:
        continue
    print("\t".join([k, v["project_id"], v["region"], v["frontend_name"]]))
' "$ONLY")"

[ -z "$rows" ] && { echo "対象 env なし" >&2; exit 1; }

fail=0
while IFS=$'\t' read -r key project region fname; do
  echo "### smoke: $key ($fname)"
  gcloud run services proxy "$fname" --project "$project" --region "$region" --port "$PORT" \
    >"/tmp/smoke-$key.log" 2>&1 &
  pid=$!
  for _ in $(seq 1 15); do curl -s -o /dev/null "http://localhost:$PORT/" && break; sleep 1; done
  ui="$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:$PORT/" || echo 000)"
  api="$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:$PORT/api/expenses" || echo 000)"
  kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true
  echo "  GET / -> $ui ; GET /api/expenses -> $api"
  [ "$ui" = "200" ] && [ "$api" = "200" ] || { echo "  !! NG（/tmp/smoke-$key.log 参照）"; fail=1; }
done <<< "$rows"

exit "$fail"
