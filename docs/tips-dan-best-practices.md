# Tips & Best Practices

Panduan ini mengasumsikan kamu sudah menyelesaikan setup sampai [Phase 4](./fase-4-domain-custom.md). Tips di bawah membantu menjaga server tetap aman, stabil, dan mudah di-maintain.

---

## Daftar Isi

- [Keamanan](#keamanan)
- [Performa & Stabilitas](#performa--stabilitas)
- [Backup Konfigurasi](#backup-konfigurasi)
- [Limitasi yang Perlu Diketahui](#limitasi-yang-perlu-diketahui)
- [Kapan Lebih Baik Pakai VPS](#kapan-lebih-baik-pakai-vps)

---

## Keamanan

> Keamanan bersifat berlapis — semakin banyak layer yang aktif, semakin sulit penyerang masuk. Implementasikan semua yang relevan, bukan hanya satu.

### Checklist Keamanan Keseluruhan

Gunakan ini sebagai audit setelah semua fase selesai:

```
[ ] Password semua service sudah diganti dari default (Filebrowser, Webmin, code-server)
[ ] SSH password auth dinonaktifkan — hanya SSH key yang bisa login
[ ] Cloudflare Zero Trust Access aktif untuk semua panel publik
[ ] SSL/TLS mode Full atau Full (Strict) di Cloudflare
[ ] HSTS aktif di Cloudflare
[ ] Bot Fight Mode aktif di Cloudflare
[ ] TLS minimum 1.2 di Cloudflare
[ ] Nginx security headers aktif (X-Frame-Options, X-Content-Type-Options, dll)
[ ] Nginx rate limiting aktif
[ ] Credentials cloudflared (chmod 600) sudah diproteksi
[ ] Filebrowser signup dinonaktifkan
[ ] UFW firewall dikonfigurasi di Ubuntu PRoot
[ ] Node.js API menggunakan helmet.js dan express-rate-limit
```

---

### Ganti Password Semua Service

Ganti password default segera setelah setup pertama — jangan tunggu sampai server live:

```bash
# Filebrowser
filebrowser users update admin \
  --password "$(openssl rand -base64 24)" \
  --database /root/.filebrowser.db
pm2 restart filebrowser

# Webmin
/usr/share/webmin/changepass.pl /etc/webmin root "$(openssl rand -base64 24)"

# code-server
nano ~/.config/code-server/config.yaml
# Update: password: <password-baru>
pm2 restart code-server
```

Simpan semua password di password manager, bukan di file plain text di server.

---

### Cloudflare Zero Trust Access (Wajib untuk Panel)

Cloudflare Access menambahkan layer autentikasi email OTP di depan subdomain — gratis untuk penggunaan personal. Tanpa ini, siapapun yang tahu URL panel bisa mencoba brute force login.

```
Cloudflare Dashboard → Zero Trust → Access → Applications
  → Add application → Self-hosted

Ulangi untuk setiap panel:
  → panel.namaserver.com   (Webmin)
  → code.namaserver.com    (code-server)
  → files.namaserver.com   (Filebrowser)
  → ssh.namaserver.com     (SSH tunnel)

Policy: Allow → Emails → kamu@email.com
```

---

### UFW Firewall di Ubuntu PRoot

Konfigurasi firewall untuk membatasi port yang bisa diakses dari jaringan lokal:

```bash
apt install ufw -y

# Default policy
ufw default deny incoming
ufw default allow outgoing

# Izinkan port yang dipakai
ufw allow 80/tcp     # Nginx HTTP
ufw allow 8080/tcp   # Filebrowser (jika akses langsung)
ufw allow 10000/tcp  # Webmin (hanya jika perlu akses lokal)

# Aktifkan
ufw enable --force
ufw status verbose
```

Untuk port yang hanya perlu diakses dari IP tertentu (misal komputer di rumah):

```bash
ufw allow from 192.168.1.100 to any port 10000
```

---

### Update Sistem Secara Terjadwal

Jalankan update rutin untuk menutup celah keamanan yang baru ditemukan:

```bash
# Update manual — jalankan setiap minggu
apt update && apt upgrade -y

# Atau buat cron job otomatis (setiap Minggu jam 03:00)
crontab -e
# Tambahkan:
# 0 3 * * 0 apt update && apt upgrade -y >> /tmp/apt-update.log 2>&1
```

Update package Termux juga:

```bash
# Di Termux (bukan Ubuntu PRoot)
pkg update && pkg upgrade -y
```

---

### Audit Log Akses Berkala

Periksa log secara berkala untuk mendeteksi aktivitas mencurigakan:

```bash
# Log akses Nginx (siapa saja yang request ke server)
tail -100 /var/log/nginx/access.log

# Filter IP yang paling banyak request (kemungkinan scanner)
awk '{print $1}' /var/log/nginx/access.log | sort | uniq -c | sort -rn | head -20

# Log error Nginx
tail -50 /var/log/nginx/error.log

# Log tunnel Cloudflare
pm2 logs cloudflared --lines 100

# Log semua service pm2
pm2 logs --lines 50
```

Tanda-tanda aktivitas mencurigakan yang perlu diwaspadai:
- Satu IP membuat ratusan request dalam waktu singkat
- Request ke path yang tidak ada (`/wp-admin`, `/phpmyadmin`, `/.env`)
- Error 401/403 berulang dari IP yang sama

---

### Enkripsi File Sensitif

Jangan simpan file sensitif (private key, credential, token) di `~/storage` tanpa enkripsi:

```bash
# Enkripsi file sebelum disimpan
gpg --symmetric --cipher-algo AES256 file-sensitif.txt
# Akan menghasilkan file-sensitif.txt.gpg — aman disimpan

# Dekripsi saat dibutuhkan
gpg --decrypt file-sensitif.txt.gpg > file-sensitif.txt
```

---

### Nonaktifkan Fitur yang Tidak Dipakai

Setiap service yang berjalan adalah potensi attack surface. Matikan yang tidak dibutuhkan:

```bash
# Cek semua proses pm2 yang berjalan
pm2 list

# Stop service yang tidak dipakai saat ini
pm2 stop <nama-service>

# Hapus dari startup
pm2 delete <nama-service>
pm2 save
```

---

### Jangan Simpan File Sensitif Tanpa Enkripsi

Folder `~/storage` adalah root Filebrowser yang bisa diakses via web. Jangan simpan file sangat sensitif (credential, private key, database dump) di sana tanpa enkripsi tambahan.

---

## Performa & Stabilitas

### Monitor Resource

```bash
free -h    # Penggunaan RAM
htop       # CPU per proses, real-time
df -h      # Penggunaan storage
```

Estimasi konsumsi RAM untuk semua service berjalan bersamaan:

| Service | RAM |
|---------|-----|
| Nginx | ~5–10 MB |
| Node.js + Express | ~50–80 MB |
| Filebrowser | ~30–50 MB |
| cloudflared | ~30–50 MB |
| **Total** | **~150–300 MB** |

HP dengan RAM 4 GB masih punya cukup headroom.

### Cegah Termux Mati di Background

Dua langkah wajib setiap sesi:

1. **Wakelock:** Geser notifikasi Termux → "Acquire wakelock"
2. **Battery optimization:** Settings → Apps → Termux → Battery → "Don't optimize"

### Simpan State pm2

Selalu jalankan `pm2 save` setelah perubahan apapun pada proses pm2, agar bisa di-resurrect saat sesi Ubuntu dibuka kembali:

```bash
pm2 save
```

---

## Backup Konfigurasi

Backup semua file konfigurasi penting ke `~/storage/backup-config` — otomatis tersync ke Filebrowser:

```bash
mkdir -p ~/storage/backup-config

# Cloudflare tunnel credentials & config
cp -r ~/.cloudflared ~/storage/backup-config/

# Filebrowser database (user, config)
cp ~/.filebrowser.db ~/storage/backup-config/

# Nginx virtual host config
cp -r /etc/nginx/sites-available ~/storage/backup-config/

# Kode aplikasi
cp -r ~/apps ~/storage/backup-config/
```

Jalankan backup ini secara berkala, terutama setelah ada perubahan konfigurasi signifikan.

---

## Limitasi yang Perlu Diketahui

| Limitasi | Detail | Workaround |
|----------|--------|------------|
| **Port < 1024** | PRoot tidak bisa bind langsung ke port 80/443 | Nginx di port 8000+, atau gunakan `authbind` |
| **systemd tidak penuh** | Service management terbatas di PRoot | Gunakan `service` atau `pm2` |
| **pm2 tidak persistent** | State hilang jika Ubuntu session ditutup | `pm2 save` + `pm2 resurrect` atau startup script |
| **Thermal throttling** | Load tinggi = panas = performa turun | Monitor `htop`, kurangi service aktif |
| **Performa I/O** | Storage HP lebih lambat dari SSD server | Cukup untuk side project, bukan high-traffic production |

---

## Kapan Lebih Baik Pakai VPS

HP Android sebagai server ideal untuk belajar, hobby, dan side project. Pertimbangkan pindah ke VPS jika:

- **Traffic tinggi** — ribuan request per menit secara konsisten
- **Uptime kritis (99.9%+)** — bisnis atau layanan yang tidak boleh mati
- **Static IP diperlukan** — integrasi dengan sistem yang butuh IP tetap
- **Tim development** — perlu akses bersama ke environment yang sama
- **Database besar dengan I/O intensif** — MySQL/PostgreSQL dengan banyak write operation

> Kabar baiknya: semua yang dipelajari di panduan ini (Nginx, Node.js, pm2, Cloudflare Tunnel) berlaku 1:1 di VPS manapun.

---

[← Troubleshooting](./troubleshooting.md) | [Kembali ke README](../README.md)
