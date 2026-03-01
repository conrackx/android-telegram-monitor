#!/bin/bash

# ==============================================================================
# Alerta de Conectividad Internet
# ==============================================================================
# Este script monitorea la conexión a internet y envía una notificación a 
# Telegram cuando la conexión retorna tras una caída.
# ==============================================================================

# Cargar variables de entorno desde .env
if [ -f "$(dirname "$0")/.env" ]; then
    # Cargar variables manejando espacios y comillas correctamente
    set -a
    source "$(dirname "$0")/.env"
    set +a
fi

LOG_FILE="$HOME/monitor.log"

if [ -z "$TELEGRAM_TOKEN" ] || [ -z "$CHAT_ID" ]; then
    echo "Error: TELEGRAM_TOKEN o CHAT_ID no están definidos en el archivo .env"
    exit 1
fi

# Alias del dispositivo para notificaciones (usar valor de .env o fallback genérico)
DEVICE_NAME="${DEVICE_ALIAS:-"Android Device"}"

# --- FUNCIONES ---

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

send_telegram_notification() {
    local message="$1"
    local sent=false
    
    # Bucle hasta que el mensaje sea enviado (útil si el Wi-Fi tarda en subir)
    while [ "$sent" = false ]; do
        response=$(curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendMessage" \
            -d "chat_id=$CHAT_ID" \
            -d "text=$message")
            
        if [[ "$response" == *"\"ok\":true"* ]]; then
            log_message "Notificación enviada con éxito."
            sent=true
        else
            log_message "Error al enviar notificación. Reintentando en 10 segundos..."
            sleep 10
        fi
    done
}

# --- BUCLE PRINCIPAL ---
log_message "Iniciando monitoreo de conectividad de internet (Umbral: 15 min)..."

# Host confiable para verificar internet (Cloudflare DNS)
CHECK_HOST="1.1.1.1"
THRESHOLD_SECONDS=900 # 15 minutos
MIN_FAILED_CHECKS=10  # Mínimo de chequeos fallidos reales para disparar alerta (evita fallos por suspensión de proceso)

INTERNET_WAS_DOWN=false
DOWN_START_TIME=0
FAILED_CHECKS_COUNT=0
ALERT_PENDING=false

while true; do
    # Intentar ping de 3 paquetes para mayor robustez ante ruidos de red
    if ping -c 3 -i 0.5 -W 2 $CHECK_HOST > /dev/null 2>&1; then
        if [ "$INTERNET_WAS_DOWN" = true ]; then
            log_message "¡Internet ha vuelto!"
            
            if [ "$ALERT_PENDING" = true ]; then
                CURRENT_TIME=$(date +%s)
                DURATION_SECONDS=$((CURRENT_TIME - DOWN_START_TIME))
                DURATION_MIN=$((DURATION_SECONDS / 60))
                
                log_message "El corte superó los 15 min y tuvo $FAILED_CHECKS_COUNT chequeos fallidos. Enviando notificación..."
                send_telegram_notification "🌐 *AVISO DE CONECTIVIDAD:* El internet ha retornado en *$DEVICE_NAME* tras una caída detectada de aprox. ${DURATION_MIN} minutos (Chequeos fallidos: $FAILED_CHECKS_COUNT)."
            else
                log_message "Corte breve o sospecha de suspensión detectada ($FAILED_CHECKS_COUNT chequeos). No se requiere notificación."
            fi
            
            INTERNET_WAS_DOWN=false
            ALERT_PENDING=false
            DOWN_START_TIME=0
            FAILED_CHECKS_COUNT=0
        fi
    else
        if [ "$INTERNET_WAS_DOWN" = false ]; then
            log_message "Se ha detectado una caída de internet."
            INTERNET_WAS_DOWN=true
            DOWN_START_TIME=$(date +%s)
            FAILED_CHECKS_COUNT=1
        else
            FAILED_CHECKS_COUNT=$((FAILED_CHECKS_COUNT + 1))
            
            # Verificar si ya superamos el umbral de tiempo Y el umbral de chequeos reales
            CURRENT_TIME=$(date +%s)
            ELAPSED=$((CURRENT_TIME - DOWN_START_TIME))
            
            if [ "$ALERT_PENDING" = false ] && [ $ELAPSED -ge $THRESHOLD_SECONDS ] && [ $FAILED_CHECKS_COUNT -ge $MIN_FAILED_CHECKS ]; then
                log_message "La caída ha superado los 15 minutos y 10 chequeos. Se enviará alerta al retornar."
                ALERT_PENDING=true
            fi
        fi
    fi

    # Esperar 60 segundos antes de la siguiente comprobación
    sleep 60
done
