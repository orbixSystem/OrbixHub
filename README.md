# OrbixHub

SaaS de gestão multi-tenant (oficinas mecânicas), monorepo: `back/` (NestJS) + `front/` (Flutter).

## Setup (dev)
1. Start Postgres 16 + Redis 7. Two options:
   - **Podman (local, this machine):** containers `orbix-postgres` (host port 55432) and `orbix-redis` (6379) are already running.
   - **docker compose** (portability/CI): `docker compose up -d` (Postgres on 5432 + Redis on 6379).
2. `cd back && cp .env.example .env` (local `.env` points at port 55432 for podman)
3. `npm install` (run at repo root; npm workspaces)
4. `npm run prisma:migrate --workspace back` (apply baseline)
5. `npm run back:dev` → API on http://localhost:3000/api

> Package manager is **npm workspaces**. Local DB runs under **Podman on host port 55432**; CI/docker-compose use 5432.

See `docs/superpowers/specs/2026-06-01-orbixhub-auth-multitenant-design.md`.
