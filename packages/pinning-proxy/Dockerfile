FROM node:18-alpine AS base

FROM base AS builder
RUN apk update
RUN apk add --no-cache libc6-compat
RUN yarn global add turbo
WORKDIR /app
COPY . .
RUN turbo prune --scope=@carrot-kpi/pinning-proxy --docker

FROM base AS installer
RUN apk update
RUN apk add --no-cache libc6-compat
WORKDIR /app

COPY .gitignore .gitignore
COPY --from=builder /app/out/json/ .
COPY --from=builder /app/out/yarn.lock ./yarn.lock
RUN yarn install --frozen-lockfile

COPY --from=builder /app/out/full/ .
COPY turbo.json turbo.json

ARG HOST
ENV HOST=$HOST

ARG PORT
ENV PORT=$PORT

ARG JWT_SECRET_KEY
ENV JWT_SECRET_KEY=$JWT_SECRET_KEY

ARG DB_CONNECTION_STRING
ENV DB_CONNECTION_STRING=$DB_CONNECTION_STRING

ARG IPFS_CLUSTER_BASE_URL
ENV IPFS_CLUSTER_BASE_URL=$IPFS_CLUSTER_BASE_URL

ARG IPFS_CLUSTER_AUTH_PASSWORD
ENV IPFS_CLUSTER_AUTH_PASSWORD=$IPFS_CLUSTER_AUTH_PASSWORD

RUN NODE_ENV=production yarn turbo run build --filter=@carrot-kpi/pinning-proxy

FROM base AS runner
WORKDIR /app

RUN addgroup --system --gid 1001 runners
RUN adduser --system --uid 1001 runner
USER runner
COPY --from=installer /app .

CMD node packages/pinning-proxy/build/index.js
