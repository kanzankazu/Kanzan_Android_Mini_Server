# Phase 3: Expose ke Internet via Cloudflare Tunnel

> **Durasi estimasi:** 30–45 menit

Membuat server HP Android dapat diakses dari internet dengan HTTPS — tanpa port forwarding, tanpa static IP, tanpa biaya VPS.

**Prasyarat:**
- Akun Cloudflare gratis ([cloudflare.com](https://cloudflare.com))
- Domain yang di-manage Cloudflare (diperlukan untuk tunnel permanen — lihat [Phase 4](./fase-4-domain-custom.md))

---

## Download & Install cloudflared

```bash
# Download cloudflared untuk ARM64 (JANGAN download amd64!)
wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64 \
  -O /usr/local/bin/cloudflared
chmod +x /usr/local/bin/cloudflared

# Verifikasi
cloudflared --version
```

> ⚠️ Pastikan download versi `arm64`. Salah arsitektur akan menyebabkan `exec format error`.

---

## Login ke Cloudflare

```bash
cloudflared tunnel login
```

Perintah ini akan menampilkan URL — buka di browser, pilih domain kamu, klik **Authorize**. File `cert.pem` akan tersimpan di `~/.cloudflared/`.

---

## Buat Tunnel

```bash
cloudflared tunnel create android-server
```

Catat **Tunnel ID** yang ditampilkan — akan dipakai di langkah berikutnya.

---

## Buat File Konfigurasi

```bash
nano ~/.cloudflared/config.yml
```

```yaml
tunnel: <TUNNEL_ID>
credentials-file: /root/.cloudflared/<TUNNEL_ID>.json

loglevel: info

ingress:
  - hostname: api.domain.com
    service: http://localhost:80
  - hostname: files.domain.com
    service: http://localhost:8080
  - service: http_status:404
```

> Ganti `<TUNNEL_ID>` dengan ID yang didapat dari langkah sebelumnya, dan `domain.com` dengan domain kamu.

---

## Daftarkan DNS

```bash
cloudflared tunnel route dns android-server api.domain.com
cloudflared tunnel route dns android-server files.domain.com
```

Perintah ini otomatis membuat CNAME record di Cloudflare DNS.

---

## Jalankan Tunnel dengan pm2

```bash
pm2 start "cloudflared tunnel run android-server" --name cloudflared
pm2 save
```

Verifikasi tunnel terhubung:

```bash
pm2 logs cloudflared
# Cari baris: "Connection established"
```

---

## Alternatif: Quick Tunnel (Tanpa Domain)

Jika belum punya domain, gunakan quick tunnel untuk testing:

```bash
pm2 start "cloudflared tunnel --url http://localhost:80" --name cloudflared-quick
pm2 logs cloudflared-quick
# Cari baris: "https://random-name-abc123.trycloudflare.com"
```

URL ini bersifat sementara dan akan berubah setiap kali tunnel di-restart. Cocok untuk demo atau testing saja.

---

## Ringkasan Semua Service

Setelah Phase 3, `pm2 list` harus menampilkan:

```
┌─────────────┬────────┬─────────┐
│ Name        │ Status │ Restarts│
├─────────────┼────────┼─────────┤
│ my-api      │ online │ 0       │
│ filebrowser │ online │ 0       │
│ cloudflared │ online │ 0       │
└─────────────┴────────┴─────────┘
```

---

## 🔒 Security Tips

### Lindungi File Credentials Tunnel

File `~/.cloudflared/<TUNNEL_ID>.json` adalah kunci tunnel kamu — siapapun yang punya file ini bisa membajak tunnel dan mengontrol traffic ke server.

```bash
# Pastikan hanya root yang bisa baca file credentials
chmod 600 ~/.cloudflared/<TUNNEL_ID>.json
chmod 600 ~/.cloudflared/cert.pem
chmod 700 ~/.cloudflared/

# Verifikasi
ls -la ~/.cloudflared/
```

### Jangan Ekspos Port Secara Langsung

Config Cloudflare Tunnel yang benar menggunakan `localhost` atau `127.0.0.1` sebagai target service — **bukan** IP jaringan lokal atau `0.0.0.0`:

```yaml
# ✅ BENAR — hanya bisa diakses via tunnel
ingress:
  - hostname: api.domain.com
    service: http://localhost:80

# ❌ SALAH — expose service langsung ke jaringan lokal
ingress:
  - hostname: api.domain.com
    service: http://0.0.0.0:80
```

### Monitor Log Tunnel Secara Berkala

Cek log cloudflared untuk mendeteksi aktivitas mencurigakan (koneksi berulang dari IP asing, error auth):

```bash
# Lihat log real-time
pm2 logs cloudflared

# Lihat 100 baris log terakhir
pm2 logs cloudflared --lines 100

# Simpan log ke file untuk analisis
pm2 logs cloudflared --lines 500 > /tmp/tunnel-log.txt
```

### Batasi Ingress Hanya ke Service yang Diperlukan

Jangan biarkan entry wildcard atau service yang tidak dipakai aktif di `config.yml`. Audit secara berkala:

```bash
cat ~/.cloudflared/config.yml
# Hapus hostname yang tidak dipakai lagi
```

Setelah edit config, selalu restart dan verifikasi:

```bash
cloudflared tunnel ingress validate
pm2 restart cloudflared
```

### Rotate Credentials Jika Dicurigai Bocor

Jika credentials tunnel dicurigai bocor atau HP hilang:

```bash
# Hapus tunnel lama dari Cloudflare Dashboard
# Buat tunnel baru dengan ID berbeda
cloudflared tunnel create android-server-new

# Update config.yml dengan tunnel ID baru
nano ~/.cloudflared/config.yml
```

Atau langsung dari [Cloudflare Dashboard](https://dash.cloudflare.com) → Zero Trust → Networks → Tunnels → Delete tunnel lama.

---

## ✅ Checklist Phase 3

```
[ ] cloudflared --version tampil tanpa error
[ ] cloudflared tunnel login berhasil (cert.pem ada di ~/.cloudflared/)
[ ] Tunnel 'android-server' berhasil dibuat
[ ] config.yml sudah dibuat dengan TUNNEL_ID yang benar
[ ] pm2 logs cloudflared menampilkan "Connection established"
[ ] https://api.domain.com bisa diakses dari data seluler
[ ] pm2 save sudah dijalankan
```

---

[← Phase 2: Fondasi Server](./fase-2-fondasi-server.md) | [Kembali ke README](../README.md) | [Phase 4: Domain Custom →](./fase-4-domain-custom.md)
