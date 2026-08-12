# digest 固定版（解決日時点の実値。digest は変わるので、固定時に自分で解決して貼る）
# 依存は CI ステップ（cloudbuild の frontend-deps）で install 済み。イメージは node_modules を詰めるだけ。
FROM node:22-slim@sha256:d649c27dae7ba0137b3cef5dd75baa422c08dc3d9e3fc0c23dfb172dc3cc6436
WORKDIR /app
ENV NODE_ENV=production
COPY package.json ./
COPY node_modules ./node_modules
COPY server.js ./
COPY public ./public
USER node
CMD ["node", "server.js"]
