#!/usr/bin/env bash
# install.sh — установка LaunchAgent для adbfs-phone (авто-маунт при подключении USB)
# Вызывается из setup.sh с параметрами; можно запустить и вручную.

set -euo pipefail

PLIST_NAME="com.kapshytar.adbfs-phone.plist"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLIST_SRC="$SCRIPT_DIR/$PLIST_NAME"
PLIST_DST="$HOME/Library/LaunchAgents/$PLIST_NAME"
UID_VAL="$(id -u)"

echo "=== Установка adbfs LaunchAgent ==="

chmod +x "$SCRIPT_DIR/adbfs-launchd-run.sh"
echo "  [ok] adbfs-launchd-run.sh → исполняемый"

mkdir -p "$HOME/Library/LaunchAgents"
cp "$PLIST_SRC" "$PLIST_DST"
echo "  [ok] Скопирован: $PLIST_DST"

if command -v plutil &>/dev/null; then
    plutil -lint "$PLIST_DST" && echo "  [ok] plist синтаксис OK"
fi

if launchctl list "$PLIST_NAME" &>/dev/null 2>&1; then
    echo "  Агент уже загружен, перезагружаем..."
    launchctl bootout "gui/$UID_VAL/$PLIST_NAME" 2>/dev/null || true
    sleep 1
fi

launchctl bootstrap "gui/$UID_VAL" "$PLIST_DST"
echo "  [ok] Агент загружен: com.kapshytar.adbfs-phone"
echo ""
echo "  Статус:  launchctl list com.kapshytar.adbfs-phone"
echo "  Логи:    tail -f /tmp/adbfs-phone.out.log"
