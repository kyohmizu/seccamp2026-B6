#!/usr/bin/env bash
# 攻撃デモ本編（実アプリと同じ「更新」経路）:
#   ロックファイルで 1.0.0 に固定 → 攻撃者が悪性1.0.1を公開 → 依存を更新(npm update)すると
#   ロックファイルが 1.0.1 に書き換わり、悪性のバージョンを取り込む。
# 事前に local/up.sh を実行しておくこと。PAUSE=1 で一手ずつ止まる。
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
REG="http://localhost:4873"
TMP="$(node -e 'console.log(require("os").tmpdir())')/flowpay-demo-PWNED-install.json"

STEP() { echo; echo "════════════════════════════════════════════════════════"; echo "▶ $*"; echo "════════════════════════════════════════════════════════"; [ -n "${PAUSE:-}" ] && read -rp "  [Enter で実行] " _ || true; }
ver() { node -p "require('./node_modules/expense-format/package.json').version" 2>/dev/null || echo '(未インストール)'; }

rm -f "$TMP" 2>/dev/null || true
WORK="$(mktemp -d)"; cp "$DIR/victim/package.json" "$DIR/victim/app.js" "$WORK/"; cd "$WORK"
# 再実行でも「攻撃前」が確実に正常な状態になるよう、レジストリとキャッシュを毎回リセットする。
CACHE="$WORK/.npmcache"
RC="$(mktemp)"; echo "//localhost:4873/:_authToken=demo-token" > "$RC"
npm unpublish expense-format --force --registry "$REG" --userconfig "$RC" >/dev/null 2>&1 || true
rm -f "$RC"

STEP "1) 攻撃前: expense-format@1.0.0（正規のバージョン）が公開されている"
bash "$DIR/publish.sh" good

STEP "2) 被害者アプリが依存を取得し、ロックファイルで 1.0.0 に固定する（実アプリと同じ状態）"
npm install --registry "$REG" --cache "$CACHE" --prefer-online --no-audit --no-fund 2>&1 | tail -4
echo "→ ロックファイルに固定されたバージョン: expense-format@$(ver)"

STEP "3) アプリ実行（正常。攻撃者はまだ何も受信していない）"
node app.js

STEP "4) 攻撃者が悪性のバージョン expense-format@1.0.1 を公開（メンテナ乗っ取り・アカウント侵害の想定）"
bash "$DIR/publish.sh" evil

STEP "5) 依存を更新する（Dependabot 相当を手動で再現）。npm update でロックファイルが 1.0.0→1.0.1 に書き換わる"
# 実アプリはロックファイルをコミット済み。攻撃は「更新」で入る:
#   ^1.0.0 の範囲内で最新(=公開直後の1.0.1)へ上がり、その postinstall が実行される。
# 公開直後の版を確実に取りに行くため、パッケージメタデータのキャッシュを更新する。
rm -rf "$CACHE"
# デモ用のダミー秘密（CI環境に置かれがちな種類を模す）。postinstall がキー名を収集する様子を見せる。
GITHUB_TOKEN="ghp_DEMO_do_not_use" GCP_SA_KEY="demo-service-account-key" NPM_TOKEN="npm_DEMOtoken" \
  npm update expense-format --registry "$REG" --cache "$CACHE" --prefer-online --no-audit --no-fund 2>&1 | tail -12
echo "→ 更新後にインストールされたバージョン: expense-format@$(ver)"

STEP "6) アプリ実行（実行時にも持ち出し）。インストール時マーカーと攻撃者ログを確認"
node app.js
echo
echo "--- インストール時マーカー（postinstall が生成）---"
cat "$TMP" 2>/dev/null || echo "(なし)"
echo
echo "--- 攻撃者サーバーの受信ログ ---"
cat "$DIR/.work-mock.log" 2>/dev/null || echo "(なし)"

echo
echo "まとめ: ロックファイルで固定していても、更新(npm update)で公開直後の悪性のバージョンを検査せず取り込む。"
echo "対策の実演は local/defenses.sh"
cd /; rm -rf "$WORK"
