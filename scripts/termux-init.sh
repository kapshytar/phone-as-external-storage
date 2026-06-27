#!/data/data/com.termux/files/usr/bin/bash
# Первичная инициализация телефона-сервера ОДНОЙ командой (запускать В Termux).
# Ставит openssh, настраивает доступ к памяти, sshd, ручной стартер, виджет-кнопку,
# и автозапуск (Termux:Boot, адаптивный wake-lock). Идемпотентно.
set -e
echo "==> Установка openssh…"
pkg install -y openssh >/dev/null

echo "==> Доступ к памяти (разреши во всплывающем окне!)…"
termux-setup-storage || true
sleep 2

echo "==> Ручной стартер ~/sshd-on.sh…"
cat > ~/sshd-on.sh <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
termux-wake-lock
sshd
echo "sshd запущен (порт 8022). Можно сворачивать Termux."
SH
chmod +x ~/sshd-on.sh

echo "==> Кнопка для Termux:Widget…"
mkdir -p ~/.shortcuts
cp ~/sshd-on.sh ~/.shortcuts/Start-SSHD.sh
chmod +x ~/.shortcuts/Start-SSHD.sh

echo "==> Автозапуск сервера (Termux:Boot) + адаптивный wake-lock…"
mkdir -p ~/.termux/boot
cat > ~/.termux/boot/10-sshd-server.sh <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
sshd
( while true; do
    if [ "$(pgrep -x sshd | wc -l)" -gt 1 ]; then termux-wake-lock; else termux-wake-unlock; fi
    sleep 20
  done ) >/dev/null 2>&1 &
SH
chmod +x ~/.termux/boot/10-sshd-server.sh

echo "==> Запуск sshd…"
sshd

echo ""
echo "================ ГОТОВО ================"
echo " username для Mac:  $(whoami)"
echo " порт sshd:         8022"
echo " Не забудь поставить аддоны из F-Droid: Termux:Boot, Termux:Widget (один раз открыть)."
echo " Дальше на Mac: ./setup.sh (введёт username выше) или приложение PhoneStream."
echo "========================================"
