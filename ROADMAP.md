# Roadmap

## P1 — Reliability

- [ ] **Watchdog / auto-reconnect:** monitor `adb track-devices`; on transport change (USB↔Wi-Fi) or wedged mount — force-unmount and remount without losing pending writes. Currently requires manual reconnect via the tray.
- [ ] **Tray app state machine:** display active transport (USB / Wi-Fi / hotspot / VPN), SSH and adb-forward status, pending write indicator, last error. Unmount should wait for cache flush rather than force by default.
- [ ] **Hotspot mode:** verify mDNS discovery over personal hotspot; add fallback to cached phone IP.
- [ ] **Post-reboot recovery:** verify Termux:Boot reliably starts sshd; handle credential-encrypted storage lock on first boot; handle Wireless Debugging reset → USB as recovery path.

## P2 — Security and longevity

- [ ] Harden sshd: bind to `127.0.0.1` when only `adb forward` is used; separate mount-only key + `PasswordAuthentication no` + `from=<subnet>` in `authorized_keys` for direct VPN access.
- [ ] Battery monitoring: alert when phone temperature is high; reminder about cable quality and ventilation.
- [ ] Document and test external access over router VPN (static DHCP for the phone).

## P3 — Performance

- [ ] Benchmark `--vfs-read-chunk-streams` under USB and Wi-Fi separately to confirm the 4–8 sweet spot.
- [ ] Multithreaded bulk copy mode (`rclone copy --transfers N --multi-thread-streams`) as a separate "turbo transfer" action for large batches.
- [ ] Concurrent-edit refresh: short `--dir-cache-time` or an explicit Refresh button (SFTP has no push notification).

## P4 — Portability and upstream

- [ ] Apple Silicon: arm64 rclone binary + FUSE-T default path (no Reduced Security required).
- [ ] Windows variant: `adb forward` + rclone mount via WinFsp.
- [ ] `setup.sh`: clean-machine test on Apple Silicon.
- [ ] Upstream PRs: ADBFileExplorer (photo preview + Mount menu item), FileDroid (Mount button) — changes are built locally, not yet submitted.

## P4.5 — Tray convenience actions

The adb channel is already open; these require no new infrastructure:

- [ ] **Screen mirror:** tray button launches `scrcpy` (USB preferred for low latency; Wi-Fi via same adb connect).
- [ ] **Screenshot:** `adb exec-out screencap -p` → save to file or clipboard, from the tray.
- [ ] **Screen record:** `scrcpy --record` or `adb shell screenrecord`, from the tray.
- [ ] Quick actions: install APK (`adb install`), clipboard sync (phone↔Mac).

## P5 — Polish

- [ ] Photo preview fallback for images without EXIF thumbnails (full pull + resize); video thumbnail generation.
- [ ] Sign and notarize PhoneStream.app (currently ad-hoc signed — Gatekeeper may warn on first launch).
- [ ] One-click streaming: open video with a single click in ADBFileExplorer (requires Flutter rebuild of FileDroid).
