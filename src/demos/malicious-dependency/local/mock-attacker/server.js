'use strict';
// デモ用の「攻撃者の受信サーバ」。localhost で待ち受け、届いたビーコンを表示するだけ。
// 実際には何も外部へ転送しない。
const http = require('http');

const PORT = Number(process.env.PORT || 9099);
let n = 0;

const server = http.createServer((req, res) => {
  if (req.method === 'POST' && req.url === '/steal') {
    let body = '';
    req.on('data', (chunk) => (body += chunk));
    req.on('end', () => {
      n += 1;
      let data;
      try {
        data = JSON.parse(body);
      } catch (_) {
        data = body;
      }
      const ts = new Date().toISOString();
      console.log(`\x1b[31m[攻撃者受信 #${n}] ${ts}\x1b[0m`);
      console.log('  ' + JSON.stringify(data));
      res.writeHead(204);
      res.end();
    });
  } else {
    res.writeHead(404);
    res.end();
  }
});

server.listen(PORT, '127.0.0.1', () => {
  console.log(`mock attacker listening on http://127.0.0.1:${PORT} (POST /steal)`);
});
