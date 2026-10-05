# Phase 4: Use Case B — Cloud Storage Pribadi

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

## ✅ Checklist Phase 4

```
[ ] filebrowser version tampil tanpa error
[ ] pm2 start filebrowser → status "online"
[ ] Filebrowser bisa diakses dari browser: http://<IP-HP>/files
[ ] Berhasil login, upload, dan download file
```

---

[← Phase 3: Web Server & API](./fase-3-web-server-api.md) | [Kembali ke README](../README.md) | [Phase 5: Expose ke Internet →](./fase-5-expose-internet.md)
