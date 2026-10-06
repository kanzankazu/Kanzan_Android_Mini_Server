# Phase 8: Use Case B — Cloud Storage Pribadi

> **Durasi estimasi:** 20–120 menit (tergantung pilihan storage)

Self-hosted cloud storage yang berjalan di HP Android — alternatif Google Drive tanpa biaya bulanan.

Halaman ini membantu kamu memilih solusi yang tepat. Konfigurasi Nginx dasar berlaku untuk semua pilihan.

---

## Pilih Storage Solution

| | [Filebrowser](./storage-filebrowser.md) | [Cloudreve](./storage-cloudreve.md) | [Nextcloud](./storage-nextcloud.md) |
|--|----------------------------------------|-------------------------------------|--------------------------------------|
| **Kemudahan setup** | ⭐⭐⭐ Sangat mudah | ⭐⭐ Sedang | ⭐ Kompleks |
| **RAM** | ~50–100 MB | ~256–512 MB | ~1–2 GB |
| **Setup time** | ~20–30 menit | ~30–45 menit | ~60–120 menit |
| **Share link publik** | ❌ | ✅ expiry + password | ✅ |
| **WebDAV** (mount ke PC) | ❌ | ✅ | ✅ |
| **Mobile app** | ❌ | ✅ native | ✅ native |
| **Preview media/dokumen** | ⚠️ terbatas | ✅ lengkap | ✅ lengkap |
| **Versioning file** | ❌ | ✅ | ✅ |
| **Cocok untuk HP Android** | ✅ Sangat cocok | ✅ Cocok | ⚠️ RAM 8 GB+ |

> **Rekomendasi:** Mulai dengan **Filebrowser** — ringan dan cukup untuk kebutuhan personal. Jika butuh share link dan WebDAV, lanjut ke **Cloudreve**. **Nextcloud** hanya worth it di HP RAM 8 GB+ yang butuh ekosistem kolaborasi lengkap.

---

## Pilih dan Mulai

- **[→ Filebrowser](./storage-filebrowser.md)** — Default, paling ringan, setup 20 menit
- **[→ Cloudreve](./storage-cloudreve.md)** — Mirip Google Drive, single binary Go, WebDAV + mobile app
- **[→ Nextcloud](./storage-nextcloud.md)** — Full Google Workspace replacement, butuh RAM 8 GB+

---

## Konfigurasi Nginx Dasar (Shared)

Setelah storage solution dipilih dan berjalan, tambahkan routing di Nginx. Port default masing-masing:

| Storage | Port Default | Path di Nginx |
|---------|-------------|---------------|
| Filebrowser | 8080 | `/files` |
| Cloudreve | 5212 | `/cloud` |
| Nextcloud | 80 (PHP-FPM) | `/` atau subdomain |

Contoh config Nginx jika menggunakan **Filebrowser** dan **API** bersamaan:

```nginx
server {
    listen 80;
    server_name _;

    # API (fase-7)
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

    # Filebrowser
    location /files {
        proxy_pass         http://localhost:8080;
        proxy_http_version 1.1;
        proxy_set_header   Host              $host;
        proxy_set_header   X-Real-IP         $remote_addr;
        proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
        proxy_set_header   Upgrade           $http_upgrade;
        proxy_set_header   Connection        "upgrade";
    }
}
```

Lihat config spesifik untuk Cloudreve dan Nextcloud di halaman masing-masing.

---

## 🔒 Security Tips (Berlaku untuk Semua)

### Ganti Password Default Segera

Semua storage solution ini punya password default yang harus diganti sebelum diekspos ke internet. Lihat detail di halaman masing-masing.

### Aktifkan Cloudflare Zero Trust

Tambahkan layer autentikasi email OTP di depan subdomain storage:

```
Cloudflare Zero Trust (one.dash.cloudflare.com)
  → Access → Applications → Add application → Self-hosted
  → files.kamu.com / cloud.kamu.com
  → Policy: Allow emails = kamu@email.com
```

### Batasi Root Folder

Pastikan root folder storage mengarah ke direktori khusus (`~/storage`), bukan ke `/root` atau folder sistem lain yang berisi konfigurasi server.

---

## ✅ Checklist Phase 8

```
[ ] Storage solution sudah dipilih dan terinstall
[ ] pm2 start → status "online"
[ ] Akses dari browser berhasil (login, upload, download)
[ ] Nginx config untuk storage aktif
[ ] Password default sudah diganti
[ ] pm2 save berhasil
```

---

[← Phase 7: Web Server & API](./fase-7-web-server-api.md) | [Kembali ke README](../README.md)
