# Migração para conta AWS nova — arquitetura e runbook

**Data:** 2026-08-01
**Status:** desenho aprovado pelo dono do produto; execução em andamento
**Conta destino:** `276571118320` (bennerdias), região **us-east-2 (Ohio)**
**Conta origem:** `825347768279`, instância `i-0d3036e30ee96235f` (parada desde 29/07/2026)

---

## 1. Por que migrar

A conta antiga acumulou US$ 32,79 de uso em julho/2026, dos quais **US$ 21,26 foram
`CPUCredits:t3`** — cobrança de CPU excedente do modo `unlimited`, disparada por um
loop de OOM (o Node era morto por falta de RAM, o PM2 reiniciava, o swap thrashing
prendia a CPU a ~90% por 11 dias). Detalhe completo do diagnóstico na memória
`aws-cost-t3-unlimited`.

O objetivo aqui não é só reduzir custo — é **eliminar a classe de falha** que
produziu tanto a fatura quanto o incidente de disco cheio.

## 2. Decisões tomadas

| Decisão | Escolha | Motivo |
|---|---|---|
| Durabilidade | Tudo numa máquina + backup automatizado pra S3 | Barato, mas o dado do cliente não se perde |
| Máquina | **t4g.small** (ARM Graviton, 2 GB RAM) | Dobro da RAM atual por US$ 12,26 — mata a causa raiz do OOM |
| Postgres | Container na própria máquina (não RDS) | RDS dobraria a conta; backup pra S3 cobre o risco |
| Deploy | GitHub Actions → GHCR → Tailscale SSH → podman pull | Já planejado; Tailscale acaba com a dor do Security Group |
| CDN | CloudFront **só para os instaladores desktop** | Pega o ganho real (arquivo grande fora da máquina) sem invalidação de cache a cada deploy do front |
| DNS | Fica no Google (nameservers `ns-cloud-e*.googledomains.com`) | Já está lá; Route 53 seria custo e peça a mais |

**Três clientes NÃO são três servidores.** O OrbixHub é multi-tenant com RLS —
os três são `tenant_id` distintos na mesma base, na mesma máquina.

## 3. Arquitetura

```
Cliente 1/2/3 ──▶ DNS Google (hub.orbixsystem.com)
                        │
                        ▼
        ┌──────────────────────────────────┐
        │  EC2 t4g.small (ARM, 2GB, Ohio)  │
        │   nginx :443 ──▶ /api :4500      │
        │   backend NestJS (podman)        │
        │     └─ node --max-old-space=768  │
        │   Postgres 16 + Redis 7 (podman) │
        │   EBS gp3 20GB                   │
        └───────┬──────────────────────────┘
                │
     ┌──────────┼───────────────┬─────────────────┐
     ▼          ▼               ▼                 ▼
 S3 uploads  S3 backups   CloudFront+S3      DLM snapshot
 (fotos,     (pg_dump      (instaladores      EBS semanal
  versionado) diário, 30d)   desktop)
```

Mudanças estruturais frente ao ambiente antigo:

1. **Fotos saem do disco local.** `STORAGE_PROVIDER=minio` apontado para S3 real.
   O código já suporta S3-compatible — é troca de env var, não reescrita. Remove a
   causa do disco cheio e o risco de perder foto ao recriar a máquina.
2. **Instaladores desktop saem da máquina.** Egress de EC2 custa US$ 0,09/GB;
   CloudFront tem free tier de 1 TB/mês.
3. **A máquina fica só com o que precisa de processo vivo** — a stack exige
   WebSocket, jobs agendados (@nestjs/schedule) e geração de PDF, o que descarta
   serverless.

## 4. Custo previsto (us-east-2)

| Item | US$/mês |
|---|---|
| EC2 t4g.small | 12,26 |
| EBS gp3 20 GB | 1,60 |
| IPv4 público | 3,60 |
| Snapshots EBS semanais | ~0,50 |
| S3 (fotos + backups) | ~0,30 |
| CloudFront | 0,00 (free tier) |
| **Total** | **≈ 18,26** |

## 5. Travas contra repetir julho

1. **Modo de crédito `standard`** desde o dia 1 — no pior caso a máquina fica lenta,
   nunca cara. (O padrão da AWS é `unlimited`, que foi o que gerou os US$ 21,26.)
2. **`--max-old-space-size=768`** no Node. Sem teto, o V8 cresce até o kernel matar.
3. **Disco de 20 GB**, não 8. Custa US$ 0,96/mês a mais e remove a classe de problema.
4. **Alarme de budget em US$ 25** + alarme de CPU > 80% por 30 min.
5. **Logrotate + cap no journald** no provisionamento, não depois do incidente.

## 6. Landmine: plano da conta

A API retornou `Free Tier accounts are not supported for this service`. As contas
estão no **plano gratuito novo** (US$ 100 em créditos). Esse plano bloqueia serviços
e **encerra a conta quando os créditos acabam ou em 6 meses**. Antes de colocar
cliente pagante dentro, mudar para o **plano pago** — os créditos continuam valendo.

## 7. Ordem de execução

O TTL do registro A hoje é **14398s (~4h)**. Baixá-lo é o primeiro passo e precisa
acontecer com antecedência, senão o cutover fica refém do cache de DNS.

1. Baixar TTL de `hub.orbixsystem.com` para 300s no painel do Google (**fazer primeiro**)
2. Mudar a conta nova para o plano pago
3. Criar usuário IAM de trabalho + budget alarm de US$ 25
4. Provisionar a t4g.small (ARM, 20 GB gp3, credit mode `standard`)
5. Instalar podman + nginx + Tailscale; subir Postgres e Redis
6. Criar buckets S3 (uploads, backups) + política de lifecycle
7. **Migrar os dados** da máquina antiga: `pg_dump` + `.storage` → nova
8. Validar a nova máquina pelo IP, com o domínio ainda apontando para a antiga
9. Cutover: trocar o A record para o IP novo
10. Emitir TLS (Let's Encrypt), configurar DLM, alarmes e backup diário
11. Desligar/terminar a infra antiga só depois de 1 semana estável

**A máquina antiga precisa ser religada** para o passo 7 — é a única fonte do banco
e das fotos. Ela está parada desde 29/07.
