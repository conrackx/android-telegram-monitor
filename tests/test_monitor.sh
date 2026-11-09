#!/bin/bash
# ==============================================================================
# tests/test_monitor.sh — Tests unitarios de android-telegram-monitor
# Ejecutar con: bash tests/test_monitor.sh
# ==============================================================================
set -euo pipefail

PASS=0
FAIL=0

assert_file_exists() {
    local desc="$1" path="$2"
    if [ -f "$path" ]; then
        echo "PASS: $desc ($path existe)"
        PASS=$((PASS + 1))
    else
        echo "FAIL: $desc ($path NO existe)"
        FAIL=$((FAIL + 1))
    fi
}

assert_gitignore_ignores() {
    local desc="$1" pattern="$2"
    if grep -qF "$pattern" .gitignore 2>/dev/null; then
        echo "PASS: $desc (.gitignore ignora '$pattern')"
        PASS=$((PASS + 1))
    else
        echo "FAIL: $desc (.gitignore NO ignora '$pattern')"
        FAIL=$((FAIL + 1))
    fi
}

assert_env_example_has_var() {
    local desc="$1" var="$2"
    if grep -qE "^${var}=" .env.example 2>/dev/null; then
        echo "PASS: $desc (.env.example define '$var')"
        PASS=$((PASS + 1))
    else
        echo "FAIL: $desc (.env.example NO define '$var')"
        FAIL=$((FAIL + 1))
    fi
}

assert_monitor_has_function() {
    local desc="$1" fn="$2"
    if grep -qE "^${fn}\s*\(\)" monitor.sh 2>/dev/null; then
        echo "PASS: $desc (monitor.sh tiene función '$fn')"
        PASS=$((PASS + 1))
    else
        echo "FAIL: $desc (monitor.sh NO tiene función '$fn')"
        FAIL=$((FAIL + 1))
    fi
}

echo "=== Tests unitarios: android-telegram-monitor ==="
echo ""

# Archivos obligatorios del estándar del hub
assert_file_exists "AGENTS.md del proyecto" "AGENTS.md"
assert_file_exists "OpenCode config" ".opencode/opencode.jsonc"
assert_file_exists "Plantilla de entorno" ".env.example"
assert_file_exists "Script principal" "monitor.sh"
assert_file_exists "Utilidad de verificación" "verify_env.sh"
assert_file_exists "LICENSE" "LICENSE"
assert_file_exists "README.md" "README.md"

# .gitignore debe ignorar .env y artifacts de runtime
assert_gitignore_ignores ".env está gitignored" ".env"
assert_gitignore_ignores "monitor.log está gitignored" "monitor.log"
assert_gitignore_ignores "nohup.out está gitignored" "nohup.out"

# .env.example debe definir las variables de entorno
assert_env_example_has_var "TELEGRAM_TOKEN" "TELEGRAM_TOKEN"
assert_env_example_has_var "CHAT_ID" "CHAT_ID"
assert_env_example_has_var "DEVICE_ALIAS" "DEVICE_ALIAS"
assert_env_example_has_var "PRODUCTIVE_HOST (SSH)" "PRODUCTIVE_HOST"
assert_env_example_has_var "PRODUCTIVE_USER (SSH)" "PRODUCTIVE_USER"
assert_env_example_has_var "PRODUCTIVE_PORT (SSH)" "PRODUCTIVE_PORT"
assert_env_example_has_var "PRODUCTIVE_SSH_KEY (SSH)" "PRODUCTIVE_SSH_KEY"
assert_env_example_has_var "PRODUCTIVE_PASSWORD (SSH placeholder)" "PRODUCTIVE_PASSWORD"

# monitor.sh debe tener las funciones clave
assert_monitor_has_function "get_gateway_ip" "get_gateway_ip"
assert_monitor_has_function "internet_check" "internet_check"
assert_monitor_has_function "send_telegram_notification" "send_telegram_notification"
assert_monitor_has_function "send_telegram" "send_telegram"
assert_monitor_has_function "is_running" "is_running"
assert_monitor_has_function "telegram_polling" "telegram_polling"

echo ""
echo "=== Resultado: $PASS passed, $FAIL failed ==="
if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
exit 0
