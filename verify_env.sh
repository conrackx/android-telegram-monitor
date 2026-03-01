#!/bin/bash
# Simular carga de .env igual que en monitor.sh
if [ -f "$(dirname "$0")/.env" ]; then
    # Cargar variables ignorando comentarios y manejando espacios correctamente
    set -a
    source "$(dirname "$0")/.env"
    set +a
fi

echo "TOKEN: ${TELEGRAM_TOKEN:0:5}..."
echo "CHAT_ID: $CHAT_ID"
echo "DEVICE_ALIAS: ${DEVICE_ALIAS:-"No configurado (usando fallback)"}"

if [ -n "$TELEGRAM_TOKEN" ] && [ -n "$CHAT_ID" ]; then
    echo "VERIFICACIÓN EXITOSA: Variables cargadas."
else
    echo "VERIFICACIÓN FALLIDA: Variables NO cargadas."
    exit 1
fi
