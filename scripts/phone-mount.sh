#!/bin/bash
# phone-mount.sh <usb|wifi>
# Монтирует один канал в независимую точку.
#   USB  → ~/Phone-USB   : adb forward tcp:8022→sshd(8022), host=127.0.0.1
#   Wi-Fi → ~/Phone-WiFi : ПРЯМОЙ SSH на IP телефона:8022 (БЕЗ adb, БЕЗ Wireless Debugging)
# Идемпотентно: если уже смонтировано и ls работает — exit 0.
set -u

ADB="$HOME/Library/Android/sdk/platform-tools/adb"
RCLONE=/usr/local/bin/rclone
KEY="$HOME/.ssh/id_ed25519_phone"
IPCACHE="$HOME/.phone_wifi_ip"

PUSER=$("$RCLONE" config show phone 2>/dev/null | awk '/^\s*user\s*=/{print $3; exit}')
PUSER="${PUSER:-u0_a520}"

T="${1:-}"
[ "$T" = "usb" ] || [ "$T" = "wifi" ] || { echo "Использование: $0 <usb|wifi>"; exit 1; }

pick_usb() { "$ADB" devices -l | awk '/ device / && /usb:/ {print $1}' | head -1; }

# ---- определить канал: HOST/PORT/точка ----
if [ "$T" = "usb" ]; then
  MNT="$HOME/Phone-USB"; LABEL="USB"; HOST="127.0.0.1"; RPORT=8022
  DEV=$(pick_usb)
else
  MNT="$HOME/Phone-WiFi"; LABEL="Wi-Fi"; RPORT=8022
  # IP из кэша (пишется keepalive/transport, пока телефон на USB); fallback — спросить adb
  HOST=$(cat "$IPCACHE" 2>/dev/null | tr -d '\r')
  if [ -z "$HOST" ]; then
    u=$(pick_usb); [ -n "$u" ] && HOST=$("$ADB" -s "$u" shell "ip -f inet addr show wlan0 2>/dev/null" 2>/dev/null | awk '/inet /{print $2}' | cut -d/ -f1 | tr -d '\r' | head -1)
    [ -n "$HOST" ] && echo "$HOST" > "$IPCACHE"
  fi
fi

# ---- атомарный lock ----
LOCK="/tmp/phonestream.${T}.lock"
mkdir "$LOCK" 2>/dev/null || { echo "Монтирование $LABEL уже идёт — подожди."; exit 0; }
trap 'rmdir "$LOCK" 2>/dev/null' EXIT INT TERM

# ---- уже смонтировано? ----
if mount | grep -q " $MNT " && ls "$MNT" >/dev/null 2>&1; then
  echo "Уже смонтировано: $MNT"; exit 0
fi

# ---- подготовка канала ----
if [ "$T" = "usb" ]; then
  [ -n "$DEV" ] || { echo "Нет USB-устройства. Воткни кабель / включи USB-debugging."; exit 1; }
  echo "USB-устройство: $DEV"
  "$ADB" -s "$DEV" shell "settings put global wifi_sleep_policy 2; dumpsys deviceidle disable" >/dev/null 2>&1
  "$ADB" -s "$DEV" forward "tcp:${RPORT}" tcp:8022 >/dev/null 2>&1
  MODEL=$("$ADB" -s "$DEV" shell getprop ro.product.model 2>/dev/null | tr -d '\r')
else
  [ -n "$HOST" ] || { echo "Не знаю IP телефона. Подключи раз по USB (закэширую IP) или впиши в $IPCACHE."; exit 1; }
  echo "Wi-Fi прямой SSH: $HOST:$RPORT (Wireless Debugging НЕ нужен)"
  ping -c1 -t2 "$HOST" >/dev/null 2>&1 || { echo "Телефон $HOST не пингуется (не в сети / спит)."; exit 1; }
  MODEL=$(ssh -i "$KEY" -p "$RPORT" -o StrictHostKeyChecking=no -o ConnectTimeout=5 "$PUSER@$HOST" "getprop ro.product.model" 2>/dev/null | tr -d '\r')
fi
VOL="${MODEL:+$MODEL ($LABEL)}"; VOL="${VOL:-Phone $LABEL}"

# ---- очистить старую точку ----
pkill -f "rclone mount.*$MNT" 2>/dev/null; sleep 0.5
mount | grep -q " $MNT " && diskutil unmount force "$MNT" >/dev/null 2>&1
rmdir "$MNT" 2>/dev/null   # НЕ rm -rf — это точка маунта, не данные
mkdir -p "$MNT"

# ---- SSH-probe (таймаут 6с) ----
CONN=":sftp,host=${HOST},port=${RPORT},user=${PUSER},key_file=${KEY},shell_type=none:"
if ! "$RCLONE" lsd "$CONN" --timeout 6s --contimeout 6s --low-level-retries 1 >/dev/null 2>&1; then
  echo "sshd на телефоне недоступен по $LABEL ($HOST:$RPORT)."
  echo "Запусти sshd: виджет «Start-SSHD» (Termux:Widget) или ./sshd-on.sh в Termux, затем Mount снова."
  exit 2
fi

# ---- монтирование ----
LOG="/tmp/rclone_${T}.log"
"$RCLONE" mount \
  ":sftp,host=${HOST},port=${RPORT},user=${PUSER},key_file=${KEY},shell_type=none:storage/shared" \
  "$MNT" \
  --vfs-cache-mode writes --vfs-read-chunk-streams 8 --vfs-read-chunk-size 8M \
  --dir-cache-time 24h --attr-timeout 1m --no-checksum --vfs-fast-fingerprint \
  --daemon-timeout 15s --sftp-concurrency 64 --sftp-skip-links --poll-interval 0 \
  --network-mode --noappledouble --noapplexattr --volname "$VOL" --no-modtime \
  --daemon --log-file "$LOG" --log-level INFO

# ---- дождаться маунта ----
for i in $(seq 1 10); do
  sleep 1
  if mount | grep -q " $MNT "; then
    echo "$LABEL" > "/tmp/phonestream.${T}.transport"
    echo "Смонтировано ($LABEL) → $MNT  [volname: $VOL]"; exit 0
  fi
done
echo "Не удалось смонтировать $LABEL. Лог:"; tail -6 "$LOG"; exit 1
