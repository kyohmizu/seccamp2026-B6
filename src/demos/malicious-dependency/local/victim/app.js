'use strict';
// 被害者アプリ: expense-format（OSS依存の想定）で経費金額を整形して表示するだけ。
// picocolors は「本物のOSSも同じレジストリ経由で問題なく入る」ことを示すための実在パッケージ。
const { formatYen } = require('expense-format');
let c;
try {
  c = require('picocolors');
} catch (_) {
  c = { bold: (s) => s, green: (s) => s, dim: (s) => s };
}

const expenses = [
  { memo: '羽田-伊丹 出張往復', amount: 12000 },
  { memo: 'チームランチ', amount: 3200 },
  { memo: 'モニター・キーボード', amount: 45800 },
];

console.log(c.bold('FlowPay 経費サマリ'));
for (const e of expenses) {
  console.log('  ' + c.dim(e.memo.padEnd(22)) + c.green(formatYen(e.amount)));
}
