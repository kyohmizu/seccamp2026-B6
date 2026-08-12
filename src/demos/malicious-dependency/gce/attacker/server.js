'use strict';
// デモ用「攻撃者の受信サーバ（C2）」。侵害パッケージからのビーコンを受けて記録・表示する。
// ※ 受け取るのは良性シミュレーション（使えるトークンそのものは送られない設計）。
const http = require('http');

const PORT = Number(process.env.PORT || 9099);
const HOST = process.env.HOST || '0.0.0.0';
const MAX = 500;
const received = [];

function clientIp(req) {
  return (req.headers['x-forwarded-for'] || req.socket.remoteAddress || '').toString();
}

const server = http.createServer((req, res) => {
  if (req.method === 'POST' && req.url === '/steal') {
    let body = '';
    req.on('data', (c) => {
      body += c;
      if (body.length > 1e6) req.destroy();
    });
    req.on('end', () => {
      let data;
      try {
        data = JSON.parse(body);
      } catch {
        data = body;
      }
      const rec = { n: received.length + 1, at: new Date().toISOString(), from: clientIp(req), data };
      received.push(rec);
      if (received.length > MAX) received.shift();
      console.log(`[C2 受信 #${rec.n}] ${rec.at} from ${rec.from}`);
      console.log('  ' + JSON.stringify(data));
      res.writeHead(204);
      res.end();
    });
    return;
  }
  if (req.method === 'GET' && (req.url === '/' || req.url.startsWith('/log'))) {
    res.writeHead(200, { 'content-type': 'application/json; charset=utf-8' });
    res.end(JSON.stringify({ count: received.length, received }, null, 2));
    return;
  }
  res.writeHead(404);
  res.end();
});

server.listen(PORT, HOST, () => {
  console.log(`C2 receiver listening on ${HOST}:${PORT} (POST /steal, GET /log)`);
});
