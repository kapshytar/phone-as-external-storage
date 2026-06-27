#!/bin/bash
# Аварийная чистка: снять зависшие маунты/демоны и перезапустить Finder.

# shellcheck source=config.sh
source "$(cd "$(dirname "$0")" && pwd)/config.sh"

pkill -9 -f rclone 2>/dev/null
pkill -9 -f adbfs 2>/dev/null
pkill -9 -f phone-stream 2>/dev/null
sleep 1
_to 12 diskutil unmount force "$HOME/PhoneStream" 2>/dev/null
_to 12 diskutil unmount force /Volumes/PhoneStream 2>/dev/null
umount -f "$HOME/PhoneStream" 2>/dev/null
rmdir "$HOME/PhoneStream" 2>/dev/null   # rmdir, НЕ rm -rf (безопасно: на смонтированной точке просто не сработает)
rm -f /tmp/phonestream.transport 2>/dev/null
# adb мог зависнуть на отвалившемся Wi-Fi — перезапустить сервер
_to 8 "$ADB" kill-server 2>/dev/null
killall Finder 2>/dev/null
echo "cleanup done"
