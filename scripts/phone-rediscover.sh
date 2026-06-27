#!/bin/bash
# Ручной «rediscover»: пересканировать mDNS, переподхватить Wi-Fi adb, поднять упавшие тома.
# Не трогает уже рабочие тома (phone-mount-all идемпотентен).
set -u
ADB="$HOME/Library/Android/sdk/platform-tools/adb"
DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Rediscover: сканирую mDNS…"
"$ADB" mdns services >/dev/null 2>&1; sleep 1   # прогрев (первый вызов часто пустой)
EP=$("$ADB" mdns services 2>/dev/null | awk '/_adb-tls-connect._tcp/{print $NF; exit}')
if [ -n "$EP" ]; then
  echo "Wi-Fi найден: $EP — подключаю"
  "$ADB" connect "$EP" >/dev/null 2>&1
else
  echo "Wi-Fi (Wireless Debugging) не виден. Проверь: WD включён на телефоне + на Mac разрешён Local Network."
fi

echo "Поднимаю доступные тома…"
bash "$DIR/phone-mount-all.sh"
