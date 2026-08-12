'use strict';
// min-release-age（cooldown）ゲートの最小実装。
// レジストリのメタデータから range を満たす最新版の公開日時を取得し、
// しきい値(日)より新しければ非0で終了する（＝出たばかりのバージョンを自動採用しない）。
//
// 使い方: node cooldown-check.js <name> <range> <minDays> <registryURL>
//   例:   node cooldown-check.js expense-format ^1.0.0 14 http://localhost:4873
const http = require('http');

const [, , name = 'expense-format', range = '^1.0.0', daysStr = '14', reg = 'http://localhost:4873'] = process.argv;
const minDays = Number(daysStr);

function get(url) {
  return new Promise((resolve, reject) => {
    http
      .get(url, (res) => {
        let b = '';
        res.on('data', (c) => (b += c));
        res.on('end', () => {
          try {
            resolve(JSON.parse(b));
          } catch (e) {
            reject(e);
          }
        });
      })
      .on('error', reject);
  });
}

function cmp(x, y) {
  const xs = x.split('.').map(Number);
  const ys = y.split('.').map(Number);
  for (let i = 0; i < 3; i++) {
    if ((xs[i] || 0) !== (ys[i] || 0)) return (xs[i] || 0) - (ys[i] || 0);
  }
  return 0;
}
// ^base（デモ用の簡易 caret 判定: メジャー一致かつ base 以上）
function satisfiesCaret(v, base) {
  const major = Number(v.split('.')[0]);
  const bmajor = Number(base.split('.')[0]);
  return major === bmajor && cmp(v, base) >= 0;
}

(async () => {
  const base = range.replace(/^[\^~]/, '');
  const meta = await get(`${reg}/${encodeURIComponent(name)}`);
  const candidates = Object.keys(meta.versions || {})
    .filter((v) => satisfiesCaret(v, base))
    .sort(cmp);
  const latest = candidates[candidates.length - 1];
  if (!latest) {
    console.log(`  ${name} に ${range} を満たすバージョンが見つかりません。`);
    process.exit(2);
  }
  const published = new Date(meta.time[latest]);
  const ageDays = (Date.now() - published.getTime()) / 86400000;
  console.log(`  候補: ${name}@${latest}  公開: ${published.toISOString()}  経過: ${ageDays.toFixed(2)}日  しきい値: ${minDays}日`);
  if (ageDays < minDays) {
    console.log(`  \x1b[31mBLOCK\x1b[0m: ${latest} は公開から ${ageDays.toFixed(2)} 日（< ${minDays}日）。cooldown により不採用。`);
    process.exit(1);
  }
  console.log(`  \x1b[32mOK\x1b[0m: ${latest} は十分に枯れている（採用可）。`);
})().catch((e) => {
  console.error('  cooldown-check エラー:', e.message);
  process.exit(2);
});
