# Phase 6: Use Case B — Cloud Storage Pribadi

> **Durasi estimasi:** 20–30 menit

Menggunakan [Filebrowser](https://github.com/filebrowser/filebrowser) sebagai cloud storage self-hosted — alternatif Google Drive yang jalan di HP Android kamu sendiri.

---

## Download & Install Filebrowser

```bash
# Konfirmasi arsitektur (harus aarch64)
uname -m

# Download Filebrowser untuk Linux ARM64
wget https://github.com/filebrowser/filebrowser/releases/latest/download/linux-arm64-filebrowser.tar.gz
tar -xzf linux-arm64-filebrowser.tar.gz
mv filebrowser /usr/local/bin/filebrowser
chmod +x /usr/local/bin/filebrowser
rm linux-arm64-filebrowser.tar.gz

# Verifikasi
filebrowser version
```

> ⚠️ Pastikan download versi `arm64`, bukan `amd64`. Salah arsitektur akan menyebabkan `exec format error`.

---

## Konfigurasi Filebrowser

```bash
# Inisialisasi database config
mkdir -p ~/storage
filebrowser config init --database ~/.filebrowser.db

# Set alamat, port, dan root folder
filebrowser config set \
  --address 0.0.0.0 \
  --port 8080 \
  --root ~/storage \
  --database ~/.filebrowser.db

# Buat user admin — GANTI 'passwordku' dengan password yang kuat!
filebrowser users add admin passwordku \
  --perm.admin \
  --database ~/.filebrowser.db
```

---

## Jalankan dengan pm2

```bash
pm2 start "filebrowser --database /root/.filebrowser.db" --name filebrowser
```

Akses dari browser di device yang sama jaringan:

```
http://<IP-HP>:8080
```

---

## Update Konfigurasi Nginx

Agar Filebrowser bisa diakses via path `/files` (bukan port terpisah), update config Nginx:

```bash
nano /etc/nginx/sites-available/my-api
```

Ganti isi file dengan konfigurasi berikut:

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

Set base URL Filebrowser agar routing `/files` berjalan dengan benar:

```bash
pm2 stop filebrowser
filebrowser config set --baseurl /files --database /root/.filebrowser.db
pm2 start filebrowser
nginx -t && service nginx reload
```

Sekarang Filebrowser bisa diakses di:

```
http://<IP-HP>/files
```

---

## ✅ Checklist Phase 6

```
[ ] filebrowser version tampil tanpa error
[ ] pm2 start filebrowser → status "online"
[ ] Filebrowser bisa diakses dari browser: http://<IP-HP>/files
[ ] Berhasil login, upload, dan download file
```

---

## Upgrade Path: Ingin Fitur Lebih Lengkap?

Filebrowser adalah pilihan terbaik untuk memulai — ringan, setup cepat, dan cukup untuk kebutuhan personal. Tapi kalau kamu butuh fitur yang lebih mendekati Google Drive (share link, WebDAV, mobile app, preview dokumen), ada dua alternatif yang layak dipertimbangkan.

---

### Perbandingan Tiga Opsi

| Fitur | Filebrowser | Cloudreve v4 | Nextcloud |
|-------|------------|-------------|-----------|
| **Kemudahan setup** | ⭐⭐⭐ Sangat mudah | ⭐⭐ Sedang | ⭐ Kompleks |
| **RAM yang dibutuhkan** | ~50–100 MB | ~256–512 MB | ~1–2 GB |
| **Share link publik** | ❌ | ✅ dengan expiry & password | ✅ |
| **WebDAV** (mount ke PC/HP) | ❌ | ✅ | ✅ |
| **Mobile app** iOS & Android | ❌ | ✅ native (v4) | ✅ native |
| **Preview video/dokumen** | ⚠️ terbatas | ✅ lengkap | ✅ lengkap |
| **Edit dokumen online** | ❌ | ✅ OnlyOffice/WOPI | ✅ Collabora/OnlyOffice |
| **Versioning file** | ❌ | ✅ | ✅ |
| **Multi-user + quota** | ⚠️ basic | ✅ | ✅ |
| **PWA** (install di homescreen) | ❌ | ✅ | ✅ |
| **Cocok untuk HP Android** | ✅ Sangat cocok | ✅ Cocok | ⚠️ Butuh RAM besar |
| **Lisensi** | Apache 2.0 (gratis) | GPL-3.0 (gratis) | AGPL-3.0 (gratis) |

> **Rekomendasi:** Mulai dengan Filebrowser. Jika butuh lebih, migrasi ke Cloudreve. Nextcloud hanya worth it kalau HP punya RAM 8 GB+ dan kamu butuh ekosistem kolaborasi lengkap (kalender, kontak, chat).

---

### Alternatif A: Cloudreve

[Cloudreve](https://cloudreve.org/) adalah self-hosted file management platform berbasis Go — satu binary, ringan, dan jauh lebih mirip Google Drive dibanding Filebrowser.

**Fitur unggulan Cloudreve v4:**
- Share link dengan expiry date, password, dan permission berbeda per user
- WebDAV — bisa di-mount sebagai network drive di Windows/macOS/Linux
- Mobile app native untuk iOS dan Android
- Preview video, audio, gambar, ePub secara online
- Edit teks, Markdown, diagram (draw.io), dan gambar langsung di browser
- Versioning file — bisa restore ke versi sebelumnya
- Download background via Aria2/qBittorrent (torrent, magnet, HTTP)
- Multi-storage backend: local, S3, OneDrive, Aliyun OSS, dll
- Mendukung ARM64 (`linux_arm64`) — cocok untuk HP Android

**Resource yang dibutuhkan:**
- RAM: ~256–512 MB (tanpa Redis/database eksternal, SQLite default sudah cukup)
- Storage binary: ~30 MB
- Default port: **5212**

**Referensi resmi:**

| Dokumen | URL |
|---------|-----|
| Homepage | https://cloudreve.org |
| Quick Start | https://docs.cloudreve.org/overview/quickstart |
| Deployment Guide | https://docs.cloudreve.org/overview/deploy/ |
| Deploy via Process Supervisor (pm2-like) | https://docs.cloudreve.org/en/overview/deploy/supervisor |
| Konfigurasi (conf.ini) | https://docs.cloudreve.org/en/overview/configure |
| GitHub Releases (download ARM64) | https://github.com/cloudreve/cloudreve/releases |
| Mobile App (Android) | https://play.google.com/store/apps/details?id=com.cloudrevemobile.app |

**Cara install singkat di Ubuntu PRoot (ARM64):**

```bash
# Download binary ARM64 (ganti VERSION dengan versi terbaru dari GitHub Releases)
wget https://github.com/cloudreve/cloudreve/releases/latest/download/cloudreve_VERSION_linux_arm64.tar.gz
tar -zxvf cloudreve_VERSION_linux_arm64.tar.gz
chmod +x ./cloudreve
mkdir -p /opt/cloudreve
mv cloudreve /opt/cloudreve/

# Jalankan pertama kali (akan generate conf.ini otomatis)
/opt/cloudreve/cloudreve
# → Catat password admin yang muncul di log pertama kali!

# Jalankan dengan pm2
pm2 start /opt/cloudreve/cloudreve --name cloudreve
```

Akses di: `http://<IP-HP>:5212`

> ⚠️ Akun pertama yang **register** otomatis jadi admin — segera register setelah pertama kali jalan, sebelum orang lain bisa.

**Nginx proxy untuk Cloudreve:**

```nginx
location /cloud {
    proxy_pass         http://localhost:5212;
    proxy_http_version 1.1;
    proxy_set_header   Host              $host;
    proxy_set_header   X-Real-IP         $remote_addr;
    proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
    proxy_set_header   X-Forwarded-Proto $scheme;
    proxy_set_header   Upgrade    $http_upgrade;
    proxy_set_header   Connection "upgrade";
    # Upload file besar — sesuaikan dengan kebutuhan
    client_max_body_size 0;
}
```

---

### Alternatif B: Nextcloud

[Nextcloud](https://nextcloud.com/) adalah solusi self-hosted paling lengkap — bukan hanya cloud storage, tapi full Google Workspace replacement (file, kalender, kontak, chat, video call, dan 200+ aplikasi tambahan).

**Kapan pilih Nextcloud:**
- HP punya RAM **8 GB+** (Nextcloud butuh PHP-FPM + MySQL/MariaDB + Redis + Nginx berjalan bersamaan)
- Butuh ekosistem kolaborasi tim lengkap (bukan hanya storage)
- Perlu LDAP/SAML/OIDC SSO gratis (tidak perlu bayar seperti Cloudreve Pro)
- Desktop sync client di Linux/macOS (Cloudreve Pro Windows-only)

**Stack yang dibutuhkan:**
```
Nginx → PHP-FPM → Nextcloud PHP
             ↓
        MySQL/MariaDB + Redis
```

**Resource yang dibutuhkan:**
- RAM: **1–2 GB minimum** (realistisnya lebih)
- Storage: ratusan MB untuk dependencies PHP
- Setup time: **1–2 jam** (vs Cloudreve ~15 menit)

**Referensi resmi:**

| Dokumen | URL |
|---------|-----|
| Homepage | https://nextcloud.com |
| Dokumentasi Admin | https://docs.nextcloud.com/server/stable/admin_manual/ |
| Install di Ubuntu (manual) | https://docs.nextcloud.com/server/stable/admin_manual/installation/source_installation.html |
| Contoh install Ubuntu 22.04 | https://docs.nextcloud.com/server/stable/admin_manual/installation/example_ubuntu.html |
| System requirements | https://docs.nextcloud.com/server/stable/admin_manual/installation/system_requirements.html |
| GitHub | https://github.com/nextcloud/server |
| Mobile App Android | https://play.google.com/store/apps/details?id=com.nextcloud.client |
| Desktop Sync Client | https://nextcloud.com/install/#install-clients |

> ⚠️ **Catatan untuk HP Android:** Nextcloud **bisa** jalan di setup ini, tapi tidak direkomendasikan kecuali HP kamu punya RAM 8 GB+. Di RAM 4–6 GB, Nextcloud akan bersaing dengan Ubuntu PRoot dan proses lain, sering menyebabkan OOM killer atau performa sangat lambat.

---

[← Phase 7: Web Server & API](./fase-7-web-server-api.md) | [Kembali ke README](../README.md)
