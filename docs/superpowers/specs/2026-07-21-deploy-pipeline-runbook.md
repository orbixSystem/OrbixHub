# OrbixHub — Deploy automático (pipeline + runbook)

> **Para leigos e agentes.** Explica como o deploy automático funciona, o que fazer
> **uma vez** para ligar, e como fazer **na mão** se o automático falhar.
> Escrito em 2026-07-21, depois do incidente de disco cheio (ver §6).

---

## 1. Visão geral (o que acontece quando você dá `git push` na master)

```
push na master
   │
   ▼  GitHub Actions (.github/workflows/deploy.yml) — builda na máquina do GitHub
   ├─ test:          lint + testes unitários do backend  (portão)
   ├─ build-backend: monta a imagem Docker (back/Dockerfile) e publica no GHCR
   ├─ build-front:   flutter build web  (artefato)
   └─ deploy:        entra na EC2 via Tailscale e roda scripts/deploy/remote-deploy.sh
                        ├─ pg_dump (backup)         → /home/ubuntu/backups
                        ├─ prisma migrate deploy    (como app_migrator)
                        ├─ troca o container do backend
                        ├─ copia o Flutter web      → /var/www/orbixhub
                        ├─ healthcheck              → rollback se falhar
                        └─ podman image prune       (mantém o disco de 8 GB sob controle)
```

**Por que buildar no GitHub e não na EC2:** a t3.micro tem 1 GB de RAM; `nest build`
e `flutter build` estouram a memória (OOM) — foi parte do que derrubou a produção.
A EC2 só **recebe o pronto**.

---

## 2. Arquitetura em produção (o que roda na EC2)

- **Postgres 16 + Redis 7**: containers **podman** (`127.0.0.1:5432` / `:6379`).
- **Backend (NestJS)**: agora um **container podman** `orbixhub-api`, rodando com
  `--network host` (fala com PG/Redis em localhost), `--env-file back/.env` e
  **volume `back/.storage`** (fotos das OS — `STORAGE_PROVIDER=local`).
  Escuta na **porta 4500**. (Antes rodava via PM2 — o script desliga o PM2 na 1ª vez.)
- **nginx**: serve o Flutter web de `/var/www/orbixhub` e faz proxy `/api` → `:4500`.
- **Domínio**: `hub.orbixsystem.com` (TLS Let's Encrypt no nginx).

---

## 3. Ligar o pipeline — configuração ÚNICA

### 3.1 Tailscale (rede privada CI ↔ EC2)
1. Crie conta grátis em https://tailscale.com (login com Google/GitHub).
2. **Na EC2**, instale e conecte:
   ```bash
   curl -fsSL https://tailscale.com/install.sh | sh
   sudo tailscale up
   # anote o IP tailscale da máquina (100.x.y.z):
   tailscale ip -4
   ```
3. Gere uma **Auth key** (Settings → Keys → Generate auth key; marque *Ephemeral* e
   *Reusable*). Guarde — vira o secret `TS_AUTHKEY`.

### 3.2 Chave SSH de deploy (o CI entra na EC2 com ela)
Gere um par **só para deploy** (não reutilize sua chave pessoal):
```bash
ssh-keygen -t ed25519 -f deploy_key -N ""     # gera deploy_key (privada) e deploy_key.pub
```
- Adicione a **pública** na EC2: cole `deploy_key.pub` em `~/.ssh/authorized_keys` do usuário `ubuntu`.
- A **privada** (`deploy_key`) vira o secret `DEPLOY_SSH_KEY`.

### 3.3 Container sobrevive a reboot (podman rootless)
Na EC2, uma vez:
```bash
loginctl enable-linger ubuntu
```

### 3.4 Secrets no GitHub (repo → Settings → Secrets and variables → Actions)
| Secret | Valor |
|---|---|
| `TS_AUTHKEY` | auth key do Tailscale (§3.1) |
| `DEPLOY_SSH_KEY` | conteúdo da chave **privada** `deploy_key` (§3.2) |
| `DEPLOY_HOST` | IP tailscale da EC2 (`100.x.y.z`) ou o nome MagicDNS |
| `DEPLOY_USER` | `ubuntu` |

> GHCR não precisa de secret extra: o próprio `GITHUB_TOKEN` do workflow faz o login
> na EC2 para puxar a imagem.

### 3.5 Primeiro deploy
- Garanta que o workflow está **na master** (o gatilho é push na master).
- Dispare: faça um push OU rode **Actions → Deploy prod → Run workflow** (manual).

---

## 4. Fazer na mão (se o automático falhar)

Você buildou a imagem localmente/CI e quer subir manualmente na EC2:
```bash
# 1) entrar na máquina
ssh -i ~/.ssh/meu-saas.pem ubuntu@<ip>       # ou pela tailnet: ssh ubuntu@100.x.y.z

# 2) puxar a imagem (troque a tag pelo commit desejado)
podman login ghcr.io                          # user = seu GitHub, senha = PAT com read:packages
podman pull ghcr.io/orbixsystem/orbixhub/backend:latest

# 3) rodar o mesmo script que o CI usa
/tmp/remote-deploy.sh ghcr.io/orbixsystem/orbixhub/backend:latest
```
O `remote-deploy.sh` já faz backup, migration, troca de container, healthcheck e
rollback. Se quiser só reiniciar o que já está lá:
```bash
podman restart orbixhub-api
podman logs --tail 50 orbixhub-api
curl -s http://localhost:4500/api/health
```

### Rollback manual para um backup de banco
```bash
ls -1t /home/ubuntu/backups/            # escolha o db-AAAAMMDD-HHMMSS.sql.gz
gunzip -c /home/ubuntu/backups/db-XXXX.sql.gz | \
  podman exec -i postgres psql -U app_owner orbixhub
```

---

## 5. Diagnóstico rápido (quando algo estiver errado)

```bash
curl -s https://hub.orbixsystem.com/api/health   # {"status":"ok"} é o esperado
df -h /                                           # DISCO — se ~100%, é o vilão nº 1 (ver §6)
free -h                                           # RAM/swap
podman ps                                         # postgres, redis, orbixhub-api de pé?
podman logs --tail 80 orbixhub-api                # erros da API
podman logs --tail 40 postgres                    # erros do banco
```

---

## 6. Regras de ouro desta máquina (aprendidas no incidente de 2026-07-21)

- **Disco de 8 GB é o recurso escasso** (decisão: NÃO aumentar — fase de teste).
  Se encher, o Postgres entra em crash-loop e a produção cai. O deploy já limpa
  imagens antigas; os logs têm rotação + guarda de 1 GB (`/etc/logrotate.d/orbix`
  e `/etc/cron.daily/orbix-log-guard`).
- **Nunca buildar na EC2.** Sempre no CI.
- **`.storage` tem fotos reais** — só existe como volume montado; nunca apague.
- **Migrations são aditivas** e rodam como `app_migrator` (`MIGRATION_DATABASE_URL`).
- Limites de memória para 1 GB: Node `--max-old-space-size=384` (no Dockerfile),
  Redis `maxmemory 96mb`, Postgres `shared_buffers=128MB`/`work_mem=4MB`/`max_connections=20`.
- **Pendência conhecida:** `apt` está em estado quebrado (resquício de um
  `do-release-upgrade`); rode `sudo apt --fix-broken install` quando for mexer em pacotes.
