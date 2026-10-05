# Tips & Best Practices

Panduan ini mengasumsikan kamu sudah menyelesaikan setup sampai [Phase 6](./fase-6-domain-custom.md). Tips di bawah membantu menjaga server tetap aman, stabil, dan mudah di-maintain.

---

## Daftar Isi

- [Keamanan](#keamanan)
- [Performa & Stabilitas](#performa--stabilitas)
- [Backup Konfigurasi](#backup-konfigurasi)
- [Limitasi yang Perlu Diketahui](#limitasi-yang-perlu-diketahui)
- [Kapan Lebih Baik Pakai VPS](#kapan-lebih-baik-pakai-vps)

---

## Keamanan

### Ganti Password Filebrowser

Ganti password default segera setelah setup pertama:

```bash
filebrowser users update admin --password "passwordBaruYangKuat" \
  --database /root/.filebrowser.db
pm2 restart filebrowser
```

### Gunakan Cloudflare Access

Cloudflare Access menambahkan layer autentikasi di depan subdomain — gratis untuk 1 user. Berguna untuk melindungi Filebrowser agar tidak bisa diakses sembarang orang meski URL diketahui.

```
Cloudflare Dashboard
  → Zero Trust
  → Access → Applications
  → Add application → Self-hosted
  → Domain: files.namaserver.com
  → Policy: allow email = kamu@email.com
```

### Jangan Simpan File Sensitif Tanpa Enkripsi

Folder `~/storage` adalah root Filebrowser. Jangan simpan file sangat sensitif (credential, private key) di sana tanpa enkripsi tambahan.

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
