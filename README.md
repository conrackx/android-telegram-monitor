# Android Internet Monitor (Termux)

Este proyecto configura un sistema de alerta temprana que notifica vía Telegram cuando la conexión a internet retorna tras una caída prolongada. Ideal para servidores Android que operan de forma autónoma.

## Sistema de Alerta (`monitor.sh`)

El script monitorea la disponibilidad de internet mediante pings a `1.1.1.1` (Cloudflare).

### Lógica de Anti-Falsos Positivos
Para evitar alertas causadas por la suspensión de procesos en Android (ahorro de batería), el script utiliza un sistema de doble validación:
1. **Tiempo**: Deben haber pasado al menos 15 minutos desde la caída detectada.
2. **Chequeos Reales**: Deben haberse acumulado al menos **10 chequeos fallidos** mientras el script estaba activo.
3. **Robustez**: Se envían **3 paquetes de ping** por cada chequeo para ignorar ruidos temporales.

### Instalación en el Dispositivo
1. **Dependencias**:
   ```bash
   pkg update && pkg install curl -y
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

## Licencia
Distribuido bajo la Licencia MIT. Ver `LICENSE` para más información.
