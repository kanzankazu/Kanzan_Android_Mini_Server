# Phase 1: Setup Ubuntu via PRoot

> **Durasi estimasi:** 20–40 menit

PRoot mensimulasikan environment Linux lengkap di atas Android **tanpa akses root**. Performance-nya mendekati native Linux.

---

## Install proot-distro & Ubuntu

```bash
# Di Termux
pkg install proot-distro -y

# Install Ubuntu (~200–400 MB)
proot-distro install ubuntu

# Masuk ke Ubuntu
proot-distro login ubuntu
```

---

## Setup Pertama di Ubuntu

```bash
apt update && apt upgrade -y
apt install curl wget nano git unzip zip htop -y

# Verifikasi (harus muncul "aarch64 GNU/Linux")
uname -a
```

Output yang diharapkan dari `uname -a` mengandung `aarch64 GNU/Linux` — ini memastikan kamu berjalan di arsitektur ARM64 yang benar.

---

## Buat Shortcut

Agar tidak perlu mengetik `proot-distro login ubuntu` setiap saat:

```bash
exit  # Kembali ke Termux dulu
echo "alias ubuntu='proot-distro login ubuntu'" >> ~/.bashrc
source ~/.bashrc
# Selanjutnya cukup ketik: ubuntu
```

---

## ✅ Checklist Phase 1

```
[ ] Ubuntu berhasil diinstall
[ ] apt update && upgrade berhasil di Ubuntu
[ ] uname -a menampilkan "aarch64 GNU/Linux"
[ ] Alias 'ubuntu' sudah dibuat
```

---

[← Phase 0: Persiapan Termux](./fase-0-persiapan-termux.md) | [Kembali ke README](../README.md) | [Phase 2: Fondasi Server →](./fase-2-fondasi-server.md)
