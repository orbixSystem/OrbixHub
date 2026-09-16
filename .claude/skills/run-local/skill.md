---
name: run-local
description: >
  Use this skill when the user asks to start, boot, or run the full OrbixHub local
  environment (backend + frontend web). Trigger phrases: "roda local", "sobe tudo",
  "run-local", "sobe o projeto", "roda o projeto", "inicia tudo", "abre o front e back",
  "sobe o ambiente completo", "roda pra mim". Starts Podman + containers + applies DB
  schema + NestJS on port 4400 + Flutter web on port 8090.
version: 1.0.0
---

# OrbixHub — Subir Ambiente Local Completo (Backend + Frontend Web)

## O que esta skill faz

Sobe automaticamente o Podman, containers (postgres + redis), aplica o schema
canônico do banco, inicia o NestJS na porta 4400 e o Flutter web na porta 8090.

## Referências rápidas

- **Backend porta:** `4400` (nunca 3000 — VS Code faz port-forward de 3000 para SysOne)
- **Frontend porta:** `8090`
- **Flutter SDK:** `C:/Users/BennerDias/flutter/bin/flutter.bat`
- **Conta de teste:** `dono@teste.com` / `senha12345`
- **Projeto root:** `C:\Users\BennerDias\Documents\benner-sys\Orbix\OrbixHub`

## Passos — execute nesta ordem

### 1. Podman Machine + Containers

```bash
podman machine start 2>/dev/null || true
podman start orbix-postgres orbix-redis
```

Idempotente — se já estiver rodando, segue.

### 2. Schema do banco (idempotente)

```bash
cd "$PROJECT_ROOT/back" && npm run db:setup
```

Aplica `sql/auth-multitenant-schema.sql` como `app_owner`. Idempotente —
seguro rodar sempre. Garante que colunas novas (ex: `tenant.vertical`) existam.

### 3. Prisma generate

```bash
cd "$PROJECT_ROOT/back" && npx prisma generate
```

Regenera o client Prisma para que os tipos TS reflitam o schema atual.
Evita os erros de "Property X does not exist".

### 4. Backend NestJS na porta 4400

Matar qualquer processo na 4400 antes:

```bash
# Checar e matar se necessário
PID=$(netstat -ano | grep ":4400 .*LISTENING" | awk '{print $5}' | head -1)
[ -n "$PID" ] && taskkill //PID $PID //F 2>/dev/null
```

Iniciar em background:

```bash
cd "$PROJECT_ROOT/back" && PORT=4400 npm run start:dev
```

Usar `run_in_background: true`. Monitorar o output até aparecer:
`Nest application successfully started`

Timeout: ~40 segundos. Se aparecer erros de compilação (Found X errors),
investigar antes de seguir.

### 5. Frontend Flutter Web na porta 8090

Matar qualquer processo na 8090 antes:

```bash
PID=$(netstat -ano | grep ":8090 .*LISTENING" | awk '{print $5}' | head -1)
[ -n "$PID" ] && taskkill //PID $PID //F 2>/dev/null
```

Checar se arquivos gerados existem. Se não, rodar build_runner:

```bash
# Se não existir algum .freezed.dart, rodar build_runner
cd "$PROJECT_ROOT/front"
if [ ! -f lib/features/auth/domain/auth_models.freezed.dart ]; then
  C:/Users/BennerDias/flutter/bin/dart.bat run build_runner build --delete-conflicting-outputs
fi
```

Iniciar em background:

```bash
cd "$PROJECT_ROOT/front" && C:/Users/BennerDias/flutter/bin/flutter.bat run -d chrome \
  --web-port 8090 \
  --dart-define=API_BASE_URL=http://localhost:4400/api \
  --web-browser-flag=--disable-extensions
```

Usar `run_in_background: true`. Monitorar até aparecer:
`This app is linked to the debug service`

Timeout: ~90 segundos (compilação do Dart + boot do Chrome).

**IMPORTANTE:** O Flutter abre uma janela do Chrome própria com debug habilitado.
Se o usuário fechar essa janela, precisa relançar o Flutter (não adianta abrir
localhost:8090 num Chrome normal — fica tela branca).

### 6. Verificação final

Reportar ao usuário:

```
Backend:  http://localhost:4400/api  (Nest rodando)
Frontend: http://localhost:8090      (Chrome aberto pelo Flutter)
```

## Troubleshooting

| Sintoma | Causa | Solução |
|---|---|---|
| `Port already in use` | Processo anterior pendurado | Matar PID via netstat |
| Tela branca no Chrome | Janela debug fechada | Relançar Flutter (passo 5) |
| `/me` retorna 500 | Schema desatualizado | `npm run db:setup` (passo 2) |
| TS errors no backend | Prisma client stale | `npx prisma generate` (passo 3) |
| `flutter run` falha | Faltam .freezed.dart | `build_runner build` (passo 5) |
| Podman não conecta | Machine parada | `podman machine start` |
| CORS error no front | Porta não listada | Adicionar porta ao `CORS_ORIGINS` no `.env` |
| Front não conecta ao back | Porta 3000 sequestrada pelo VS Code | Usar porta 4400 (já configurado) |
