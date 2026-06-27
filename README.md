# Phone as External Storage

> Mount your old Android phone as a macOS Finder volume — **free, open-source, no copying required**.

## The Problem

- Android killed USB Mass Storage years ago
- Google abandoned Android File Transfer (crashes on macOS 13+)
- MTP is slow, buggy, and unreliable
- MacDroid / Commander One cost money and are closed-source
- No free OSS solution that mounts phone as a real Finder volume with no-copy access on macOS

## Quick Start

```bash
git clone https://github.com/kapshytar/phone-as-external-storage
cd phone-as-external-storage
./setup.sh
```

The wizard walks through every step interactively, installs dependencies, configures SSH keys, rclone remote, and creates Desktop launchers. Safe to re-run — already-done steps are skipped.

**What you need before running:**
- macOS Intel (Apple Silicon support: swap `osx-amd64` → `osx-arm64` in setup.sh)
- Homebrew at `/usr/local`
- An Android phone with a USB cable

## What This Does

Two mount stacks, both no-copy:

### Stream Mode (rclone + Termux sshd) — recommended for video/large files
```
macOS ← rclone/sftp ← adb forward tcp:8022 ← Termux sshd ← Android
```
- True no-copy streaming: files never leave the phone
- Multi-threaded reads (16 streams, 8 MB chunks)
- Works over USB (fast) or Wi-Fi via Wireless Debugging (mDNS)
- Mount point: `~/PhoneStream`

### FUSE Mode (adbfs + macFUSE) — recommended for Finder integration / EXIF thumbnails
```
macOS ← macFUSE ← adbfs-rootless (patched) ← ADB ← Android
```
- Full FUSE volume in Finder (`~/Phone`, auto-detects SD card → `~/Phone-SD`)
- Photo thumbnails with EXIF, Spotlight, file tags
- One-command mount/unmount
- Auto-mount on USB connect via launchd agent
- Note: adbfs copies to /tmp on file open — for true streaming use Stream Mode above

## Architecture

```
                   Stream Mode (rclone)
┌──────────┐      ┌─────────────────────────────────────────────┐
│  Finder  │      │  rclone mount (no-copy, multi-stream)       │
│ ~/Phone  │      │     sftp ← adb forward tcp:8022             │
│ Stream   │◄─────│         ← Termux sshd (port 8022)           │
└──────────┘      │              ← Android phone                │
                  └─────────────────────────────────────────────┘

                   FUSE Mode (adbfs)
┌──────────┐      ┌─────────────────────────────────────────────┐
│  Finder  │      │  macFUSE ← adbfs-rootless (ADBFS_ROOT env) │
│  ~/Phone │◄─────│         ← ADB over USB / Wi-Fi              │
│  ~/Phone-│      │              ← Android phone                │
│  SD      │      └─────────────────────────────────────────────┘
└──────────┘
```

**Key components:**
- **[macFUSE](https://macfuse.github.io)** — kernel FUSE driver for macOS
- **[adbfs-rootless](https://github.com/spion/adbfs-rootless)** (GPLv3, upstream) — FUSE filesystem over ADB. We apply `patch/adbfs-root-env.patch` to add `ADBFS_ROOT` env var support
- **[rclone](https://rclone.org)** (MIT) — multi-threaded sftp mount
- **Termux** (F-Droid) — Linux environment on Android, provides openssh/sshd

## Installation (manual, without wizard)

### Stream Mode (rclone + Termux)

#### 1. Install rclone (official binary — Homebrew build cannot mount)

```bash
curl -fsSL https://downloads.rclone.org/rclone-current-osx-amd64.zip -o /tmp/rclone.zip
unzip /tmp/rclone.zip -d /tmp/rclone_tmp
sudo install -m 755 /tmp/rclone_tmp/*/rclone /usr/local/bin/rclone
sudo xattr -d com.apple.quarantine /usr/local/bin/rclone
```

#### 2. Install Termux on phone + sshd

1. Install Termux from **F-Droid** (not Play Store)
2. In Termux:
   ```
   pkg update -y && pkg install -y openssh
   termux-setup-storage    # Allow storage access when prompted!
   sshd
   passwd                  # Set a password (needed once to copy the key)
   ```

#### 3. Enable Wireless Debugging or connect USB

- **USB**: Settings → Developer Options → USB Debugging → ON
- **Wi-Fi**: Settings → Developer Options → Wireless Debugging → ON
  (Samsung Knox blocks the old `adb tcpip 5555` — only Wireless Debugging works)

#### 4. Configure SSH key

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_phone -N ""
adb forward tcp:8022 tcp:8022
ssh-copy-id -i ~/.ssh/id_ed25519_phone.pub -p 8022 127.0.0.1
```

#### 5. Configure rclone remote

```bash
# Replace u0_a520 with your actual Termux username (run `whoami` in Termux)
rclone config create phone sftp \
  host 127.0.0.1 port 8022 \
  user u0_a520 \
  key_file ~/.ssh/id_ed25519_phone \
  known_hosts_file /dev/null
```

#### 6. Mount

```bash
./scripts/phone-stream-up.sh
# or use the Desktop launcher created by setup.sh
```

---

### FUSE Mode (adbfs + macFUSE)

#### 1. Install macFUSE

```bash
brew install --cask macfuse
# Then: System Settings → Privacy & Security → allow macFUSE → REBOOT
```

#### 2. Install ADB

```bash
brew install --cask android-platform-tools
```

#### 3. Build adbfs-rootless (patched)

```bash
git clone https://github.com/spion/adbfs-rootless
cd adbfs-rootless
git checkout 277c088
git apply /path/to/patch/adbfs-root-env.patch
make
# Put adbfs somewhere accessible, e.g. ~/bin/adbfs
```

#### 4. Mount

```bash
./scripts/mount-phone.sh
```

## Usage

```bash
# Stream Mode (rclone + Termux sshd)
./scripts/phone-stream-up.sh      # mount → ~/PhoneStream
./scripts/phone-stream-down.sh    # unmount

# FUSE Mode (adbfs + macFUSE)
./scripts/mount-phone.sh          # ~/Phone + ~/Phone-SD if SD card present
./scripts/mount-phone.sh -s SERIAL_NUMBER   # specific device
./scripts/mount-phone.sh system   # full system root → ~/Phone-System
./scripts/unmount-phone.sh        # unmount all phone volumes

# Power management
./scripts/phone-restrict.sh lift     # disable Doze/throttling while working
./scripts/phone-restrict.sh restore  # re-enable when done
```

### Auto-mount on USB connect (FUSE Mode)

```bash
cd scripts/launchd
./install.sh   # registers com.kapshytar.adbfs-phone LaunchAgent
```

Starts at login, waits 30s for USB Android device, mounts to `~/Phone`. Restarts automatically if adbfs crashes.

```bash
./uninstall.sh   # to remove
```

### phone-restrict.sh — battery-friendly power management

`mount-phone.sh` automatically calls `phone-restrict.sh lift` which:
- Keeps Wi-Fi active (disables sleep policy)
- Disables Wi-Fi scan throttling
- Disables Doze mode
- Raises phantom process limit

`unmount-phone.sh` calls `phone-restrict.sh restore` to return original values.

## Dark Mode (phone as silent server)

Run the phone as a headless server — screen stays off, no indicator lights nagging you:

```bash
# Screen never turns on while charging
adb shell settings put global stay_on_while_plugged_in 0

# Adaptive wake-lock: full CPU only when SSH connection is active, sleep otherwise
# (handled automatically by scripts/termux-boot-10-sshd-server.sh)
```

The script `scripts/termux-boot-10-sshd-server.sh` polls `pgrep sshd` every 20 seconds:
- Active SSH session → `termux-wake-lock` (partial, keeps CPU, screen stays off)
- No session → `termux-wake-unlock` (phone can deep-sleep)

## Server Mode (sshd auto-start on phone boot)

Survive phone reboots without touching Termux:

1. Install **Termux:Boot** from F-Droid
2. Open Termux:Boot at least once (registers the boot hook)
3. In Termux:

```bash
mkdir -p ~/.termux/boot
cp /path/to/scripts/termux-boot-10-sshd-server.sh ~/.termux/boot/10-sshd-server.sh
chmod +x ~/.termux/boot/10-sshd-server.sh
```

After every phone reboot, sshd starts automatically. Combined with Dark Mode the phone works as a silent NAS-style storage server.

## Real-World Speed

| Method | Speed | Notes |
|--------|-------|-------|
| USB 3 + adbfs (FUSE Mode) | ~175 MB/s | Best for large transfers, Finder integration |
| USB + rclone/sftp (Stream Mode) | ~110–140 MB/s | True no-copy, best for video streaming |
| Wi-Fi 5GHz | ~20–40 MB/s | Limited by Android power-saving latency, not radio ceiling |
| MTP over USB | ~5–15 MB/s | Built-in macOS/Android, slow and glitchy |

Use USB for anything serious. Wi-Fi adds latency because Android's Wi-Fi chip aggressively power-saves between packets.

## ✅ Compatibility / Requirements

### Phone (Android)

| Feature | Requirement | Notes |
|---------|-------------|-------|
| Termux (sshd, Stream Mode) | Android **7.0+** | Termux minimum requirement |
| USB transport (adb forward) | Any Android with USB Debugging | Works on all brands |
| Wi-Fi / Wireless Debugging (mDNS auto-discovery) | **Android 11+** recommended | On older Android: USB only, or legacy `adb tcpip` (not reliable) |
| Samsung devices | Wi-Fi: Wireless Debugging only | Knox blocks legacy `adb tcpip 5555` → use Wireless Debugging or USB |
| Termux:Boot (auto-start sshd) | Optional | Install from F-Droid |
| Termux:Widget | Optional | Install from F-Droid |

**Install Termux from [F-Droid](https://f-droid.org), not the Play Store** — the Play Store build is outdated.

Tested on: **Samsung Galaxy S10+ (Android 12)**. Any Android brand works; Samsung-specific caveats are noted above.

### Mac (macOS)

| Component | Requirement | Notes |
|-----------|-------------|-------|
| macOS | **11 Big Sur+** | |
| rclone binary (included) | Intel `osx-amd64` | Apple Silicon: swap to `osx-arm64` binary in `setup.sh` |
| macFUSE | Requires kext approval + **reboot** | System Settings → Privacy & Security → allow → reboot |
| macFUSE on Apple Silicon | Needs lowered security in Recovery for KEXT | Alternative: [FUSE-T](https://www.fuse-t.org) (no kext required) |

---

## 🛡️ Hardening & Longevity (for always-on server use)

### rclone / VFS cache

- **`--vfs-cache-mode writes`** (used by default) — enables full write-back caching; required for writes to work correctly. `minimal` mode does **not** support writes.
- **`--vfs-cache-mode full`** — only needed if apps require random-seek access or in-place editing (e.g. SQLite databases). Has higher local disk usage.
- **`--vfs-read-chunk-streams 8`** (currently set to 8) — sweet spot is 4–8 parallel streams. Higher values can saturate phone CPU or flash I/O without improving speed.

### Security

- **SSH over adb forward (recommended):** keep `sshd` bound to `127.0.0.1` — accessible only through `adb forward tcp:8022`, invisible to the network. No open port, no exposure.
- **SSH over direct LAN/VPN access:** use a dedicated SSH key for mount only, set `PasswordAuthentication no`, restrict the user, and add `from=<LAN/VPN subnet>` in `~/.ssh/authorized_keys` on the phone.
- **Wireless Debugging:** enable only on trusted (home/VPN) networks. Disable when not in use.

### Android power & process management

- In Android Settings: set **Battery → Termux → Unrestricted** and allow autostart for Termux and Termux:Boot. Without this, Android may kill the sshd process.
- **Phantom process killer** (Android 12+): disable via `adb shell device_config put activity_manager max_phantom_processes 2147483647` — `phone-restrict.sh lift` does this automatically.
- After a phone reboot: the screen must be unlocked once (credential-encrypted storage is locked at boot). Wireless Debugging may also reset → keep a USB cable as a recovery path.

### Physical / hardware

- For permanent charging: enable **battery charge limit at 80–85%** (Samsung: *Settings → Battery → Protect battery*). Continuous 100% charging degrades the battery and risks swelling.
- Use a quality cable and ensure adequate ventilation around the phone.

### Write durability

- rclone write-back cache flushes after ~5 seconds. **Do not unplug the cable or put the Mac to sleep immediately after copying large files** — data may still be uploading to the phone.
- A hung mount is recovered automatically: `phone-stream-up.sh` performs force-unmount + remount if needed.

### Known limitation: concurrent edits

SFTP has no push-notification protocol. If a file is modified from the phone while the FUSE mount is active, the Mac may not see the change immediately. Remount to force a refresh.

---

## Known Gotchas

- **adbfs copies to /tmp on open**: when any app opens a file via FUSE, adbfs pulls it to a local temp location. For true no-copy streaming (e.g. playing a video directly off phone) use Stream Mode (rclone/sftp)
- **Wi-Fi ADB is not `adb tcpip 5555`**: modern Android uses *Wireless Debugging* (Settings → Developer Options → Wireless Debugging) with a dynamically assigned port. The old `adb connect ip:5555` is deprecated on Android 11+ and blocked by Samsung Knox
- **macFUSE requires kext approval + reboot**: after installing macFUSE, go to System Settings → Privacy & Security → allow the kernel extension, then reboot. Skipping this = `mount: failed`
- **rclone from Homebrew cannot mount**: the Homebrew build of rclone is compiled without macFUSE support. Use the official binary from downloads.rclone.org — `setup.sh` handles this automatically
- **Termux from Play Store may be outdated**: always install Termux from F-Droid for the latest packages
- **termux-setup-storage is mandatory**: without it, `~/storage/shared` points to an inaccessible path and rclone sees an empty directory
- **Multiple devices**: set `ANDROID_SERIAL` env var to target a specific device when multiple are connected
- **SD card auto-detection**: `mount-phone.sh` detects external SD cards by listing `/storage/` and looking for `XXXX-XXXX` formatted directory names

## Scripts Reference

| Script | Description |
|--------|-------------|
| `setup.sh` | Interactive wizard — install everything, configure from scratch |
| `scripts/phone-stream-up.sh` | Mount via rclone/sftp (Stream Mode) |
| `scripts/phone-stream-down.sh` | Unmount Stream Mode + remove port forward |
| `scripts/mount-phone.sh` | Mount via adbfs/macFUSE (FUSE Mode) |
| `scripts/unmount-phone.sh` | Unmount all phone volumes (both modes) |
| `scripts/phone-restrict.sh` | Android power management (lift/restore) |
| `scripts/termux-boot-10-sshd-server.sh` | Termux:Boot script — sshd + adaptive wake-lock |
| `scripts/launchd/install.sh` | Install launchd auto-mount agent (FUSE Mode) |
| `scripts/launchd/uninstall.sh` | Remove launchd agent |

## patch/adbfs-root-env.patch

The upstream `adbfs-rootless` exposes the entire Android filesystem root via FUSE. This patch adds:

1. `g_root` global string — optional device-side path prefix
2. `remap_path()` helper — prepends `g_root` to every FUSE path operation
3. `ADBFS_ROOT` env var support in `main()` — if set, initializes `g_root`

This lets you mount `/storage/emulated/0` directly as the FUSE root, so Finder shows your photos/music/documents without navigating deep into the Android filesystem tree.

Apply to upstream commit `277c088` (Implements utimens touch dates):

```bash
git clone https://github.com/spion/adbfs-rootless
cd adbfs-rootless
git checkout 277c088
git apply /path/to/patch/adbfs-root-env.patch
make
```

## Credits

Standing on the shoulders of giants:

| Project | License | Link |
|---------|---------|------|
| macFUSE | BSD + FUSE | https://macfuse.github.io |
| adbfs-rootless | **GPLv3** | https://github.com/spion/adbfs-rootless |
| ADBFileExplorer | **GPLv3** | https://github.com/Aldeshov/ADBFileExplorer |
| FileDroid | — | https://github.com/andrisasuke/filedroid |
| rclone | MIT | https://rclone.org |
| Termux | GPL/MIT | https://termux.dev |

**Our scripts** (`setup.sh`, `scripts/`) are released under the **MIT License**.

> The `adbfs` binary is **GPLv3** (upstream). This repo provides a patch only — build it yourself from the upstream source. Do not redistribute the binary.

## License

MIT License — see [LICENSE](LICENSE).

> adbfs-rootless (upstream) remains GPLv3. Build separately and apply `patch/adbfs-root-env.patch`.
