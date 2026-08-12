#!/usr/bin/env bash
# クリーンアップ。方式によって推奨手順が違う。
#   - 共有プロジェクト方式: terraform destroy で全 env のリソースを削除。
#   - 別プロジェクト方式  : プロジェクトごと削除が最も確実・完全（terraform destroy より速い）。
#
# 使い方: scripts/teardown.sh
set -euo pipefail
cd "$(dirname "$0")/.."   # src/infra

echo "対象 env:"; terraform output -json environments 2>/dev/null | python3 -c '
import json,sys
for k,v in json.load(sys.stdin).items(): print(f"  - {k}: {v[\"project_id\"]}")' || echo "  (output なし)"

cat <<'EOS'

[別プロジェクト方式] プロジェクトごと削除が確実:
    for p in $(terraform output -json environments | python3 -c 'import json,sys;print("\n".join(v["project_id"] for v in json.load(sys.stdin).values()))' | sort -u); do
      gcloud projects delete "$p" --quiet
    done

[共有プロジェクト方式] terraform destroy:
EOS

read -r -p "この state に対して terraform destroy を実行しますか? [y/N] " yn
if [ "$yn" = "y" ] || [ "$yn" = "Y" ]; then
  terraform destroy
else
  echo "中止しました。"
fi
