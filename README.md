# Kanzan Android Mini Server

Mengubah HP Android bekas (atau yang sedang tidak terpakai) menjadi server sungguhan — bisa diakses dari internet, menjalankan API, bahkan jadi cloud storage pribadi pengganti Google Drive. Semua ini tanpa root, tanpa biaya VPS, dan tanpa port forwarding di router.

Panduan ini membawa kamu dari HP kosong sampai server yang bisa diakses via URL HTTPS resmi dari mana saja di dunia.

---

## 📋 Daftar Isi

- [Cara Kerja & Arsitektur](#cara-kerja--arsitektur) — diagram stack & alur request internet ke HP
- [Perbandingan: HP Android vs Raspberry Pi vs VPS](#perbandingan-hp-android-vs-raspberry-pi-vs-vps) — tabel biaya, performa, use case
- [Hardware yang Direkomendasikan](#hardware-yang-direkomendasikan) — spesifikasi minimum & ideal HP server
- [Phase 0: Persiapan & Install Termux](#-phase-0-persiapan--install-termux) — ±15–30 menit
  - [Kenapa F-Droid, Bukan Play Store?](#kenapa-f-droid-bukan-play-store) — Play Store sudah outdated sejak 2020
  - [Install F-Droid](#install-f-droid) — app store alternatif untuk Termux versi terbaru
  - [Install Termux via F-Droid](#install-termux-via-f-droid) — terminal emulator Linux di Android
  - [Setup Awal Termux](#setup-awal-termux) — pkg update, install paket dasar, setup storage
  - [Aktifkan Wakelock](#aktifkan-wakelock) — wajib agar Termux tidak mati saat layar mati
  - [Nonaktifkan Battery Optimization](#nonaktifkan-battery-optimization) — cegah Android kill Termux di background
  - [Verifikasi Setup](#verifikasi-setup) — cek koneksi internet
- [Phase 1: Setup Ubuntu via PRoot](#-phase-1-setup-ubuntu-via-proot) — ±20–40 menit, install Linux tanpa root
  - [Setup Pertama di Ubuntu](#setup-pertama-di-ubuntu) — apt update, install paket dasar, verifikasi ARM64
  - [Buat Shortcut](#buat-shortcut) — alias `ubuntu` agar tidak ketik perintah panjang
- [Phase 2: Fondasi Server — Nginx + Node.js](#-phase-2-fondasi-server--nginx--nodejs) — ±20–30 menit, install semua tools utama
- [Phase 3: Use Case A — Web Server & API](#-phase-3-use-case-a--web-server--api) — ±30–45 menit, Express.js API dengan pm2
  - [Konfigurasi Nginx](#konfigurasi-nginx) — reverse proxy port 80 → Node.js port 3000
- [Phase 4: Use Case B — Cloud Storage Pribadi](#-phase-4-use-case-b--cloud-storage-pribadi) — ±20–30 menit, Filebrowser self-hosted
  - [Update Nginx untuk Filebrowser](#update-nginx-untuk-filebrowser) — routing `/files` → Filebrowser port 8080
- [Phase 5: Expose ke Internet via Cloudflare Tunnel](#-phase-5-expose-ke-internet-via-cloudflare-tunnel) — ±30–45 menit, HTTPS tanpa port forwarding
  - [Alternatif: Quick Tunnel (Tanpa Domain)](#alternatif-quick-tunnel-tanpa-domain) — URL random untuk testing, tanpa akun Cloudflare
  - [Ringkasan Semua Service](#ringkasan-semua-service) — checklist pm2 list yang diharapkan
- [Troubleshooting](#troubleshooting) — 11 kasus error umum beserta solusinya
  - [Termux killed saat layar mati](#termux-killed-saat-layar-mati) — wakelock & battery optimization
  - [`pkg update` error "No such file or directory"](#pkg-update-error-no-such-file-or-directory) — ganti mirror Termux
  - [proot-distro Ubuntu crash](#proot-distro-ubuntu-crash) — upgrade atau reinstall proot-distro
  - [Nginx gagal start: "Address already in use"](#nginx-gagal-start-address-already-in-use) — kill proses yang pakai port 80
  - [`apt install` error "dpkg was interrupted"](#apt-install-error-dpkg-was-interrupted) — jalankan `dpkg --configure -a`
  - [Node.js / npm tidak ditemukan setelah install](#nodejs--npm-tidak-ditemukan-setelah-install) — source ulang PATH
  - [`cloudflared` error "exec format error"](#cloudflared-error-exec-format-error) — salah download arsitektur (harus ARM64)
  - [Tunnel connect tapi URL tidak bisa diakses](#tunnel-connect-tapi-url-tidak-bisa-diakses) — cek DNS propagation & config.yml
  - [Filebrowser "permission denied" pada ~/storage](#filebrowser-permission-denied-pada-storage) — fix chmod & chown
  - [pm2 proses hilang setelah restart Ubuntu session](#pm2-proses-hilang-setelah-restart-ubuntu-session) — `pm2 resurrect` atau script startup
  - [HP overheat](#hp-overheat) — monitor htop, kurangi service aktif
- [Tips & Best Practices](#tips--best-practices)
  - [Keamanan](#keamanan) — password Filebrowser & Cloudflare Access
  - [Performa & Stabilitas](#performa--stabilitas) — monitor RAM, CPU, storage
  - [Backup Konfigurasi](#backup-konfigurasi) — backup cloudflared, Filebrowser DB, Nginx config
  - [Limitasi yang Perlu Diketahui](#limitasi-yang-perlu-diketahui) — PRoot constraints & workaround
  - [Kapan Lebih Baik Pakai VPS](#kapan-lebih-baik-pakai-vps) — traffic tinggi, uptime kritis, tim besar
- [Referensi](#referensi) — link dokumentasi semua tools yang dipakai

---

## Cara Kerja & Arsitektur

Secara garis besar, stack yang dibangun di panduan ini terlihat seperti ini:

```
Internet
    │
    ▼
[Cloudflare Edge Network]  ← enkripsi TLS, DDoS protection, routing domain
    │
    ▼
[cloudflared daemon]       ← koneksi outbound dari HP, tidak perlu buka port
    │
    ▼
[Ubuntu PRoot]             ← Linux environment lengkap di dalam Termux
    ├── Nginx :80           ← web server / reverse proxy
    │     ├── /             → Node.js API (port 3000)
    │     └── /files        → Filebrowser (port 8080)
    ├── Node.js + Express :3000  ← Use Case A: API / Web Server
    ├── Filebrowser :8080        ← Use Case B: Cloud Storage Pribadi
    └── pm2                      ← process manager, keep services alive
    │
[Termux]                   ← terminal emulator, host untuk Ubuntu PRoot
    │
[HP Android]               ← hardware, charging terus saat jadi server
```

**Alur request dari internet:**
1. User akses `https://api.kamu.com` dari mana saja
2. Request masuk ke Cloudflare Edge → diteruskan via tunnel ke `cloudflared` di HP
3. `cloudflared` forward ke Nginx di port 80
4. Nginx routing ke service yang tepat (Node.js atau Filebrowser)
5. Response balik ke user via jalur yang sama

**Kenapa tidak butuh root atau port forwarding?**
- `cloudflared` membuat koneksi *outbound* dari HP ke Cloudflare — bukan menunggu koneksi masuk
- PRoot mensimulasikan Linux environment tanpa privilege root Android
- Hasilnya: setup yang aman, tidak mengubah sistem Android, dan bisa diuninstall kapan saja

---

## Perbandingan: HP Android vs Raspberry Pi vs VPS

| Kriteria | HP Android Bekas | Raspberry Pi 4 | VPS (entry level) |
|----------|-----------------|----------------|-------------------|
| **Biaya hardware** | Rp 0 (pakai HP bekas) | Rp 500rb–900rb | Rp 0 (sewa) |
| **Biaya operasional** | Listrik ~5–10W | Listrik ~5–8W | Rp 50rb–200rb/bln |
| **Setup complexity** | Mudah (panduan ini) | Sedang | Mudah |
| **Performa** | Cukup (Snapdragon/Dimensity) | Cukup (ARM Cortex-A72) | Bergantung plan |
| **Uptime** | Butuh charging terus | Butuh power supply stabil | 99.9% (managed) |
| **Static IP** | Tidak (via Cloudflare Tunnel) | Tidak (via Cloudflare Tunnel) | Ya |
| **Root diperlukan** | ❌ Tidak | ❌ Tidak (headless) | ❌ Tidak |
| **Cocok untuk** | Belajar, hobby, side project | Hobby, IoT, home server | Produksi, traffic tinggi |
| **Tidak cocok untuk** | Traffic tinggi, uptime kritis | Project yang butuh cloud | Budget sangat terbatas |

> **Kesimpulan:** HP Android bekas adalah pilihan terbaik untuk belajar server, side project, atau proof of concept tanpa keluar biaya bulanan.

---

## Hardware yang Direkomendasikan

| Komponen | Minimum | Direkomendasikan |
|----------|---------|-----------------|
| **RAM** | 4 GB | 6 GB+ |
| **Storage internal** | 32 GB | 64 GB+ |
| **Android version** | Android 7 | Android 10+ |
| **Prosesor** | Octa-core | Snapdragon 7xx / Dimensity 8xxx |
| **Charger** | Bawaan HP | Charger fast charging (HP akan menyala terus) |

> **Tips hardware:**
> - Gunakan HP yang sudah tidak dipakai aktif sebagai dedicated server
> - Lepas SIM card jika tidak dibutuhkan (hemat baterai)
> - Pertimbangkan pasang pendingin kecil atau tempatkan di lokasi berventilasi baik
> - HP dengan baterai sudah menurun justru bagus — bisa dipasang charger terus tanpa khawatir baterai kembung (tapi monitor suhu)

---

## 🚀 Phase 0: Persiapan & Install Termux

> **Durasi estimasi:** 15–30 menit

Termux adalah aplikasi terminal emulator untuk Android yang memungkinkan kamu menjalankan perintah Linux langsung di HP.

### Kenapa F-Droid, Bukan Play Store?

Versi Termux di Play Store sudah **tidak diperbarui sejak 2020** — repository package-nya outdated dan banyak paket tidak bisa diinstall. Wajib download dari F-Droid untuk mendapat versi terbaru.

### Install F-Droid

1. Buka browser di HP, kunjungi [f-droid.org](https://f-droid.org)
2. Download file `.apk` F-Droid
3. Buka file `.apk` → Allow install from unknown sources jika diminta
4. Install F-Droid

### Install Termux via F-Droid

1. Buka F-Droid → Search **"Termux"**
2. Install Termux (developer: **Fredrik Fornwall**)

### Setup Awal Termux

```bash
# Update dan upgrade paket
pkg update && pkg upgrade -y

# Install paket dasar
pkg install wget curl openssh nano git -y

# Setup izin akses storage Android
termux-setup-storage
```

### Aktifkan Wakelock

Geser notification bar → notifikasi **"Termux"** → ketuk **"Acquire wakelock"**

Lakukan ini setiap kali membuka Termux untuk jadi server.

### Nonaktifkan Battery Optimization

Settings → Apps → Termux → Battery → **"Don't optimize"** / **"Unrestricted"**

### Verifikasi Setup

```bash
ping -c 4 8.8.8.8
```

```
Checklist Phase 0:
[ ] Termux terinstall dari F-Droid (bukan Play Store)
[ ] pkg update && upgrade berhasil
[ ] termux-setup-storage berhasil
[ ] Wakelock aktif
[ ] Battery optimization dimatikan
[ ] ping 8.8.8.8 berhasil
```

---

## 🐧 Phase 1: Setup Ubuntu via PRoot

> **Durasi estimasi:** 20–40 menit

PRoot mensimulasikan environment Linux lengkap di atas Android **tanpa akses root**. Performance-nya mendekati native Linux.

```bash
# Di Termux
pkg install proot-distro -y

# Install Ubuntu (~200–400 MB)
proot-distro install ubuntu

# Masuk ke Ubuntu
proot-distro login ubuntu
```

### Setup Pertama di Ubuntu

```bash
apt update && apt upgrade -y
apt install curl wget nano git unzip zip htop -y

# Verifikasi (harus muncul "aarch64 GNU/Linux")
uname -a
```

### Buat Shortcut

```bash
exit  # Kembali ke Termux dulu
echo "alias ubuntu='proot-distro login ubuntu'" >> ~/.bashrc
source ~/.bashrc
# Selanjutnya cukup ketik: ubuntu
```

```
Checklist Phase 1:
[ ] Ubuntu berhasil diinstall
[ ] apt update && upgrade berhasil di Ubuntu
[ ] uname -a menampilkan "aarch64 GNU/Linux"
[ ] Alias 'ubuntu' sudah dibuat
```

---

## 🔧 Phase 2: Fondasi Server — Nginx + Node.js

> **Durasi estimasi:** 20–30 menit

```bash
# Install Nginx
apt install nginx -y
service nginx start

# Cek IP HP di jaringan lokal
ip addr show | grep "inet "

# Install Node.js LTS
curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
apt install nodejs -y

# Install pm2
npm install -g pm2

# Verifikasi
node --version
npm --version
pm2 --version

# Buat struktur direktori
mkdir -p ~/apps/my-api
mkdir -p ~/storage
mkdir -p ~/.cloudflared
```

```
Checklist Phase 2:
[ ] curl http://localhost mengembalikan halaman Nginx
[ ] IP HP di jaringan lokal sudah diketahui
[ ] Node.js, npm, pm2 terinstall
[ ] Direktori ~/apps/my-api dan ~/storage sudah dibuat
```

---

## 🌐 Phase 3: Use Case A — Web Server & API

> **Durasi estimasi:** 30–45 menit

```bash
cd ~/apps/my-api
npm init -y
npm install express
nano index.js
```

Isi `index.js`:

```javascript
const express = require('express');
const os      = require('os');

const app  = express();
const PORT = 3000;

app.use(express.json());

app.get('/', (req, res) => {
  res.json({
    message : 'Hello from Android Server! 🤖',
    server  : 'Node.js + Express on Android',
    time    : new Date().toISOString()
  });
});

app.get('/api/status', (req, res) => {
  const uptimeSecs = process.uptime();
  const hours      = Math.floor(uptimeSecs / 3600);
  const minutes    = Math.floor((uptimeSecs % 3600) / 60);
  const seconds    = Math.floor(uptimeSecs % 60);

  res.json({
    status     : 'online',
    uptime     : `${hours}h ${minutes}m ${seconds}s`,
    memory     : {
      total_mb : Math.round(os.totalmem() / 1024 / 1024),
      free_mb  : Math.round(os.freemem() / 1024 / 1024),
      used_pct : Math.round((1 - os.freemem() / os.totalmem()) * 100)
    },
    cpu        : os.cpus()[0].model,
    platform   : os.platform(),
    arch       : os.arch(),
    node_ver   : process.version,
    timestamp  : new Date().toISOString()
  });
});

app.get('/api/hello/:name', (req, res) => {
  const { name } = req.params;
  res.json({
    message : `Halo, ${name}! Kamu sedang ngobrol sama server yang jalan di HP Android. 👋`,
    from    : 'Android Mini Server'
  });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`[${new Date().toISOString()}] Server berjalan di port ${PORT}`);
});
```

```bash
pm2 start index.js --name my-api
```

### Konfigurasi Nginx

```bash
nano /etc/nginx/sites-available/my-api
```

```nginx
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass         http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header   Host              $host;
        proxy_set_header   X-Real-IP         $remote_addr;
        proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
        proxy_connect_timeout 30s;
        proxy_read_timeout    30s;
    }
}
```

```bash
ln -s /etc/nginx/sites-available/my-api /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t && service nginx reload
```

```
Checklist Phase 3:
[ ] pm2 start my-api → status "online"
[ ] curl http://localhost:3000 mengembalikan JSON
[ ] curl http://localhost (port 80) mengembalikan JSON
[ ] API bisa diakses dari device lain di WiFi yang sama
```

---

## 📁 Phase 4: Use Case B — Cloud Storage Pribadi

> **Durasi estimasi:** 20–30 menit

```bash
# Konfirmasi arsitektur (harus aarch64)
uname -m

# Download Filebrowser untuk Linux ARM64
wget https://github.com/filebrowser/filebrowser/releases/latest/download/linux-arm64-filebrowser.tar.gz
tar -xzf linux-arm64-filebrowser.tar.gz
mv filebrowser /usr/local/bin/filebrowser
chmod +x /usr/local/bin/filebrowser
rm linux-arm64-filebrowser.tar.gz

filebrowser version
```

```bash
# Setup
mkdir -p ~/storage
filebrowser config init --database ~/.filebrowser.db
filebrowser config set \
  --address 0.0.0.0 \
  --port 8080 \
  --root ~/storage \
  --database ~/.filebrowser.db

# Buat user admin (ganti 'passwordku'!)
filebrowser users add admin passwordku \
  --perm.admin \
  --database ~/.filebrowser.db

pm2 start "filebrowser --database /root/.filebrowser.db" --name filebrowser
```

### Update Nginx untuk Filebrowser

```nginx
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass         http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header   Host              $host;
        proxy_set_header   X-Real-IP         $remote_addr;
        proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
        proxy_connect_timeout 30s;
        proxy_read_timeout    30s;
    }

    location /files {
        proxy_pass         http://localhost:8080;
        proxy_http_version 1.1;
        proxy_set_header   Host              $host;
        proxy_set_header   X-Real-IP         $remote_addr;
        proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
        proxy_set_header   Upgrade    $http_upgrade;
        proxy_set_header   Connection "upgrade";
    }
}
```

```bash
# Set base URL Filebrowser
pm2 stop filebrowser
filebrowser config set --baseurl /files --database /root/.filebrowser.db
pm2 start filebrowser
nginx -t && service nginx reload
```

```
Checklist Phase 4:
[ ] filebrowser version tampil tanpa error
[ ] pm2 start filebrowser → status "online"
[ ] Filebrowser bisa diakses dari browser: http://<IP-HP>/files
[ ] Berhasil login, upload, dan download file
```

---

## ☁️ Phase 5: Expose ke Internet via Cloudflare Tunnel

> **Durasi estimasi:** 30–45 menit

**Prasyarat:**
- Akun Cloudflare gratis ([cloudflare.com](https://cloudflare.com))
- Domain yang di-manage Cloudflare

```bash
# Download cloudflared untuk ARM64 (JANGAN download amd64!)
wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64 \
  -O /usr/local/bin/cloudflared
chmod +x /usr/local/bin/cloudflared
cloudflared --version

# Login (buka URL di browser, pilih domain, klik Authorize)
cloudflared tunnel login

# Buat tunnel
cloudflared tunnel create android-server

# Buat config
nano ~/.cloudflared/config.yml
```

```yaml
tunnel: <TUNNEL_ID>
credentials-file: /root/.cloudflared/<TUNNEL_ID>.json

loglevel: info

ingress:
  - hostname: api.domain.com
    service: http://localhost:80
  - hostname: files.domain.com
    service: http://localhost:8080
  - service: http_status:404
```

```bash
# Daftarkan DNS
cloudflared tunnel route dns android-server api.domain.com
cloudflared tunnel route dns android-server files.domain.com

# Jalankan tunnel
pm2 start "cloudflared tunnel run android-server" --name cloudflared
pm2 save

# Verifikasi — cari "Connection established"
pm2 logs cloudflared
```

### Alternatif: Quick Tunnel (Tanpa Domain)

```bash
pm2 start "cloudflared tunnel --url http://localhost:80" --name cloudflared-quick
pm2 logs cloudflared-quick
# Cari: "https://random-name-abc123.trycloudflare.com"
```

### Ringkasan Semua Service

```bash
pm2 list
# my-api      → online
# filebrowser → online
# cloudflared → online
```

```
Checklist Phase 5:
[ ] cloudflared --version tampil tanpa error
[ ] cloudflared tunnel login berhasil (cert.pem ada di ~/.cloudflared/)
[ ] Tunnel 'android-server' berhasil dibuat
[ ] config.yml sudah dibuat dengan TUNNEL_ID yang benar
[ ] pm2 logs cloudflared menampilkan "Connection established"
[ ] https://api.domain.com bisa diakses dari data seluler
[ ] pm2 save sudah dijalankan
```

---

## 🔍 Troubleshooting

### Termux killed saat layar mati

```
1. Aktifkan wakelock di notifikasi Termux → "Acquire wakelock"
2. Settings → Apps → Termux → Battery → "Don't optimize"
3. MIUI: Settings → Apps → Termux → Battery saver → No restrictions
4. Samsung: Settings → Device care → Battery → Never sleeping apps → tambah Termux
```

### `pkg update` error "No such file or directory"

```bash
termux-change-repo   # Pilih mirror lain
pkg update
```

### proot-distro Ubuntu crash

```bash
pkg upgrade proot-distro
# Jika masih bermasalah:
proot-distro remove ubuntu
proot-distro install ubuntu
```

### Nginx gagal start: "Address already in use"

```bash
apt install lsof -y
lsof -i :80
kill -9 <PID>
service nginx start
```

### `apt install` error "dpkg was interrupted"

```bash
dpkg --configure -a
apt install -f
```

### Node.js / npm tidak ditemukan setelah install

```bash
source /etc/profile
# Jika masih tidak ada:
curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
apt install nodejs -y
```

### `cloudflared` error "exec format error"

```bash
rm /usr/local/bin/cloudflared
uname -m   # Harus: aarch64
wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64 \
  -O /usr/local/bin/cloudflared
chmod +x /usr/local/bin/cloudflared
```

### Tunnel connect tapi URL tidak bisa diakses

```bash
# Tunggu DNS propagate 1–5 menit lalu cek di dnschecker.org
curl http://localhost:80
curl http://localhost:8080
cat ~/.cloudflared/config.yml
pm2 restart cloudflared
```

### Filebrowser "permission denied" pada ~/storage

```bash
chmod 755 ~/storage
chown -R root:root ~/storage
pm2 restart filebrowser
```

### pm2 proses hilang setelah restart Ubuntu session

```bash
pm2 resurrect
# Jika resurrect tidak ada data:
pm2 start ~/apps/my-api/index.js --name my-api
pm2 start "filebrowser --database /root/.filebrowser.db" --name filebrowser
pm2 start "cloudflared tunnel run android-server" --name cloudflared
pm2 save
```

Script startup (opsional):

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

### HP overheat

```bash
htop
free -h
pm2 stop filebrowser   # Stop service yang tidak dipakai sementara
```

---

## 💡 Tips & Best Practices

### Keamanan

- **Ganti password Filebrowser segera** setelah setup pertama
- **Gunakan Cloudflare Access** untuk proteksi tambahan (gratis untuk 1 user):
  ```
  Cloudflare Dashboard → Zero Trust → Access → Applications
  → Add application → Self-hosted → Domain: files.domain.com
  → Policy: allow email = kamu@email.com
  ```
- Jangan simpan file sangat sensitif di `~/storage` tanpa enkripsi

### Performa & Stabilitas

```bash
free -h    # Monitor RAM
htop       # Monitor CPU
df -h      # Monitor storage
```

RAM total untuk semua service (Nginx + Node.js + Filebrowser + cloudflared): ~150–300 MB.

### Backup Konfigurasi

```bash
mkdir -p ~/storage/backup-config
cp -r ~/.cloudflared ~/storage/backup-config/
cp ~/.filebrowser.db ~/storage/backup-config/
cp -r /etc/nginx/sites-available ~/storage/backup-config/
cp -r ~/apps ~/storage/backup-config/
```

### Limitasi yang Perlu Diketahui

| Limitasi | Detail | Workaround |
|----------|--------|------------|
| **Port < 1024** | PRoot tidak bisa bind langsung ke port 80/443 | Nginx di port 8000+, atau gunakan `authbind` |
| **systemd tidak penuh** | Service management terbatas di PRoot | Gunakan `service` atau `pm2` |
| **pm2 tidak persistent** | State hilang jika Ubuntu session ditutup | `pm2 save` + `pm2 resurrect` / script startup |
| **Thermal throttling** | Load tinggi = panas = performa turun | Monitor suhu, kurangi service jika overheat |
| **Performa I/O** | Storage HP lebih lambat dari SSD server | Cukup untuk side project, bukan high-traffic production |

### Kapan Lebih Baik Pakai VPS

- Traffic tinggi atau uptime 99.9% dibutuhkan
- Static IP diperlukan
- Tim development yang perlu akses bersama
- Database besar dengan I/O intensif

---

## Referensi

- [F-Droid](https://f-droid.org) — App store untuk Termux
- [Termux Wiki](https://wiki.termux.com) — Dokumentasi resmi
- [proot-distro GitHub](https://github.com/termux/proot-distro)
- [Nginx Documentation](https://nginx.org/en/docs/)
- [Node.js via NodeSource](https://github.com/nodesource/distributions)
- [pm2 Documentation](https://pm2.keymetrics.io/docs/)
- [Filebrowser GitHub Releases](https://github.com/filebrowser/filebrowser/releases) — Download binary ARM64
- [cloudflared GitHub Releases](https://github.com/cloudflare/cloudflared/releases) — Download binary ARM64
- [Cloudflare Tunnel Documentation](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/)
- [Cloudflare Zero Trust Access](https://developers.cloudflare.com/cloudflare-one/applications/)

---

## License

MIT License — see [LICENSE](LICENSE) for details.

## Contributing

Lihat [CONTRIBUTING.md](.github/CONTRIBUTING.md) untuk panduan kontribusi.

---

*Last Updated: Oktober 2026*
