# Roadmap / TODO

Статус: базовое решение РАБОТАЕТ (adbfs-маунт + no-copy rclone-стрим + трей-приложение + out-of-box setup).
Ниже — что доделать. Приоритеты по убыванию.

## P1 — надёжность сервера
- [ ] **Watchdog/reconciler на Mac**: следить за `adb track-devices`, при смене транспорта (USB↔Wi-Fi) или зависшем маунте — force-unmount + remount, не теряя pending-writes. (Сейчас чинится вручную кнопкой Подключить.)
- [ ] **Трей-приложение v2 = state machine**: показывать путь (USB/Wi-Fi/hotspot/VPN), статус ssh/adb-forward/rclone, «есть несохранённые записи», последнюю ошибку. Unmount должен ждать flush, не делать force по умолчанию.
- [ ] **Hotspot-режим**: проверить mDNS-автопоиск поверх точки доступа; добавить fallback по фиксированному IP телефона.
- [ ] **После ребута телефона**: проверить, что Termux:Boot реально поднимает sshd; учесть первый разблок (credential-encrypted storage) и что Wireless Debugging может быть выключен → USB как recovery.

## P2 — безопасность и долговечность
- [ ] Security-профиль: sshd bind `127.0.0.1` (если только adb-forward) ИЛИ отдельный mount-only ключ + `PasswordAuthentication no` + `authorized_keys from=<subnet>` для прямого VPN-доступа.
- [ ] Battery longevity: авто-включать Samsung «защита батареи» 80–85%; мониторинг температуры; напоминание про нормальный кабель/вентиляцию.
- [ ] Внешний доступ через VPN на роутере — документировать и протестировать (статический DHCP телефону).

## P3 — производительность
- [ ] Подобрать `--vfs-read-chunk-streams` (сейчас 8) замерами под USB и Wi-Fi.
- [ ] Многопоточная качалка для bulk-копий (`rclone copy --transfers N --multi-thread-streams`) — отдельный «турбо-перенос» для больших объёмов.
- [ ] Concurrent-edit: короткий `--dir-cache-time` или кнопка Refresh/remount (у SFTP нет push-notify).

## P4 — кроссплатформенность и апстрим
- [ ] Apple Silicon: arm64-бинарь rclone + ветка под FUSE-T (без снижения безопасности для KEXT).
- [ ] Windows-вариант (у юзера есть Windows): adb forward + rclone mount через WinFsp.
- [ ] `setup.sh`: прогон на чистой машине; ветка под Apple Silicon.
- [ ] PR в апстрим: FileDroid (кнопка Mount), ADBFileExplorer (фото-превью + меню Mount) — собрано локально, не отправлено.

## P5 — фичи
- [ ] Фото-превью: fallback для картинок без EXIF-миниатюры (полная тяга + Pillow resize); видео-превью.
- [ ] Подписать/нотаризовать PhoneStream.app (сейчас ad-hoc подпись — при первом запуске может ругаться Gatekeeper).
