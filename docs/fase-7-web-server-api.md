# Phase 7: Use Case A — Web Server & API

> **Durasi estimasi:** 30–60 menit (tergantung framework yang dipilih)

Membuat API yang berjalan di HP Android, dikelola via pm2, dan di-proxy oleh Nginx.

Halaman ini membantu kamu memilih framework yang paling sesuai. Konfigurasi Nginx dan langkah pm2 berlaku untuk semua pilihan.

---

## Pilih Framework

| | [Node.js + Express](./api-express.md) | [Go + Gin](./api-gin.md) | [Python + FastAPI](./api-fastapi.md) |
|--|--------------------------------------|--------------------------|--------------------------------------|
| **RAM usage** | ~50–80 MB | ~10–20 MB | ~60–100 MB |
| **Performa** | Sedang | Tinggi | Sedang–Tinggi |
| **Startup time** | ~1–2 detik | <0.1 detik | ~2–3 detik |
| **Binary/dependency size** | ~200 MB (node_modules) | ~15 MB (single binary) | ~100 MB (venv) |
| **Sudah terinstall** | ✅ Node.js ada di Phase 2 | ❌ Perlu install Go | ❌ Perlu install Python |
| **Kemudahan** | ⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Cocok untuk** | Prototyping, JS developer | Performa, RAM terbatas | Python developer, ML/AI |

> **Rekomendasi:** Kalau baru mulai → pakai **Express** (Node.js sudah ada). Kalau RAM jadi perhatian → **Gin**. Kalau familiar Python atau butuh integrasi AI/ML → **FastAPI**.

---

## Pilih dan Mulai

- **[→ Node.js + Express](./api-express.md)** — Default, Node.js sudah terinstall di Phase 2
- **[→ Go + Gin](./api-gin.md)** — Performa terbaik, single binary, RAM paling hemat
- **[→ Python + FastAPI](./api-fastapi.md)** — Paling mudah, auto docs, cocok untuk AI/ML

---

## Konfigurasi Nginx (Sama untuk Semua Framework)

Semua framework di atas berjalan di port 3000. Konfigurasi Nginx berikut berlaku untuk semuanya:

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

Aktifkan konfigurasi:

```bash
ln -s /etc/nginx/sites-available/my-api /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t && service nginx reload
```

---

## 🔒 Security Tips (Berlaku untuk Semua Framework)

### Nginx Rate Limiting

Tambahkan rate limiting di level Nginx sebagai lapisan pertama pertahanan:

```bash
# Sudah dikonfigurasi di Phase 2 jika mengikuti security tips
# Pastikan zone limit_req_zone aktif di /etc/nginx/conf.d/rate-limit.conf

# Tambahkan di blok location {} di konfigurasi virtual host:
#   limit_req zone=api_limit burst=20 nodelay;
```

### Sembunyikan Versi Server

```bash
# Pastikan server_tokens off aktif
grep "server_tokens" /etc/nginx/conf.d/security-headers.conf
```

### Set NODE_ENV / Environment Production

Setiap framework punya cara untuk mode production — lihat di halaman masing-masing framework.

---

## ✅ Checklist Phase 7

```
[ ] Framework sudah dipilih dan diinstall
[ ] API berjalan di port 3000
[ ] pm2 start → status "online"
[ ] curl http://localhost:3000 mengembalikan JSON
[ ] Konfigurasi Nginx aktif dan reload berhasil
[ ] curl http://localhost (port 80) mengembalikan JSON
[ ] API bisa diakses dari device lain di WiFi yang sama
```

---

[← Phase 6: Remote GUI](./fase-6-remote-gui.md) | [Kembali ke README](../README.md) | [Phase 8: Cloud Storage →](./fase-8-cloud-storage.md)
