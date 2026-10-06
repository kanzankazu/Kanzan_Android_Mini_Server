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

## 🔒 Security Tips

### Update Sistem Secara Berkala

Jalankan update setiap minggu untuk menutup celah keamanan di package Ubuntu:

```bash
apt update && apt upgrade -y
```

### Nonaktifkan Login Root via Password

Jika SSH diinstall di Ubuntu PRoot (bukan hanya di Termux), pastikan root tidak bisa login via password langsung:

```bash
# Di Ubuntu PRoot — cek sshd_config jika ada
grep "PermitRootLogin" /etc/ssh/sshd_config
# Pastikan nilainya: PermitRootLogin prohibit-password
# Artinya root hanya bisa login via SSH key, bukan password
```

### Nonaktifkan Service yang Tidak Dipakai

Jangan jalankan service yang tidak dibutuhkan — setiap service aktif adalah potensi attack surface:

```bash
# Cek semua service yang berjalan
service --status-all 2>/dev/null | grep ' + '

# Contoh matikan service yang tidak dipakai (sesuaikan)
service bluetooth stop 2>/dev/null || true
```

### Buat User Non-Root untuk Aplikasi (Opsional tapi Direkomendasikan)

Menjalankan aplikasi sebagai root adalah kebiasaan buruk. Buat user terpisah untuk aplikasi:

```bash
# Buat user 'appuser' tanpa password login
useradd -r -s /bin/false appuser

# Jalankan Node.js app sebagai appuser via pm2
# pm2 start index.js --name my-api --user appuser
```

> Di PRoot Android, isolation user tidak sekuat bare metal Linux, tapi tetap merupakan praktik terbaik yang baik untuk dibiasakan.

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
