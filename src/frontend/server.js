// FlowPay frontend: UIを配信し、private な backend(Cloud Run) を
// サービス間認証(ID token)で呼び出すプロキシ。
import express from 'express';
import helmet from 'helmet';
import compression from 'compression';
import morgan from 'morgan';
import rateLimit from 'express-rate-limit';
import axios from 'axios';
import dayjs from 'dayjs';
import { z } from 'zod';
import { GoogleAuth } from 'google-auth-library';
// 金額整形は外部ライブラリ expense-format に委譲する。
// CommonJS のためデフォルトインポートで受ける。
import expenseFormat from 'expense-format';
const { formatYen } = expenseFormat;

const app = express();
app.disable('x-powered-by');
// Cloud Run のフロントプロキシ1段を信頼する。これがないと express-rate-limit が
// X-Forwarded-For 検出時に検証エラーをログ出力し、レート制限のキーも接続元プロキシ単位になる。
app.set('trust proxy', 1);
app.use(helmet({ contentSecurityPolicy: false }));
app.use(compression());
app.use(morgan('combined'));
app.use(express.json());
app.use('/api', rateLimit({ windowMs: 60_000, max: 120, standardHeaders: true, legacyHeaders: false }));
app.use(express.static('public'));

const BACKEND = process.env.BACKEND_URL || 'http://localhost:8081';
// backend が応答しない場合にリクエスト・ソケットを滞留させないためのタイムアウト（ミリ秒）。
const BACKEND_TIMEOUT_MS = 5000;
const auth = new GoogleAuth();

// private Cloud Run backend を呼ぶ。https(本番)は ID トークン付きクライアント、
// http(ローカル)は認証なしの axios にフォールバックする。
async function callBackend(path, { method = 'GET', body } = {}) {
  if (BACKEND.startsWith('https://')) {
    const client = await auth.getIdTokenClient(BACKEND);
    const res = await client.request({ url: `${BACKEND}${path}`, method, data: body, timeout: BACKEND_TIMEOUT_MS });
    return res.data;
  }
  const res = await axios({ url: `${BACKEND}${path}`, method, data: body, timeout: BACKEND_TIMEOUT_MS });
  return res.data;
}

// 登録リクエストの入力スキーマ（backend 側の validator と対応）。
const createSchema = z.object({
  amount: z.number().int().positive().max(100_000_000),
  category: z.enum(['交通費', '会議費', '消耗品', '出張費', '接待費', 'その他']).optional(),
  memo: z.string().max(200).optional(),
});

app.get('/api/expenses', async (req, res) => {
  try {
    const q = new URLSearchParams();
    for (const k of ['category', 'from', 'to']) if (req.query[k]) q.set(k, String(req.query[k]));
    const qs = q.toString();
    const items = await callBackend(`/expenses${qs ? `?${qs}` : ''}`);
    // 各明細に整形済み金額と表示用日付を付ける（expense-format / dayjs をサーバ側で実行）。
    const enriched = (items || []).map((e) => ({
      ...e,
      amountText: formatYen(e.amount),
      dateText: e.createdAt ? dayjs(e.createdAt).format('YYYY/MM/DD') : '',
    }));
    res.json(enriched);
  } catch (e) {
    res.status(502).json({ error: String(e) });
  }
});

app.get('/api/summary', async (_req, res) => {
  try {
    const s = await callBackend('/summary');
    res.json({
      ...s,
      totalText: formatYen(s.total || 0),
      monthTotalText: formatYen(s.monthTotal || 0),
      byCategory: (s.byCategory || []).map((c) => ({ ...c, totalText: formatYen(c.total) })),
    });
  } catch (e) {
    res.status(502).json({ error: String(e) });
  }
});

app.post('/api/expenses', async (req, res) => {
  const parsed = createSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(422).json({ error: '入力が不正です', details: parsed.error.flatten() });
  }
  try {
    const data = await callBackend('/expenses', { method: 'POST', body: parsed.data });
    res.status(201).json(data);
  } catch (e) {
    res.status(502).json({ error: String(e) });
  }
});

app.get('/healthz', (_req, res) => res.type('text').send('ok'));

const port = process.env.PORT || 8080;
app.listen(port, () => console.log(`frontend listening on :${port}`));
