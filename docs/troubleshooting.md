# Troubleshooting

Kumpulan 11 kasus error umum beserta solusinya. Jika masalahmu tidak ada di sini, cek [referensi dokumentasi resmi](../README.md#referensi).

---

## Daftar Isi

1. [Termux killed saat layar mati](#1-termux-killed-saat-layar-mati)
2. [`pkg update` error "No such file or directory"](#2-pkg-update-error-no-such-file-or-directory)
3. [proot-distro Ubuntu crash](#3-proot-distro-ubuntu-crash)
4. [Nginx gagal start: "Address already in use"](#4-nginx-gagal-start-address-already-in-use)
5. [`apt install` error "dpkg was interrupted"](#5-apt-install-error-dpkg-was-interrupted)
6. [Node.js / npm tidak ditemukan setelah install](#6-nodejs--npm-tidak-ditemukan-setelah-install)
7. [`cloudflared` error "exec format error"](#7-cloudflared-error-exec-format-error)
8. [Tunnel connect tapi URL tidak bisa diakses](#8-tunnel-connect-tapi-url-tidak-bisa-diakses)
9. [Filebrowser "permission denied" pada ~/storage](#9-filebrowser-permission-denied-pada-storage)
10. [pm2 proses hilang setelah restart Ubuntu session](#10-pm2-proses-hilang-setelah-restart-ubuntu-session)
11. [HP overheat](#11-hp-overheat)

---

## 1. Termux killed saat layar mati

**Gejala:** Semua service mati saat layar HP mati atau HP dikunci.

**Solusi:**

```
1. Aktifkan wakelock di notifikasi Termux → "Acquire wakelock"
2. Settings → Apps → Termux → Battery → "Don't optimize"
3. MIUI: Settings → Apps → Termux → Battery saver → No restrictions
4. Samsung: Settings → Device care → Battery → Never sleeping apps → tambah Termux
```

> Lakukan langkah ini setiap kali membuka sesi Termux baru yang akan dipakai sebagai server.

---

## 2. `pkg update` error "No such file or directory"

**Gejala:**
```
E: Unable to fetch some archives, maybe run apt-get update
   or try with --fix-missing?
```

**Solusi:**

```bash
termux-change-repo   # Pilih mirror lain (misalnya Albatross atau mirror terdekat)
pkg update
```

---

## 3. proot-distro Ubuntu crash

**Gejala:** `proot-distro login ubuntu` langsung keluar atau hang tanpa pesan error jelas.

**Solusi:**

```bash
# Coba upgrade dulu
pkg upgrade proot-distro

# Jika masih bermasalah, reinstall Ubuntu
proot-distro remove ubuntu
proot-distro install ubuntu
```

> ⚠️ Reinstall akan menghapus semua data di dalam Ubuntu. Backup konfigurasi penting ke `~/storage` terlebih dahulu.

---

## 4. Nginx gagal start: "Address already in use"

**Gejala:**
```
nginx: [emerg] bind() to 0.0.0.0:80 failed (98: Address already in use)
```

**Solusi:**

```bash
apt install lsof -y
lsof -i :80           # Lihat PID proses yang pakai port 80
kill -9 <PID>         # Ganti <PID> dengan angka dari output di atas
service nginx start
```

---

## 5. `apt install` error "dpkg was interrupted"

**Gejala:**
```
E: dpkg was interrupted, you must manually run
   'dpkg --configure -a' to correct the problem.
```

**Solusi:**

```bash
dpkg --configure -a
apt install -f
```

---

## 6. Node.js / npm tidak ditemukan setelah install

**Gejala:** `node: command not found` atau `npm: command not found` padahal sudah diinstall.

**Solusi:**

```bash
source /etc/profile
```

Jika masih tidak ditemukan, install ulang:

```bash
curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
apt install nodejs -y
```

---

## 7. `cloudflared` error "exec format error"

**Gejala:**
```
bash: /usr/local/bin/cloudflared: cannot execute binary file: Exec format error
```

**Penyebab:** Salah download arsitektur — kemungkinan download `amd64` padahal HP ARM64.

**Solusi:**

```bash
rm /usr/local/bin/cloudflared

# Konfirmasi arsitektur HP
uname -m   # Harus: aarch64

# Download ulang versi yang benar
wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64 \
  -O /usr/local/bin/cloudflared
chmod +x /usr/local/bin/cloudflared

# Verifikasi
cloudflared --version
```

---

## 8. Tunnel connect tapi URL tidak bisa diakses

**Gejala:** `pm2 logs cloudflared` menampilkan "Connection established", tapi URL tetap tidak bisa dibuka.

**Langkah diagnosa:**

```bash
# 1. Tunggu DNS propagate 1–5 menit, cek di dnschecker.org

# 2. Pastikan service lokal berjalan
curl http://localhost:80
curl http://localhost:8080

# 3. Cek isi config.yml
cat ~/.cloudflared/config.yml

# 4. Restart tunnel
pm2 restart cloudflared
```

---

## 9. Filebrowser "permission denied" pada ~/storage

**Gejala:** Filebrowser tidak bisa baca/tulis ke folder `~/storage`.

**Solusi:**

```bash
chmod 755 ~/storage
chown -R root:root ~/storage
pm2 restart filebrowser
```

---

## 10. pm2 proses hilang setelah restart Ubuntu session

**Gejala:** Semua proses pm2 tidak ada setelah menutup dan membuka kembali sesi Ubuntu.

**Solusi — resurrect dari save terakhir:**

```bash
pm2 resurrect
```

**Jika resurrect tidak ada data (belum pernah `pm2 save`):**

```bash
pm2 start ~/apps/my-api/index.js --name my-api
pm2 start "filebrowser --database /root/.filebrowser.db" --name filebrowser
pm2 start "cloudflared tunnel run android-server" --name cloudflared
pm2 save
```

**Opsional — buat startup script untuk kemudahan:**

```bash
nano ~/start-server.sh
```

```bash
#!/bin/bash
service nginx start
pm2 resurrect || {
  pm2 start ~/apps/my-api/index.js --name my-api
  pm2 start "filebrowser --database /root/.filebrowser.db" --name filebrowser
  pm2 start "cloudflared tunnel run android-server" --name cloudflared
  pm2 save
}
echo "✅ Server started. Run 'pm2 list' to verify."
```

```bash
chmod +x ~/start-server.sh
./start-server.sh
```

---

## 11. HP overheat

**Gejala:** HP terasa sangat panas, performa menurun drastis (thermal throttling).

**Diagnosa:**

```bash
htop          # Lihat proses mana yang makan CPU paling banyak
free -h       # Cek penggunaan RAM
```

**Solusi:**

```bash
# Hentikan sementara service yang tidak dipakai
pm2 stop filebrowser   # Jika cloud storage tidak aktif digunakan
```

> Tips jangka panjang: tempatkan HP di lokasi berventilasi baik, hindari ditumpuk atau diletakkan di atas bantal/kasur.

---

[Kembali ke README](../README.md) | [Tips & Best Practices →](./tips-dan-best-practices.md)
