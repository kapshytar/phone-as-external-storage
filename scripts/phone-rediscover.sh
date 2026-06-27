#!/bin/bash
# «ПОДКЛЮЧИТЬ ВСЁ»: пробегается по ВСЕМ способам инициализации каждого канала
# и печатает итог — что поднялось. Идемпотентно (рабочее не ломает).
set -u
ADB="$HOME/Library/Android/sdk/platform-tools/adb"
DIR="$(cd "$(dirname "$0")" && pwd)"
IP=$(cat "$HOME/.phone_wifi_ip" 2>/dev/null | tr -d '\r'); IP="${IP:-192.168.1.202}"

echo "Подключаю все каналы…"

# 0) перезапуск adb-сервера — чинит протухший mDNS на macOS и пере-сканирует USB-шину
"$ADB" kill-server  >/dev/null 2>&1; sleep 1
"$ADB" start-server >/dev/null 2>&1; sleep 2

# 1) USB: re-enumerate (если порт живой — телефон поднимется как usb:)
"$ADB" reconnect offline >/dev/null 2>&1

# 2) Wi-Fi adb / Wireless-debug — все способы:
#    a) mDNS (динамический порт WD)
"$ADB" mdns services >/dev/null 2>&1; sleep 1
EP=$("$ADB" mdns services 2>/dev/null | awk '/_adb-tls-connect._tcp/{print $NF; exit}')
[ -n "$EP" ] && "$ADB" connect "$EP" >/dev/null 2>&1
#    b) фикс-порт 5555 (если adbd слушает)
nc -z -G1 "$IP" 5555 >/dev/null 2>&1 && "$ADB" connect "$IP:5555" >/dev/null 2>&1

# 3) Wi-Fi SSH — проверка (поднять удалённо нельзя; watchdog на телефоне сам держит)
SSH_OK=no
nc -z -G2 "$IP" 8022 >/dev/null 2>&1 && SSH_OK=yes

sleep 2

# 4) тома (best effort)
bash "$DIR/phone-mount-all.sh" >/dev/null 2>&1 || true

# ── ИТОГ: что поднялось ──
echo "──────── РЕЗУЛЬТАТ ────────"
U=$("$ADB" devices -l 2>/dev/null | grep 'usb:' | awk '{print $1}')
[ -n "$U" ] && echo "🟢 USB (кабель): $U" || echo "⚪️ USB: нет (проверь кабель=дата и порт)"
WC=$("$ADB" devices 2>/dev/null | grep -E ':[0-9]+|_adb-tls' | grep -c device)
[ "$WC" -gt 0 ] && echo "🟢 Wi-Fi adb (Wireless-debug): $WC вход(а)" || echo "⚪️ Wi-Fi adb: нет (включи Wireless Debugging на телефоне)"
[ "$SSH_OK" = yes ] && echo "🟢 Wi-Fi SSH (8022): жив" || echo "⚪️ Wi-Fi SSH: нет (на телефоне запусти sshd: виджет Start-SSHD)"
/sbin/mount | grep -q Phone-USB  && echo "🟢 Папка USB смонтирована"  || echo "⚪️ Папка USB не смонтирована"
/sbin/mount | grep -q Phone-WiFi && echo "🟢 Папка Wi-Fi смонтирована" || echo "⚪️ Папка Wi-Fi не смонтирована"
exit 0
