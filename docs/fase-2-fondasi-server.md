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

## ✅ Checklist Phase 2

```
[ ] curl http://localhost mengembalikan halaman Nginx
[ ] IP HP di jaringan lokal sudah diketahui
[ ] Node.js, npm, pm2 terinstall
[ ] Direktori ~/apps/my-api dan ~/storage sudah dibuat
```

---

[← Phase 1: Setup Ubuntu](./fase-1-setup-ubuntu.md) | [Kembali ke README](../README.md) | [Phase 3: Web Server & API →](./fase-3-web-server-api.md)
