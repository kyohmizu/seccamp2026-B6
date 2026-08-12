# 依存は CI ステップ（pipelines/cloudbuild.yaml の frontend-deps）で install 済み。
# ここでは用意された node_modules をそのままイメージに格納する（install はイメージ内で行わない）。
# ローカルで docker build する場合は、先に frontend/ で `npm install` を実行しておくこと。
FROM node:22-slim
WORKDIR /app
ENV NODE_ENV=production
COPY package.json ./
COPY node_modules ./node_modules
COPY server.js ./
COPY public ./public
USER node
CMD ["node", "server.js"]
