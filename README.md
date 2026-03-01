# Android Internet Monitor (Termux)

Este proyecto configura un sistema de alerta temprana que notifica vía Telegram cuando la conexión a internet retorna tras una caída prolongada. Ideal para servidores Android que operan de forma autónoma.

## Sistema de Alerta (`monitor.sh`)

El script monitorea la disponibilidad de internet mediante pings a `1.1.1.1` (Cloudflare).

### Lógica de Monitoreo Dinámico
El script no solo detecta la caída, sino que intenta identificar la causa probable usando el **Gateway (Router)** local, aplicando también una gracia de conectividad en caso de desconexiones WiFi pasajeras:
1. **Falla ISP**: El router responde pero internet no. Hay energía localmente.
2. **Corte de Luz (Router Down)**: Ni el router ni internet responden. Se infiere que el router se apagó por falta de energía.
3. **Fallo de Conexión Local (Sin red Wi-Fi)**: Se ha perdido conexión local y el Gateway no se detecta (tras agotar intentos de gracia).

### Lógica de Anti-Falsos Positivos y Anti-Suspensión
Para evitar alertas causadas por la suspensión de procesos en Android (ahorro de batería) o inestabilidad pasajera, el script utiliza un sistema estricto de validación:
1. **Adquisición de Wakelock**: El script interactúa con Termux API (`termux-wake-lock`) para evitar que el OS suspenda su ejecución en segundo plano.
2. **Validación de Internet 2/3**: En lugar de un solo ping, realiza una batería rápida de 3 pings. Solo falla si al menos 2 pings son negativos, filtrando pérdidas de paquetes aisladas.
3. **Tiempo**: Deben haber pasado al menos 15 minutos desde la caída detectada.
4. **Chequeos Reales**: Deben haberse acumulado al menos **10 chequeos fallidos** mientras el script estaba activo.
5. **Reintentos en API de Telegram**: Bucle de 10 reintentos para asegurar el envío del mensaje incluso si el Wi-Fi demora un poco más en reconectar totalmente.
6. **Notificación Inteligente**: Al retornar la conexión, envía un reporte indicando **Causa Probable**, **Duración** y conteo de fallos reales acumulados.

### Instalación en el Dispositivo
1. **Dependencias**:
   ```bash
   pkg update && pkg install curl iproute2 dos2unix termux-api -y
   ```
2. **Configuración**:
   Crea un archivo `.env` en este directorio con:
   ```env
   TELEGRAM_TOKEN="tu_token_aqui"
   CHAT_ID="tu_chat_id_aqui"
   DEVICE_ALIAS="Mi Servidor"  # Opcional: Nombre que aparecerá en el mensaje
   ```
3. **Ejecución en segundo plano**:
   ```bash
   nohup ./monitor.sh > /dev/null 2>&1 &
   ```

### Archivos de Registro
- Log local en `~/monitor.log`.

### Consideraciones (Windows/Termux)
> [!WARNING]
> Si editas o creas los archivos `.env` o `monitor.sh` desde un entorno Windows, saltarán errores por el uso de saltos de línea CRLF (`\r\n`). Al transferir al dispositivo Android (Termux), ejecuta:
> ```bash
> dos2unix .env monitor.sh
> ```

## Licencia
Distribuido bajo la Licencia MIT. Ver `LICENSE` para más información.
