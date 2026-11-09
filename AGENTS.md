# AGENTS.md — android-telegram-monitor

Convenciones y comandos del proyecto `android-telegram-monitor`, adaptado al estándar del hub central `/home/conrack/code`.

## Propósito

Script de Bash para Termux (Android) que monitorea la conexión a internet y envía una notificación por Telegram cuando la conexión retorna tras una caída prolongada. Detecta la causa probable (ISP, corte de luz/router, o fallo de conexión local Wi-Fi) y evita falsos positivos mediante validación 2/3 pings, wakelock de Android y umbrales de tiempo y chequeos fallidos.

## Estándares aplicados

Hereda (en orden de carga):

1. `.opencode/opencode.jsonc` (sub-proyecto, mayor prioridad)
2. `../AGENTS.md` — workspace root
3. `../ENGINEERING_STANDARDS.md` — estándares globales
4. `AGENTS.md` — este archivo (proyecto)
5. `AGENTS.local.md` — plugins (gitignored)

## Estructura del proyecto

```
android-telegram-monitor/
├── AGENTS.md                 # este archivo
├── AGENTS.local.md           # plugins (gitignored, no commitear)
├── .env                      # credenciales locales (gitignored, no commitear)
├── .env.example              # plantilla de entorno (versionado, sin secretos)
├── .gitignore                # ignora .env, monitor.log, nohup.out
├── LICENSE                   # MIT
├── README.md                 # documentación de uso
├── monitor.sh                # script principal de monitoreo
├── verify_env.sh             # utilidad de verificación de .env
├── .opencode/
│   └── opencode.jsonc        # herencia de instrucciones del hub
├── tests/
│   └── test_monitor.sh       # tests unitarios del script
└── .github/
    └── workflows/
        └── ci.yml            # CI: shellcheck, tests, secret scanning
```

## Comandos

Desde la raíz del proyecto:

| Comando | Descripción |
|---------|-------------|
| `./verify_env.sh` | Verifica que `.env` carga correctamente las variables |
| `shellcheck monitor.sh verify_env.sh` | Lint estático de Bash |
| `bash tests/test_monitor.sh` | Ejecuta tests unitarios |
| `nohup ./monitor.sh > /dev/null 2>&1 &` | Ejecuta el monitor en segundo plano (Termux) |

## Configuración

1. Copiar `.env.example` a `.env` y rellenar los placeholders.
2. `.env` está en `.gitignore` — **nunca se sube a git**.
3. Dependencias del sistema (Termux): `curl`, `iproute2`, `dos2unix`, `termux-api`.

## Reglas del proyecto

- No commitear secretos, tokens, contraseñas ni PII (`.env` está gitignored).
- Cualquier cambio en `monitor.sh` debe ir acompañado de tests en `tests/`.
- Mantener el script con anidamiento ≤ 3 niveles (ENGINEERING_STANDARDS cap. 3).
- UTF-8 sin BOM; evitar saltos de línea CRLF en Termux (`dos2unix` si se edita desde Windows).
