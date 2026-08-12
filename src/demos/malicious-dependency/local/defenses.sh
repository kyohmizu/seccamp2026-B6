#!/usr/bin/env bash
# 対策の実演: (1) lockfile + npm ci  (2) ignore-scripts  (3) cooldown / min-release-age
# 前提: local/up.sh 実行済み、かつ good/evil 両方が publish 済み（demo.sh を一度流すと満たす）。
# 未 publish の場合はこのスクリプトが両方 publish する。PAUSE=1 で一手ずつ止まる。
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
REG="http://localhost:4873"
TMP="$(node -e 'console.log(require("os").tmpdir())')/flowpay-demo-PWNED-install.json"

STEP() { echo; echo "════════════════════════════════════════════════════════"; echo "▶ $*"; echo "════════════════════════════════════════════════════════"; [ -n "${PAUSE:-}" ] && read -rp "  [Enter で実行] " _ || true; }
ver() { node -p "require('./node_modules/expense-format/package.json').version" 2>/dev/null || echo '(未インストール)'; }
marker() { [ -f "$TMP" ] && echo '生成された(!! postinstall 実行)' || echo '無し(postinstall 実行されず)'; }
newwork() { WORK="$(mktemp -d)"; cp "$DIR/victim/package.json" "$DIR/victim/app.js" "$WORK/"; cd "$WORK"; CACHE="$WORK/.npmcache"; rm -f "$TMP"; }

# 両方のバージョンが公開済みであることを保証
bash "$DIR/publish.sh" good >/dev/null 2>&1 || true
bash "$DIR/publish.sh" evil >/dev/null 2>&1 || true
echo "前提: expense-format 1.0.0（正規のバージョン）と 1.0.1（悪性のバージョン）が Verdaccio に公開済み。"

STEP "対策1: コミット済み package-lock.json + npm ci（バージョン固定）"
newwork
# 検証済みの 1.0.0 でロックファイルを作る（本来はリポジトリにコミット済みの想定）
npm install expense-format@1.0.0 picocolors --registry "$REG" --cache "$CACHE" --prefer-online --no-audit --no-fund >/dev/null 2>&1
echo "ロックファイル生成時のバージョン: expense-format@$(ver)（1.0.0 に固定）"
rm -rf node_modules
echo "→ 悪性1.0.1が公開済みでも、npm ci はロックファイル通りに入れる:"
npm ci --registry "$REG" --cache "$CACHE" 2>&1 | tail -3
echo "  結果: expense-format@$(ver) / インストール時マーカー: $(marker)"

STEP "対策2: npm install --ignore-scripts（インストール時RCEの無効化）"
newwork
npm install --registry "$REG" --cache "$CACHE" --ignore-scripts --prefer-online --no-audit --no-fund 2>&1 | tail -3
echo "  取得したバージョン: expense-format@$(ver)（1.0.1 は入る）/ マーカー: $(marker)"
echo "  ※ ignore-scripts が止めるのはインストール時のみ。実行時の持ち出しは別レイヤ:"
node app.js >/dev/null 2>&1 || true
echo "  → アプリを実行すれば runtime ビーコンは発生する（実行時対策・権限分離が別途必要）。"

STEP "対策3: cooldown / min-release-age（出たばかりのバージョンを採用しない）"
newwork
echo "  公開直後のバージョンを弾くゲート（14日未満を拒否）:"
node "$DIR/cooldown-check.js" expense-format '^1.0.0' 14 "$REG" || true
echo "  → 悪性1.0.1は公開直後なのでブロックされ、自動更新で取り込まれない。"
echo "     検証済みの1.0.0に留める運用（対策1）と組み合わせて効く。"

echo
echo "対策の実演終了。攻撃者ログ: $DIR/.work-mock.log"
cd /; rm -rf "$WORK"
