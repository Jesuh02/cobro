#!/usr/bin/env bash
# ==============================================================================
# Script para iniciar Evolution API y PostgreSQL (Compatible con Docker estándar y Compose)
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Asegurar que exista archivo .env
if [ ! -f ".env" ]; then
  echo "Creando .env a partir de .env.example..."
  cp .env.example .env
fi

# Cargar variables
source .env

PORT="${PORT:-8080}"
SERVER_URL="${SERVER_URL:-http://localhost:8080}"
API_KEY="${AUTHENTICATION_API_KEY:-cobrod-secure-evolution-key}"
INSTANCE="${EVOLUTION_INSTANCE_NAME:-cobrod}"
DB_USER="${POSTGRES_USER:-evolution}"
DB_PASS="${POSTGRES_PASSWORD:-evolution_secret_password}"
DB_NAME="${POSTGRES_DB:-evolution}"

echo "=========================================================="
echo "🚀 Iniciando stack de WhatsApp (Evolution API v2.3.7)..."
echo "Puerto:       http://localhost:${PORT}"
echo "API Key:      ${API_KEY}"
echo "Instancia:    ${INSTANCE}"
echo "=========================================================="

# 1. Crear red y volumen si no existen
docker network create cobrod_evolution_net 2>/dev/null || true
docker volume create cobrod_evolution_db_data 2>/dev/null || true

# 2. Iniciar PostgreSQL si no está corriendo
if [ ! "$(docker ps -q -f name=^/cobrod-evolution-db$)" ]; then
  echo "Iniciando contenedor PostgreSQL (cobrod-evolution-db)..."
  docker rm -f cobrod-evolution-db 2>/dev/null || true
  docker run -d \
    --name cobrod-evolution-db \
    --restart unless-stopped \
    --network cobrod_evolution_net \
    -v cobrod_evolution_db_data:/var/lib/postgresql/data \
    -e POSTGRES_USER="${DB_USER}" \
    -e POSTGRES_PASSWORD="${DB_PASS}" \
    -e POSTGRES_DB="${DB_NAME}" \
    postgres:15-alpine
fi

echo "Esperando que la base de datos esté lista..."
for i in {1..20}; do
  if docker exec cobrod-evolution-db pg_isready -U "${DB_USER}" -d "${DB_NAME}" >/dev/null 2>&1; then
    echo "✅ Base de datos lista."
    break
  fi
  sleep 1
done

# 3. Iniciar Redis si no está corriendo
if [ ! "$(docker ps -q -f name=^/cobrod-redis$)" ]; then
  echo "Iniciando contenedor Redis (cobrod-redis)..."
  docker rm -f cobrod-redis 2>/dev/null || true
  docker run -d \
    --name cobrod-redis \
    --restart unless-stopped \
    --network cobrod_evolution_net \
    redis:7-alpine
fi

# 4. Iniciar Evolution API si no está corriendo
if [ ! "$(docker ps -q -f name=^/cobrod-evolution-api$)" ]; then
  echo "Iniciando contenedor Evolution API (cobrod-evolution-api)..."
  docker rm -f cobrod-evolution-api 2>/dev/null || true
  docker run -d \
    --name cobrod-evolution-api \
    --restart unless-stopped \
    --network cobrod_evolution_net \
    -p "${PORT}:8080" \
    -e SERVER_URL="${SERVER_URL}" \
    -e AUTHENTICATION_API_KEY="${API_KEY}" \
    -e DATABASE_PROVIDER="postgresql" \
    -e DATABASE_CONNECTION_URI="postgresql://${DB_USER}:${DB_PASS}@cobrod-evolution-db:5432/${DB_NAME}?schema=public" \
    -e DATABASE_SAVE_DATA_INSTANCE="true" \
    -e DATABASE_SAVE_DATA_NEW_MESSAGE="false" \
    -e DATABASE_SAVE_MESSAGE_HISTORIC="false" \
    -e DATABASE_SAVE_DATA_CHATS="false" \
    -e DATABASE_SAVE_DATA_CONTACTS="false" \
    -e CACHE_REDIS_ENABLED="true" \
    -e CACHE_REDIS_URI="redis://cobrod-redis:6379/1" \
    -e QRCODE_LIMIT="30" \
    -e DEL_INSTANCE="false" \
    evoapicloud/evolution-api:v2.3.2
fi

echo ""
echo "⏳ Esperando a que Evolution API termine de inicializar..."
for i in {1..30}; do
  if curl -s -f "http://localhost:${PORT}" > /dev/null 2>&1; then
    echo "✅ Evolution API en línea y saludable!"
    break
  fi
  sleep 1
done

echo ""
echo "⚙️ Verificando / creando la instancia '${INSTANCE}'..."
CREATE_RES=$(curl -s -X POST "http://localhost:${PORT}/instance/create" \
  -H "apikey: ${API_KEY}" \
  -H "Content-Type: application/json" \
  -d "{\"instanceName\": \"${INSTANCE}\", \"integration\": \"WHATSAPP-BAILEYS\", \"qrcode\": true}" 2>&1 || true)

echo ""
echo "=========================================================="
echo "🎉 ¡LISTO PARA VINCULAR WHATSAPP!"
echo ""
echo "1. Abre en tu navegador la siguiente URL para ver el código QR:"
echo "👉 http://localhost:${PORT}/instance/connect/${INSTANCE}"
echo ""
echo "2. En tu móvil, abre WhatsApp Business:"
echo "   - Ve a Ajustes / Menú > Dispositivos vinculados"
echo "   - Toca 'Vincular un dispositivo' y escanea el código QR en pantalla."
echo ""
echo "Para detener los servicios ejecuta:"
echo "./docker/whatsapp/stop.sh"
echo "=========================================================="
