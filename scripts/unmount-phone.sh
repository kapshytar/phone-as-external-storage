#!/bin/bash
# Размонтирует все тома телефона (adbfs и rclone-стрим).
for mnt in "$HOME/Phone" "$HOME/Phone-SD" "$HOME/Phone-System" "$HOME/PhoneStream" "$HOME/droid"; do
  if mount | grep -q " $mnt "; then
    umount "$mnt" 2>/dev/null || diskutil unmount force "$mnt" 2>/dev/null
    if mount | grep -q " $mnt "; then echo "НЕ размонтировано: $mnt"; else echo "Размонтировано: $mnt"; fi
  fi
done
pkill -f "adbfs .*/Phone" 2>/dev/null || true
pkill -f "adbfs .*/droid" 2>/dev/null || true

# убрать проброс порта
"$HOME/Library/Android/sdk/platform-tools/adb" forward --remove tcp:8022 2>/dev/null || true

# вернуть телефон в спокойный режим (батарея/нагрев), раз больше не работаем
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
"$SCRIPT_DIR/phone-restrict.sh" restore 2>/dev/null || true
echo "Готово."
