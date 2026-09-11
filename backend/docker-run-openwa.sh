#!/usr/bin/env bash
# ==============================================================================
# Script para iniciar el contenedor Docker de Open-WA (WhatsApp Gateway)
# ==============================================================================

set -e

CONTAINER_NAME="cobrod-openwa"
PORT="${OPENWA_PORT:-8080}"
SESSION_DIR="$(pwd)/.openwa-session"
API_KEY="${OPENWA_API_KEY:-cobrod-secure-openwa-key}"

mkdir -p "$SESSION_DIR"

echo "=========================================================="
echo "Iniciando contenedor Open-WA ($CONTAINER_NAME)..."
echo "Puerto:      http://localhost:$PORT"
echo "Sesión:      $SESSION_DIR"
echo "Clave API:   $API_KEY"
echo "=========================================================="

# Detener y remover contenedor previo si ya existe
if [ "$(docker ps -aq -f name=^/${CONTAINER_NAME}$)" ]; then
  echo "Deteniendo y eliminando contenedor previo..."
  docker rm -f "$CONTAINER_NAME"
fi

# Ejecutar contenedor
docker run -d \
  --name "$CONTAINER_NAME" \
  --restart unless-stopped \
  -p "${PORT}:8002" \
  -v "${SESSION_DIR}:/sessions" \
  -e API_KEY="$API_KEY" \
  openwa/wa-automate

echo ""
echo "✅ Contenedor $CONTAINER_NAME iniciado en segundo plano."
echo "Para escanear el código QR con tu WhatsApp en el móvil, abre en el navegador:"
echo "👉 http://localhost:${PORT}"
echo ""
echo "Para ver los logs en tiempo real ejecuta:"
echo "docker logs -f $CONTAINER_NAME"

