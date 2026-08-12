'use strict';
// expense-format@1.0.0（正規のバージョン）: 経費金額を日本円表記にするだけのユーティリティ。
function formatYen(n) {
  return new Intl.NumberFormat('ja-JP', {
    style: 'currency',
    currency: 'JPY',
    maximumFractionDigits: 0,
  }).format(Number(n) || 0);
}
module.exports = { formatYen };
