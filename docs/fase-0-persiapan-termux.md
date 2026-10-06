# Phase 0: Persiapan & Install Termux

> **Durasi estimasi:** 15–30 menit

Termux adalah aplikasi terminal emulator untuk Android yang memungkinkan kamu menjalankan perintah Linux langsung di HP.

---

## Kenapa F-Droid, Bukan Play Store?

Versi Termux di Play Store sudah **tidak diperbarui sejak 2020** — repository package-nya outdated dan banyak paket tidak bisa diinstall. Wajib download dari F-Droid untuk mendapat versi terbaru.

---

## Install F-Droid

1. Buka browser di HP, kunjungi [f-droid.org](https://f-droid.org)
2. Download file `.apk` F-Droid
3. Buka file `.apk` → Allow install from unknown sources jika diminta
4. Install F-Droid

---

## Install Termux via F-Droid

1. Buka F-Droid → Search **"Termux"**
2. Install Termux (developer: **Fredrik Fornwall**)

---

## Setup Awal Termux

```bash
# Update dan upgrade paket
pkg update && pkg upgrade -y

# Install paket dasar
pkg install wget curl openssh nano git -y

# Setup izin akses storage Android
termux-setup-storage
```

---

## Aktifkan Wakelock

Geser notification bar → notifikasi **"Termux"** → ketuk **"Acquire wakelock"**

Lakukan ini setiap kali membuka Termux untuk jadi server.

---

## Nonaktifkan Battery Optimization

Settings → Apps → Termux → Battery → **"Don't optimize"** / **"Unrestricted"**

Untuk beberapa vendor:
- **MIUI (Xiaomi):** Settings → Apps → Termux → Battery saver → No restrictions
- **Samsung:** Settings → Device care → Battery → Never sleeping apps → tambah Termux

---

## Verifikasi Setup

```bash
ping -c 4 8.8.8.8
```

---

## 🔒 Security Tips

### Aktifkan Screen Lock di HP

HP yang jadi server tetap harus terkunci jika ada yang pegang secara fisik:

- Settings → **Security** → Screen lock → PIN atau Password (bukan swipe)
- Aktifkan juga **USB debugging** hanya saat dibutuhkan, matikan kembali setelahnya

### Batasi Permission Storage Termux

Termux hanya perlu akses storage untuk operasi file — jangan beri izin lain yang tidak perlu:

- Settings → Apps → Termux → Permissions → izinkan **Storage** saja
- Jangan izinkan akses kontak, kamera, atau mikrofon

### Jangan Install Termux dari Sumber Tidak Dikenal

Hanya install Termux dari **F-Droid resmi** (`f-droid.org`). Versi dari sumber lain bisa dimodifikasi dan menjadi pintu masuk backdoor.

### Amankan SSH Termux Sejak Awal

Jika kamu berencana menginstall SSH (Phase 5), lakukan ini sekarang:

```bash
# Pastikan authorized_keys sudah ada sebelum expose ke internet
mkdir -p ~/.ssh
chmod 700 ~/.ssh
touch ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

---

## ✅ Checklist Phase 0

```
[ ] Termux terinstall dari F-Droid (bukan Play Store)
[ ] pkg update && upgrade berhasil
[ ] termux-setup-storage berhasil
[ ] Wakelock aktif
[ ] Battery optimization dimatikan
[ ] ping 8.8.8.8 berhasil
```

---

[Kembali ke README](../README.md) | [Phase 1: Setup Ubuntu →](./fase-1-setup-ubuntu.md)
