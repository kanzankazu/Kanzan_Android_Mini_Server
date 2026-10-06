# Storage: Nextcloud

> **Durasi estimasi:** 60–120 menit
>
> **Prasyarat:** [Phase 2](./fase-2-fondasi-server.md) sudah selesai, RAM HP **8 GB+**

[Nextcloud](https://nextcloud.com/) adalah solusi self-hosted paling lengkap — bukan hanya cloud storage, tapi full Google Workspace replacement (file, kalender, kontak, chat, video call, dan 200+ aplikasi tambahan).

> ⚠️ **Baca ini sebelum mulai:** Nextcloud **bisa** jalan di setup ini, tapi **tidak direkomendasikan** kecuali HP kamu punya RAM 8 GB+. Di RAM 4–6 GB, Nextcloud akan bersaing dengan Ubuntu PRoot dan proses lain, sering menyebabkan OOM killer atau performa sangat lambat. Pertimbangkan [Cloudreve](./storage-cloudreve.md) sebagai alternatif yang jauh lebih ringan.

---

## Kapan Pilih Nextcloud

Pilih Nextcloud jika:
- HP punya RAM **8 GB+**
- Butuh ekosistem kolaborasi tim lengkap (kalender, kontak, chat, video call)
- Perlu LDAP/SAML/OIDC SSO tanpa biaya tambahan
- Butuh desktop sync client di Linux/macOS
- Perlu 200+ aplikasi tambahan dari Nextcloud App Store

---

## Stack yang Dibutuhkan

```
Nginx (sudah ada) → PHP-FPM → Nextcloud PHP
                        ↓
               MySQL/MariaDB + Redis
```

**Resource yang dibutuhkan:**
- RAM: **1–2 GB minimum** aktif (realistisnya lebih saat ada traffic)
- Storage: ~500 MB untuk PHP dependencies
- Setup time: **1–2 jam**

---

## Install Dependencies

```bash
# Di Ubuntu PRoot
apt update

# PHP dan ekstensi yang dibutuhkan Nextcloud
apt install php8.1 php8.1-fpm php8.1-gd php8.1-mysql php8.1-curl \
  php8.1-mbstring php8.1-intl php8.1-gmp php8.1-bcmath php8.1-xml \
  php8.1-imagick php8.1-zip php8.1-bz2 php8.1-redis -y

# Database
apt install mariadb-server -y

# Redis (untuk caching — sangat membantu performa)
apt install redis-server -y

# Verifikasi PHP
php --version
```

---

## Setup Database

```bash
service mariadb start

mysql -u root -e "
CREATE DATABASE nextcloud CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE USER 'nextcloud'@'localhost' IDENTIFIED BY 'passworddb_kuat';
GRANT ALL PRIVILEGES ON nextcloud.* TO 'nextcloud'@'localhost';
FLUSH PRIVILEGES;
"
```

Ganti `passworddb_kuat` dengan password yang kuat.

---

## Download Nextcloud

```bash
# Cek versi terbaru di https://nextcloud.com/install/
wget https://download.nextcloud.com/server/releases/latest.tar.bz2
tar -xjf latest.tar.bz2
mv nextcloud /var/www/
rm latest.tar.bz2

# Set permission
chown -R www-data:www-data /var/www/nextcloud
```

---

## Konfigurasi PHP-FPM

```bash
nano /etc/php/8.1/fpm/pool.d/www.conf
```

Sesuaikan untuk RAM terbatas:

```ini
pm = dynamic
pm.max_children = 5
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 3
```

```bash
service php8.1-fpm start
```

---

## Konfigurasi Nginx untuk Nextcloud

Buat config baru:

```bash
nano /etc/nginx/sites-available/nextcloud
```

```nginx
upstream php-handler {
    server unix:/var/run/php/php8.1-fpm.sock;
}

server {
    listen 80;
    server_name _;

    root /var/www/nextcloud;
    index index.php index.html;

    client_max_body_size 512M;
    fastcgi_buffers 64 4K;

    location = /robots.txt { return 204; access_log off; log_not_found off; }
    location = /favicon.ico { return 204; access_log off; log_not_found off; }

    location / {
        rewrite ^ /index.php;
    }

    location ~ ^\/(?:build|tests|config|lib|3rdparty|templates|data)\/ {
        deny all;
    }

    location ~ \.php(?:$|\/) {
        fastcgi_split_path_info ^(.+\.php)(\/.*)?$;
        set $path_info $fastcgi_path_info;
        fastcgi_param PATH_INFO $path_info;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_pass php-handler;
        fastcgi_intercept_errors on;
        fastcgi_request_buffering off;
    }

    location ~ \.(?:css|js|woff2?|svg|gif|map)$ {
        try_files $uri /index.php$request_uri;
        add_header Cache-Control "public, max-age=15778463";
        expires 6M;
    }

    location ~ \.(?:png|html|ttf|ico|jpg|jpeg|bcmap|mp4|webm)$ {
        try_files $uri /index.php$request_uri;
    }
}
```

Aktifkan:

```bash
ln -s /etc/nginx/sites-available/nextcloud /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t && service nginx reload
```

---

## Instalasi Nextcloud via Web

Buka browser dan akses `http://<IP-HP>`:

1. Isi username dan password admin
2. Data folder: `/var/www/nextcloud/data`
3. Database: MySQL/MariaDB
   - User: `nextcloud`
   - Password: `passworddb_kuat`
   - Database: `nextcloud`
   - Host: `localhost`
4. Klik **Install** — tunggu beberapa menit

---

## Konfigurasi Tambahan

Edit `config.php` setelah install:

```bash
nano /var/www/nextcloud/config/config.php
```

Tambahkan di dalam array `$CONFIG`:

```php
'trusted_domains' => [
    'localhost',
    '<IP-HP>',
    'cloud.kamu.com',   // domain kamu
],
'overwrite.cli.url' => 'https://cloud.kamu.com',
'overwriteprotocol' => 'https',
'redis' => [
    'host' => 'localhost',
    'port' => 6379,
],
'memcache.local'      => '\\OC\\Memcache\\Redis',
'memcache.distributed' => '\\OC\\Memcache\\Redis',
'memcache.locking'    => '\\OC\\Memcache\\Redis',
```

---

## Start Semua Service via pm2

```bash
pm2 start "service mariadb start && tail -f /dev/null" --name mariadb
pm2 start "service php8.1-fpm start && tail -f /dev/null" --name php-fpm
pm2 start "service redis-server start && tail -f /dev/null" --name redis
pm2 save
```

---

## Referensi

| Dokumen | URL |
|---------|-----|
| Homepage | https://nextcloud.com |
| Dokumentasi Admin | https://docs.nextcloud.com/server/stable/admin_manual/ |
| System Requirements | https://docs.nextcloud.com/server/stable/admin_manual/installation/system_requirements.html |
| GitHub | https://github.com/nextcloud/server |
| Mobile App Android | https://play.google.com/store/apps/details?id=com.nextcloud.client |

---

## ✅ Checklist

```
[ ] RAM HP 8 GB+ sudah dikonfirmasi
[ ] PHP, MariaDB, Redis terinstall
[ ] Database nextcloud sudah dibuat
[ ] Nginx config untuk Nextcloud aktif
[ ] Install via browser berhasil
[ ] Login admin berhasil
[ ] config.php sudah dikonfigurasi (trusted_domains, Redis)
```

---

[← Kembali ke Phase 8](./fase-8-cloud-storage.md) | [Kembali ke README](../README.md)
