# Storage: Filebrowser

> **Durasi estimasi:** 20–30 menit
>
> **Prasyarat:** [Phase 2](./fase-2-fondasi-server.md) sudah selesai, Nginx berjalan

[Filebrowser](https://github.com/filebrowser/filebrowser) adalah pilihan default — file manager berbasis web yang ringan, setup cepat, dan cukup untuk kebutuhan personal.

---

## Download & Install

```bash
# Di Ubuntu PRoot
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

## Konfigurasi

```bash
# Inisialisasi database config
mkdir -p ~/storage
filebrowser config init --database ~/.filebrowser.db

# Set alamat, port, dan root folder
filebrowser config set \
  --address 127.0.0.1 \
  --port 8080 \
  --root ~/storage \
  --database ~/.filebrowser.db

# Buat user admin — GANTI 'passwordku' dengan password yang kuat!
filebrowser users add admin passwordku \
  --perm.admin \
  --database ~/.filebrowser.db

# Nonaktifkan signup publik
filebrowser config set \
  --signup=false \
  --database ~/.filebrowser.db
```

---

## Jalankan dengan pm2

```bash
pm2 start "filebrowser --database /root/.filebrowser.db" --name filebrowser
pm2 save
```

Akses dari browser di jaringan yang sama:

```
http://<IP-HP>:8080
```

---

## Konfigurasi Nginx

Agar Filebrowser bisa diakses via path `/files`:

```bash
nano /etc/nginx/sites-available/my-api
```

Tambahkan di dalam blok `server {}`:

```nginx
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
```

Set base URL agar routing `/files` benar:

```bash
pm2 stop filebrowser
filebrowser config set --baseurl /files --database /root/.filebrowser.db
pm2 start filebrowser
nginx -t && service nginx reload
```

Akses sekarang di:

```
http://<IP-HP>/files
```

---

## 🔒 Security Tips

### Ganti Password Segera

```bash
filebrowser users update admin \
  --password "$(openssl rand -base64 24)" \
  --database /root/.filebrowser.db
pm2 restart filebrowser
```

### Batasi Root ke Folder Khusus

Root sudah di-set ke `~/storage` — jangan ubah ke `/root` atau folder sistem lain.

### Aktifkan Cloudflare Zero Trust

Jika diekspos via subdomain publik, pasang Cloudflare Access:

```
Cloudflare Zero Trust → Access → Applications
→ files.kamu.com → Allow emails = kamu@email.com
```

### Scan File Upload (Opsional)

```bash
apt install clamav -y
freshclam

# Scan manual
clamscan -r ~/storage --infected

# Cron mingguan (Minggu jam 03:00)
crontab -e
# 0 3 * * 0 clamscan -r /root/storage --infected --log=/tmp/clamav-scan.log
```

---

## ✅ Checklist

```
[ ] filebrowser version tampil tanpa error
[ ] pm2 start filebrowser → status "online"
[ ] Filebrowser bisa diakses: http://<IP-HP>/files
[ ] Berhasil login, upload, dan download file
[ ] Password default sudah diganti
[ ] Signup publik dinonaktifkan
[ ] pm2 save berhasil
```

---

[← Kembali ke Phase 8](./fase-8-cloud-storage.md) | [Kembali ke README](../README.md)
