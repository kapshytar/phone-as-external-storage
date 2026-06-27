#!/bin/bash
# phone-unmount.sh <usb|wifi|all>
# Размонтирует указанный канал (или оба при "all"):
#   diskutil unmount force, pkill демона, adb forward --remove (только USB), rmdir точки,
#   rm transport-файла.
set -u

# shellcheck source=config.sh
source "$(cd "$(dirname "$0")" && pwd)/config.sh"

unmount_one() {
  local T="$1"
  local MNT

  if [ "$T" = "usb" ]; then
    MNT="$HOME/Phone-USB"
    # USB-форвард слушает на PHONE_SSH_PORT (8022) — снять его
    USB_FWD_PORT="$PHONE_SSH_PORT"
  elif [ "$T" = "wifi" ]; then
    MNT="$HOME/Phone-WiFi"
    # Wi-Fi идёт прямым SSH — adb forward не использовался, снимать нечего
    USB_FWD_PORT=""
  else
    echo "Неизвестный транспорт: $T (usb|wifi|all)"
    return 1
  fi

  echo "Размонтирование $T ($MNT)…"

  # убить rclone-демон этой точки
  pkill -f "rclone mount.*$MNT" 2>/dev/null
  sleep 0.5

  # размонтировать том
  if mount | grep -q " $MNT "; then
    _to 12 diskutil unmount force "$MNT" >/dev/null 2>&1 && echo "  unmount OK" || echo "  unmount: уже отключено"
  fi

  # снять adb forward только для USB-канала (Wi-Fi форвардов нет)
  if [ -n "$USB_FWD_PORT" ]; then
    _to 8 "$ADB" forward --remove "tcp:${USB_FWD_PORT}" 2>/dev/null || true
  fi

  # убрать точку маунта (rmdir — только если пуста)
  rmdir "$MNT" 2>/dev/null || true

  # убрать transport-файл
  rm -f "/tmp/phonestream.${T}.transport"

  echo "  $T размонтирован."
}

ARG="${1:-}"
case "$ARG" in
  usb)  unmount_one usb ;;
  wifi) unmount_one wifi ;;
  all)
    unmount_one usb
    unmount_one wifi
    ;;
  *)
    echo "Использование: $0 <usb|wifi|all>"
    exit 1
    ;;
esac
