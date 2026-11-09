#!/bin/bash

# ==============================================================================
# Alerta de Conectividad Internet
# ==============================================================================
# Este script monitorea la conexión a internet y envía una notificación a 
# Telegram cuando la conexión retorna tras una caída.
# ==============================================================================

# Cargar variables de entorno desde .env
if [ -f "$(dirname "$0")/.env" ]; then
    set -a
    source "$(dirname "$0")/.env"
    set +a
fi

LOG_FILE="$HOME/monitor.log"
PIDFILE="$HOME/.monitor.pid"
TELEGRAM_API="https://api.telegram.org/bot$TELEGRAM_TOKEN"
OFFSET_FILE="$HOME/.monitor_tg_offset_${CHAT_ID}"

if [ -z "$TELEGRAM_TOKEN" ] || [ -z "$CHAT_ID" ]; then
    echo "Error: TELEGRAM_TOKEN o CHAT_ID no están definidos en el archivo .env"
    exit 1
fi

# Alias del dispositivo para notificaciones
DEVICE_NAME="${DEVICE_ALIAS:-"Android Device"}"

# FIX: Adquirir wakelock para evitar que Android congele el proceso
# Requiere: pkg install termux-api
if command -v termux-wake-lock &> /dev/null; then
    termux-wake-lock
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Wakelock adquirido." >> "$LOG_FILE"
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ADVERTENCIA: termux-wake-lock no disponible. Android puede suspender el proceso." >> "$LOG_FILE"
fi

# Registrar PID para permitir consultas remotas de estado
trap 'rm -f "$PIDFILE"' EXIT
echo $$ > "$PIDFILE"

# --- FUNCIONES ---

get_gateway_ip() {
    export PATH="/data/data/com.termux/files/usr/bin:/system/bin:$PATH"
    local gw
    gw=$(ip route show 2>/dev/null | awk '/default/ {print $3; exit}')
    if [ -z "$gw" ]; then
        gw=$(getprop dhcp.wlan0.gateway 2>/dev/null)
    fi
    echo "$gw"
}

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Verifica si el proceso del monitor está vivo leyendo su PIDFILE
is_running() {
    local pid
    [ -f "$PIDFILE" ] || return 1
    pid=$(cat "$PIDFILE" 2>/dev/null)
    [ -n "$pid" ] || return 1
    kill -0 "$pid" 2>/dev/null
}

# Polling de Telegram: escucha comandos del CHAT_ID configurado.
# Comandos soportados: /status (responde si el proceso está corriendo).
telegram_polling() {
    local offset=0
    local updates
    local update_id
    local chat_id
    local text

    [ -f "$OFFSET_FILE" ] && offset=$(cat "$OFFSET_FILE" 2>/dev/null)
    [ -n "$offset" ] || offset=0

    updates=$(curl -s --max-time 5 "$TELEGRAM_API/getUpdates?offset=$((offset + 1))&limit=5&timeout=2")
    [ -n "$updates" ] || return 0

    # Procesar cada update devolviendo el offset más alto visto
    echo "$updates" | grep -o '"update_id":[0-9]*' | while read -r line; do
        update_id="${line#*:}"
        [ "$update_id" -gt "$offset" ] && offset="$update_id"
    done

    # Guardar offset persistente
    echo "$offset" > "$OFFSET_FILE" 2>/dev/null

    # Procesar cada update: encontrar el update_id más alto
    local new_offset=0
    echo "$updates" | grep -o '"update_id":[0-9]*' | while read -r line; do
        update_id="${line#*:}"
        [ "$update_id" -gt "$new_offset" ] && new_offset="$update_id"
    done

    # Guardar offset persistente (solo si hay updates nuevos)
    [ "$new_offset" -gt 0 ] && echo "$new_offset" > "$OFFSET_FILE" 2>/dev/null

    # Revisar comandos /status de nuestro CHAT_ID en el lote de updates
    if echo "$updates" | grep -q '"chat":{"id":'"$CHAT_ID"''; then
        if echo "$updates" | grep -q '"/status"'; then
            if is_running; then
                send_telegram "$CHAT_ID" "✅ El monitor está corriendo en *$DEVICE_NAME*."
            else
                send_telegram "$CHAT_ID" "❌ El monitor *no* está corriendo en *$DEVICE_NAME*."
            fi
        fi
    fi
}

# FIX: Validación de 2/3 pings en lugar de un único ping
# Retorna 0 (éxito) si hay internet, 1 si no hay
internet_check() {
    local host="$1"
    local fails=0
    for i in 1 2 3; do
        ping -c 1 -W 2 "$host" > /dev/null 2>&1 || ((fails++))
        [ $i -lt 3 ] && sleep 1
    done
    # Falla solo si 2 o más de los 3 pings fallan
    [ $fails -ge 2 ] && return 1 || return 0
}

send_telegram() {
    local chat_id="$1"
    local message="$2"
    local sent=false
    local retries=0
    local max_retries=10

    while [ "$sent" = false ] && [ $retries -lt $max_retries ]; do
        response=$(curl -s -X POST "$TELEGRAM_API/sendMessage" \
            -d "chat_id=$chat_id" \
            -d "parse_mode=Markdown" \
            -d "text=$message")

        if [[ "$response" == *"\"ok\":true"* ]]; then
            log_message "Notificación enviada a $chat_id."
            sent=true
        else
            retries=$((retries + 1))
            log_message "Error al enviar notificación a $chat_id (intento $retries/$max_retries). Reintentando en 10 segundos..."
            sleep 10
        fi
    done

    if [ "$sent" = false ]; then
        log_message "No se pudo enviar la notificación a $chat_id tras $max_retries intentos. Se abandona."
    fi
}

send_telegram_notification() {
    local message="$1"
    send_telegram "$CHAT_ID" "$message"
}

# --- BUCLE PRINCIPAL ---
log_message "Iniciando monitoreo de conectividad de internet (Umbral: 15 min / 10 chequeos)..."

CHECK_HOST="1.1.1.1"
THRESHOLD_SECONDS=900   # 15 minutos de tiempo real
MIN_FAILED_CHECKS=10    # Mínimo de chequeos fallidos reales (anti-suspensión Android)
GATEWAY_EMPTY_GRACE=3   # FIX: chequeos de gracia cuando el gateway está vacío

INTERNET_WAS_DOWN=false
DOWN_START_TIME=0
FAILED_CHECKS_COUNT=0
ALERT_PENDING=false
LIKELY_CAUSE="Desconocida"
GATEWAY_EMPTY_COUNT=0   # FIX: contador de chequeos con gateway vacío

while true; do
    GATEWAY_IP=$(get_gateway_ip)

    # FIX: Si el gateway está vacío, dar gracia antes de diagnosticar
    # Puede ser una reconexión transitoria de Wi-Fi aún sin DHCP
    if [ -z "$GATEWAY_IP" ]; then
        GATEWAY_EMPTY_COUNT=$((GATEWAY_EMPTY_COUNT + 1))
    else
        GATEWAY_EMPTY_COUNT=0
    fi

    # FIX: Usar internet_check() con validación 2/3 pings
    if internet_check "$CHECK_HOST"; then
        # --- INTERNET DISPONIBLE ---
        GATEWAY_EMPTY_COUNT=0

        if [ "$INTERNET_WAS_DOWN" = true ]; then
            log_message "¡Internet ha vuelto!"

            if [ "$ALERT_PENDING" = true ]; then
                CURRENT_TIME=$(date +%s)
                DURATION_SECONDS=$((CURRENT_TIME - DOWN_START_TIME))
                DURATION_MIN=$((DURATION_SECONDS / 60))

                log_message "El corte finalizó. Causa probable: $LIKELY_CAUSE. Duración: ${DURATION_MIN} min. Chequeos fallidos: $FAILED_CHECKS_COUNT."

                EMOJI="🌐"
                [ "$LIKELY_CAUSE" == "Corte de Luz (Router Down)" ] && EMOJI="🔌"

                send_telegram_notification "$EMOJI *AVISO DE CONECTIVIDAD:* El internet ha retornado en *$DEVICE_NAME*.

*Causa probable:* $LIKELY_CAUSE
*Duración:* aprox. ${DURATION_MIN} minutos
*Chequeos fallidos:* $FAILED_CHECKS_COUNT"
            else
                log_message "Corte breve detectado (no alcanzó el umbral). No se requiere notificación."
            fi

            # Reset de estado
            INTERNET_WAS_DOWN=false
            ALERT_PENDING=false
            DOWN_START_TIME=0
            FAILED_CHECKS_COUNT=0
            LIKELY_CAUSE="Desconocida"
        fi

    else
        # --- INTERNET CAÍDO ---

        if [ "$INTERNET_WAS_DOWN" = false ]; then
            log_message "Se ha detectado una caída de internet."
            INTERNET_WAS_DOWN=true
            DOWN_START_TIME=$(date +%s)
            FAILED_CHECKS_COUNT=1
        else
            FAILED_CHECKS_COUNT=$((FAILED_CHECKS_COUNT + 1))
        fi

        # FIX: Diagnosticar causa solo si el gateway lleva más de GATEWAY_EMPTY_GRACE
        # chequeos vacíos consecutivos, para evitar falso "Gateway no hallado"
        if [ -n "$GATEWAY_IP" ]; then
            if ping -c 1 -W 1 "$GATEWAY_IP" > /dev/null 2>&1; then
                LIKELY_CAUSE="Falla del Proveedor (ISP)"
            else
                LIKELY_CAUSE="Corte de Luz (Router Down)"
            fi
        elif [ $GATEWAY_EMPTY_COUNT -gt $GATEWAY_EMPTY_GRACE ]; then
            LIKELY_CAUSE="Fallo de Conexión Local (Sin red Wi-Fi)"
        else
            # Gateway vacío pero dentro del período de gracia: no actualizar causa
            log_message "Gateway vacío (intento $GATEWAY_EMPTY_COUNT/$GATEWAY_EMPTY_GRACE), esperando estabilización..."
        fi

        log_message "Caída activa. Causa: $LIKELY_CAUSE. Chequeos fallidos: $FAILED_CHECKS_COUNT. Elapsed: $(( ($(date +%s) - DOWN_START_TIME) / 60 )) min."

        # Verificar umbral para activar alerta pendiente (AND estricto)
        CURRENT_TIME=$(date +%s)
        ELAPSED=$((CURRENT_TIME - DOWN_START_TIME))

        if [ "$ALERT_PENDING" = false ] && \
           [ $ELAPSED -ge $THRESHOLD_SECONDS ] && \
           [ $FAILED_CHECKS_COUNT -ge $MIN_FAILED_CHECKS ]; then
            log_message "Umbral alcanzado (tiempo: ${ELAPSED}s, chequeos: $FAILED_CHECKS_COUNT). Causa: $LIKELY_CAUSE. Alerta preparada para el retorno."
            ALERT_PENDING=true
        fi
    fi

    # Polling de comandos de Telegram (no bloqueante, timeout 2s)
    telegram_polling

    sleep 60
done
