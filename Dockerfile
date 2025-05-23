FROM node:18.20.0 AS base
# 참고 https://github.com/vercel/next.js/blob/canary/examples/with-docker/Dockerfile

# Install dependencies only when needed
FROM base AS deps
# libc6-compat not needed on Ubuntu/Debian
WORKDIR /app

# Install dependencies based on the preferred package manager
COPY package.json yarn.lock* package-lock.json* pnpm-lock.yaml* ./
RUN \
  if [ -f yarn.lock ]; then yarn --frozen-lockfile; \
  elif [ -f package-lock.json ]; then npm ci; \
  elif [ -f pnpm-lock.yaml ]; then yarn global add pnpm && pnpm i --frozen-lockfile; \
  else echo "Lockfile not found." && exit 1; \
  fi

# Rebuild the source code only when needed
FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

ENV NEXT_TELEMETRY_DISABLED 1

# RUN yarn build

RUN npm run build

# Production image, copy all the files and run next
FROM base AS runner
WORKDIR /app

ENV NODE_ENV production
ENV NEXT_TELEMETRY_DISABLED 1

# 用 apt 安装依赖
RUN apt-get update && \
  apt-get install -y --no-install-recommends bash ffmpeg python3 libva-drm2 vainfo intel-media-va-driver wget ca-certificates && \
  rm -rf /var/lib/apt/lists/*

RUN wget https://github.com/yt-dlp/yt-dlp/releases/download/2025.04.30/yt-dlp -O /usr/local/bin/yt-dlp && \
  chmod a+rx /usr/local/bin/yt-dlp

# Use environment variables in the addgroup and adduser commands
RUN groupadd --gid ${GID:-1001} nodejs && \
  useradd --uid ${UID:-1001} --gid nodejs --shell /bin/bash --create-home nextjs

COPY --from=builder /app/public ./public

COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs

EXPOSE 3000

ENV PORT 3000
ENV HOSTNAME "0.0.0.0"

CMD ["node", "server.js"]