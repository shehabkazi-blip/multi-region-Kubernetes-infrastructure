# ---- Build stage ----
FROM node:18-alpine AS builder
WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm install --omit=dev

# ---- Runtime stage ----
FROM node:18-alpine
WORKDIR /app

# Run as non-root for security
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

COPY --chown=appuser:appgroup --from=builder /app/node_modules ./node_modules
COPY --chown=appuser:appgroup package.json ./
COPY --chown=appuser:appgroup server.js ./

ENV PORT=8080
ENV NODE_ENV=production

USER appuser
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO - http://localhost:8080/healthz || exit 1

CMD ["node", "server.js"]
