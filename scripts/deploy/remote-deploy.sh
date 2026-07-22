#!/usr/bin/env bash
# Roda NA EC2 (chamado pelo GitHub Actions via SSH/Tailscale).
# Faz o deploy do backend em container podman de forma segura:
# pull -> backup do banco -> migrations -> troca o container -> healthcheck
# -> rollback automatico se falhar -> limpa imagens antigas (disco de 8 GB).
#
# Uso: remote-deploy.sh <image-ref>
set -euo pipefail

IMAGE_REF="${1:?uso: remote-deploy.sh <image-ref>}"

APP_DIR="/home/ubuntu/OrbixHub/back"
ENV_FILE="$APP_DIR/.env"
STORAGE_DIR="$APP_DIR/.storage"       # fotos da OS (STORAGE_PROVIDER=local) — precisa persistir
CONTAINER="orbixhub-api"
BACKUP_DIR="/home/ubuntu/backups"
STATE_FILE="/home/ubuntu/.orbix-last-good-image"
HEALTH_URL="http://localhost:4500/api/health"

log() { echo "[deploy] $*"; }

mkdir -p "$BACKUP_DIR" "$STORAGE_DIR"

log "puxando imagem: $IMAGE_REF"
podman pull "$IMAGE_REF"

log "backup do banco (pg_dump comprimido)"
TS=$(date +%Y%m%d-%H%M%S)
podman exec postgres pg_dump -U app_owner orbixhub | gzip > "$BACKUP_DIR/db-$TS.sql.gz"
# mantem apenas os 5 backups mais recentes (disco de 8 GB)
ls -1t "$BACKUP_DIR"/db-*.sql.gz 2>/dev/null | tail -n +6 | xargs -r rm -f
log "backup salvo em $BACKUP_DIR/db-$TS.sql.gz"

log "aplicando migrations (prisma migrate deploy como app_migrator)"
MIG_URL=$(grep -E '^MIGRATION_DATABASE_URL=' "$ENV_FILE" | cut -d= -f2-)
podman run --rm --network host --env-file "$ENV_FILE" \
  -e DATABASE_URL="$MIG_URL" "$IMAGE_REF" \
  npx prisma migrate deploy

# guarda a imagem atual para rollback
PREV_IMAGE=""
if podman container exists "$CONTAINER"; then
  PREV_IMAGE=$(podman inspect --format '{{.ImageName}}' "$CONTAINER" 2>/dev/null || true)
fi

start_container() {
  local img="$1"
  podman rm -f "$CONTAINER" >/dev/null 2>&1 || true
  podman run -d --name "$CONTAINER" \
    --network host \
    --env-file "$ENV_FILE" \
    -v "$STORAGE_DIR:/app/back/.storage" \
    --restart=always \
    "$img" >/dev/null
}

# migracao do runtime antigo (PM2) -> container, uma vez
if command -v pm2 >/dev/null 2>&1; then
  pm2 delete orbixhub-api >/dev/null 2>&1 || true
  pm2 save --force >/dev/null 2>&1 || true
fi

log "subindo container novo"
start_container "$IMAGE_REF"

log "healthcheck (ate 60s)"
ok=""
for _ in $(seq 1 30); do
  if curl -fsS "$HEALTH_URL" 2>/dev/null | grep -q '"status":"ok"'; then ok=1; break; fi
  sleep 2
done

if [ -z "$ok" ]; then
  log "HEALTHCHECK FALHOU — iniciando rollback"
  if [ -n "$PREV_IMAGE" ]; then
    log "rollback para $PREV_IMAGE"
    start_container "$PREV_IMAGE"
  else
    log "sem imagem anterior para rollback"
  fi
  exit 1
fi

echo "$IMAGE_REF" > "$STATE_FILE"
log "OK — backend no ar: $IMAGE_REF"

log "limpando imagens antigas (podman image prune)"
podman image prune -f >/dev/null 2>&1 || true
log "concluido"
