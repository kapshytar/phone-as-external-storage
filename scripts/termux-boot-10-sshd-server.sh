#!/data/data/com.termux/files/usr/bin/sh
# Сервер-режим: sshd при загрузке телефона + адаптивная мощность.
# Полная мощность (wake-lock) ТОЛЬКО когда есть активное подключение; в простое отпускаем — телефон дремлет.
#
# Установка: скопировать в ~/.termux/boot/10-sshd-server.sh на телефоне
# Требует: Termux:Boot из F-Droid, пакеты openssh + termux-tools
sshd
(
  while true; do
    if [ "$(pgrep -x sshd | wc -l)" -gt 1 ]; then
      termux-wake-lock
    else
      termux-wake-unlock
    fi
    sleep 20
  done
) >/dev/null 2>&1 &
