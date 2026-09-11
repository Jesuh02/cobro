#!/usr/bin/env bash
# ==============================================================================
# Script para detener los contenedores de WhatsApp
# ==============================================================================

echo "Deteniendo contenedores de WhatsApp..."
docker stop cobrod-evolution-api cobrod-evolution-db cobrod-redis 2>/dev/null || true
docker rm cobrod-evolution-api cobrod-evolution-db cobrod-redis 2>/dev/null || true
echo "✅ Contenedores detenidos correctamente."

