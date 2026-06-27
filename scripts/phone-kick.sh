#!/bin/bash
# «Передёрнуть» adb/USB — пере-сканировать шину и поймать отвалившийся телефон
# (USB просел при лимите заряда / Wi-Fi WD флапнул). Питание порта без sudo не toggle-нуть,
# но re-enumerate adb обычно восстанавливает дропнутое.

# shellcheck source=config.sh
source "$(cd "$(dirname "$0")" && pwd)/config.sh"

echo "Передёргиваю adb/USB…"

# kill-server guard: если смонтирован FUSE-том телефона — не убиваем сервер
# (убийство adb-сервера при живом маунте дропает форвард → мёртвый маунт).
if /sbin/mount | grep -qE 'Phone-USB|Phone-WiFi'; then
  echo "Обнаружен активный FUSE-маунт — пропускаю kill/start-server, делаю reconnect offline."
  _to 8 "$ADB" reconnect offline >/dev/null 2>&1
else
  _to 8 "$ADB" reconnect offline >/dev/null 2>&1
  _to 8 "$ADB" kill-server  >/dev/null 2>&1; sleep 1
  _to 8 "$ADB" start-server >/dev/null 2>&1; sleep 2
  _to 8 "$ADB" reconnect    >/dev/null 2>&1; sleep 1
fi

# Wi-Fi через mDNS (если WD рекламируется)
EP=$(_to 8 "$ADB" mdns services 2>/dev/null | awk '/_adb-tls-connect._tcp/{print $NF; exit}')
[ -n "$EP" ] && _to 8 "$ADB" connect "$EP" >/dev/null 2>&1

echo "Устройства:"; "$ADB" devices -l | grep -v "^$"
if "$ADB" devices | grep -q $'\tdevice'; then
  echo "Телефон найден."
else
  echo "Телефон не виден. Проверь кабель и что на телефоне включён USB-debugging / Wireless debugging."
fi
