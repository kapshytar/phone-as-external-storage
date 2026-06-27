#!/bin/bash
# Принудительно снять ВСЕ возможные точки маунта телефона (adbfs + rclone) и перезапустить Finder.

# shellcheck source=config.sh
source "$(cd "$(dirname "$0")" && pwd)/config.sh"

pkill -9 -f adbfs 2>/dev/null
pkill -9 -f "rclone mount" 2>/dev/null
sleep 1
for m in "$HOME/Phone" "$HOME/Phone-USB" "$HOME/Phone-WiFi" "$HOME/Phone-SD" "$HOME/Phone-System" "$HOME/PhoneStream" /Volumes/Phone-USB /Volumes/Phone-WiFi; do
  _to 12 diskutil unmount force "$m" 2>/dev/null
  umount -f "$m" 2>/dev/null
  rmdir "$m" 2>/dev/null
done
killall Finder 2>/dev/null
echo "stale mounts killed + Finder restarted"
