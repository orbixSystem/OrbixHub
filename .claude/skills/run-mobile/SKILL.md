---
name: run-mobile
description: >
  Use this skill when the user asks to start, boot, or prepare the OrbixHub backend
  dev environment for mobile testing. Trigger phrases: "sobe o ambiente", "inicia o
  backend", "start docker e nest", "subir o nest", "run-mobile", "sobe o docker",
  "prepara o ambiente", "inicia o servidor". Starts Docker Desktop + containers +
  NestJS on port 4400. Does NOT launch the emulator or Flutter — user controls those
  from the IDE.
version: 1.1.0
---

# OrbixHub — Subir o Ambiente Backend (Docker + NestJS)

## O que esta skill faz

Sobe automaticamente o Docker Desktop, containers (postgres + redis) e o NestJS na
porta 4400. Emulador e Flutter são controlados pelo usuário via IDE.

## Referências

- **Backend porta:** `4400` (nunca 3000 — VS Code faz port-forward de 3000 para SysOne)
- **API_BASE_URL no emulador:** `http://10.0.2.2:4400/api`
- **Conta de teste:** `degan_joao1@hotmail.com` / `12345678910`

## Passos — execute nesta ordem

### 1. Docker Desktop

Inicia o Docker Desktop e aguarda o daemon ficar pronto:

```powershell
Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"
```

Depois aguarda o daemon (loop até `docker ps` responder OK, timeout 60s):

```powershell
$t = 0
while ($t -lt 60) {
  docker ps 2>$null && break
  Start-Sleep 5; $t += 5; Write-Host "Aguardando Docker... ${t}s"
}
```

Se o Docker Desktop já estiver rodando, `docker ps` responde imediatamente e o loop encerra.

### 2. Containers (postgres + redis)

```powershell
docker compose up -d
```

Comando idempotente — se já estiverem up, não faz nada. Confirme com `docker compose ps`.

### 3. NestJS na porta 4400

Inicia em background (`run_in_background: true`), da raiz do monorepo:

```powershell
$env:PORT = '4400'; npm run back:dev
```

Monitora o output com `tail -f` + `grep` (Bash) até aparecer:
`Nest application successfully started`

## Verificação pós-boot

```powershell
curl http://localhost:4400/api/health   # deve retornar { status: 'ok' }
```

## Encerramento

- NestJS: Ctrl+C no processo de background
- Containers: `docker compose stop` (ou deixar up para próxima sessão)

## Troubleshooting

| Sintoma | Causa | Solução |
|---|---|---|
| `Port 4400 already in use` | Processo anterior pendurado | `netstat -ano \| findstr 4400` → matar o PID |
| Container falha ao iniciar | Docker daemon ainda subindo | Aguardar mais e tentar `docker compose up -d` de novo |
| `ECONNREFUSED` no emulador | NestJS não subiu | Checar output do processo de background |
