# Phase 2: Fondasi Server — Nginx + Node.js

> **Durasi estimasi:** 20–30 menit

Install semua tools utama: web server Nginx, runtime Node.js, dan process manager pm2.

---

## Install Nginx

```bash
apt install nginx -y
service nginx start
```

Verifikasi Nginx berjalan:

```bash
curl http://localhost
# Harus muncul halaman welcome Nginx
```

---

## Cek IP HP di Jaringan Lokal

```bash
ip addr show | grep "inet "
```

Catat IP ini — dipakai untuk test akses dari device lain di WiFi yang sama.

---

## Install Node.js LTS

```bash
curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
apt install nodejs -y
```

---

## Install pm2

```bash
npm install -g pm2
```

pm2 adalah process manager yang menjaga service tetap berjalan di background dan auto-restart jika crash.

---

## Verifikasi Instalasi

```bash
node --version
npm --version
pm2 --version
```

---

## Buat Struktur Direktori

```bash
mkdir -p ~/apps/my-api
mkdir -p ~/storage
mkdir -p ~/.cloudflared
```

| Direktori | Fungsi |
|-----------|--------|
| `~/apps/my-api` | Kode aplikasi Node.js / Express |
| `~/storage` | Root folder Filebrowser (cloud storage) |
| `~/.cloudflared` | Konfigurasi tunnel Cloudflare |

---

## 🔒 Security Tips

### Tambah Security Headers di Nginx

Security headers melindungi dari serangan umum seperti clickjacking, XSS, dan MIME sniffing. Tambahkan ke konfigurasi Nginx:

```bash
nano /etc/nginx/conf.d/security-headers.conf
```

Isi file:

```nginx
# Sembunyikan versi Nginx dari response header
server_tokens off;

# Cegah clickjacking
add_header X-Frame-Options "SAMEORIGIN" always;

# Cegah MIME type sniffing
add_header X-Content-Type-Options "nosniff" always;

# Aktifkan XSS filter di browser lama
add_header X-XSS-Protection "1; mode=block" always;

# Paksa HTTPS (aktifkan setelah domain HTTPS jalan di Phase 3-4)
# add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

# Batasi referrer info yang dikirim ke situs lain
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
```

Apply konfigurasi:

```bash
nginx -t && service nginx reload
```

### Batasi Request Rate (Rate Limiting)

Cegah brute force dan DDoS sederhana dengan rate limiting di Nginx:

```bash
nano /etc/nginx/conf.d/rate-limit.conf
```

Isi file:

```nginx
# Buat zone rate limit: 10 MB untuk simpan state, max 10 req/detik per IP
limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;
limit_req_zone $binary_remote_addr zone=login_limit:10m rate=3r/m;
```

Lalu tambahkan di dalam blok `location` di virtual host kamu (Phase 7):

```nginx
location / {
    limit_req zone=api_limit burst=20 nodelay;
    # ... proxy_pass config lainnya
}
```

Apply:

```bash
nginx -t && service nginx reload
```

### Sembunyikan Informasi Server

Pastikan Nginx tidak membocorkan versi dan informasi sistem:

```bash
# Verifikasi server_tokens off sudah aktif
curl -I http://localhost | grep -i server
# Harusnya hanya tampil: Server: nginx (tanpa versi)
```

---

## ✅ Checklist Phase 2

```
[ ] curl http://localhost mengembalikan halaman Nginx
[ ] IP HP di jaringan lokal sudah diketahui
[ ] Node.js, npm, pm2 terinstall
[ ] Direktori ~/apps/my-api dan ~/storage sudah dibuat
```

---

[← Phase 1: Setup Ubuntu](./fase-1-setup-ubuntu.md) | [Kembali ke README](../README.md) | [Phase 3: Expose ke Internet →](./fase-3-expose-internet.md)
