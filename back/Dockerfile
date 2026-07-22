# OrbixHub backend (NestJS) — imagem de produção.
# Build context = RAIZ do monorepo (por causa dos npm workspaces).
# Estágio 1 compila (precisa de dev deps + toolchain nativo p/ argon2);
# estágio 2 é a imagem final, só com runtime + deps de produção.

# ---------- build ----------
FROM node:20-bookworm-slim AS build
WORKDIR /app

# Toolchain nativo p/ compilar argon2 (bindings C) + openssl para o Prisma
# detectar a versão certa (openssl-3.0.x) ao gerar o client/engines.
RUN apt-get update \
  && apt-get install -y --no-install-recommends python3 make g++ openssl \
  && rm -rf /var/lib/apt/lists/*

# Instala deps a partir do manifesto do workspace (cache-friendly).
COPY package.json package-lock.json ./
COPY back/package.json ./back/package.json
RUN npm ci

# Código + schema, então gera client Prisma e compila o Nest.
COPY back ./back
RUN npm run prisma:generate --workspace back \
  && npm run build --workspace back

# Enxuga para deps de produção (mantém @prisma/client e o CLI prisma,
# que agora é dependency — necessário p/ `migrate deploy` no release).
RUN npm prune --omit=dev

# ---------- runtime ----------
FROM node:20-bookworm-slim AS runtime
WORKDIR /app/back
ENV NODE_ENV=production

# Prisma precisa do OpenSSL em runtime (o motor de migração/engine falha sem
# libssl na imagem slim). ca-certificates p/ chamadas HTTPS de saída.
RUN apt-get update \
  && apt-get install -y --no-install-recommends openssl ca-certificates \
  && rm -rf /var/lib/apt/lists/*

# node_modules ficam hasteados na raiz do workspace (/app/node_modules);
# o Node resolve subindo a árvore a partir de /app/back.
COPY --from=build /app/node_modules /app/node_modules
COPY --from=build /app/package.json /app/package.json
COPY --from=build /app/back/dist ./dist
COPY --from=build /app/back/prisma ./prisma
COPY --from=build /app/back/package.json ./package.json

# Cap de heap coerente com a t3.micro (1 GB, dividida com PG/Redis).
# A porta real vem do --env-file no run (PORT=4500 em prod).
CMD ["node", "--max-old-space-size=384", "dist/src/main.js"]
