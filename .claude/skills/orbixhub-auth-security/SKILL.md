---
name: orbixhub-auth-security
description: Use when working on OrbixHub identity/auth code (back/src/modules/auth/**, back/src/common/auth/**, back/src/common/crypto/**) — login, register, refresh rotation, password reset, JWT, argon2, anti-enumeration, lockout, one-time tokens. Encodes the security invariants that must not be broken.
---

# OrbixHub — Segurança de Auth & Identidade

## Tokens

- **Access token**: JWT **HS256** assinado com `JWT_ACCESS_SECRET` (≥ 32 bytes).
  `AccessTokenService.verify` usa **allowlist** `['HS256']` → rejeita `alg:none` e confusão de
  chave assimétrica. TTL padrão 15m.
- **Claims** (`AccessTokenClaims`): `sub` (userId), `tid` (tenantId), `role`, `jti`.
- **Refresh token**: opaco, persistido como **hash** em `refresh_token`. Rotação por família:
  - cada refresh gera novo token e marca o anterior como `rotated_to`;
  - **reuso de token já rotacionado** (fora da tolerância) **revoga a família inteira** (anti-replay).
    Lógica em `RefreshService`.

## Senhas (`PasswordService`)

- Hash com **argon2id**; parâmetros do env (`ARGON_MEMORY_KIB`, `ARGON_TIME_COST`, `ARGON_PARALLELISM`).
- `dummyVerify(password)` faz verify real contra hash dummy cacheado, igualando o custo do caminho
  "e-mail não existe" (anti-timing).

## Anti-enumeração (OBRIGATÓRIO)

- `login`: e-mail inexistente, senha errada ou conta travada → **sempre** o mesmo
  `UnauthorizedException('Credenciais inválidas.')`. Nunca revele qual fator falhou.
- `forgot-password`: **sempre** `{ ok: true }` (200), exista ou não o e-mail.
- Rate limit estrito: `register`/`login`/`forgot-password` usam `AuthThrottlerGuard` com
  `@Throttle({ auth: { ttl: 60_000, limit: 5 } })` (5/min por IP+conta).

## Lockout

- Após `LOCK_THRESHOLD` (5) falhas → conta travada por `LOCK_MINUTES` (20). Conta travada
  retorna o mesmo erro genérico.

## Tokens de uso único (`one_time_token`)

- `email_verify` e `password_reset`: gera token opaco (`generateOpaqueToken`), persiste o **hash**
  (`hashToken`), TTL `OTT_TTL_MIN` (30 min). Consome com `consumeOneTimeToken`.
- `reset-password` consome o token, atualiza a senha e **revoga todas as sessões** (`revokeAllForUser`).

## Ordem de operações no `register`

1. Valida slug, normaliza e-mail, checa duplicidade.
2. `hash` da senha.
3. Tx atômica: cria `tenant` + `users` (owner) + `membership` + trial (`billing.createTrial`).
4. **Após commit**: cria one-time token e envia e-mail (falha de e-mail **não** faz rollback).
5. Emite access + refresh.

> Trate `P2002` (unique violation) de slug/e-mail como `ConflictException` genérico.
> Operações sensíveis de IAM exigem reauth (senha atual).
