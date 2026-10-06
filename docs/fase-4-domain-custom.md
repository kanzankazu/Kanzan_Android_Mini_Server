# Phase 4: Setup Domain Custom

> **Durasi estimasi:** 15–30 menit
>
> **Prasyarat:** [Phase 3](./fase-3-expose-internet.md) sudah selesai — tunnel sudah berjalan dan `pm2 logs cloudflared` menampilkan "Connection established"

Panduan ini menggunakan domain yang **sudah kamu miliki** (dibeli dari registrar seperti Niagahoster, Namecheap, GoDaddy, dll). Cloudflare bertindak sebagai nameserver sekaligus proxy gratis.

---

## Daftarkan Domain ke Cloudflare

1. Login ke [dash.cloudflare.com](https://dash.cloudflare.com) → **Add a Site**
2. Masukkan domain kamu (contoh: `namaserver.com`) → pilih plan **Free** → Continue
3. Cloudflare akan scan DNS record yang sudah ada → klik **Continue**
4. Salin 2 nameserver yang diberikan Cloudflare, contoh:
   ```
   ara.ns.cloudflare.com
   ken.ns.cloudflare.com
   ```
5. Buka panel registrar domain kamu → ganti nameserver lama dengan 2 nameserver Cloudflare di atas
6. Tunggu propagasi — biasanya **10–30 menit**, maksimal 48 jam
7. Kembali ke Cloudflare → klik **Done, check nameservers** → tunggu status berubah jadi **Active**

Verifikasi nameserver aktif:

```bash
# Jalankan dari Ubuntu di HP
apt install dnsutils -y
dig NS namaserver.com +short
# Harus muncul nameserver Cloudflare
```

---

## Buat DNS Record via Tunnel

Setelah domain aktif di Cloudflare, hubungkan subdomain ke tunnel:

```bash
# Di Ubuntu (pastikan sudah login cloudflared sebelumnya)
# Format: cloudflared tunnel route dns <nama-tunnel> <subdomain>

# Untuk API (arahkan ke Nginx port 80)
cloudflared tunnel route dns android-server api.namaserver.com

# Untuk Filebrowser (routing /files ditangani Nginx)
cloudflared tunnel route dns android-server files.namaserver.com
```

Perintah ini otomatis membuat **CNAME record** di Cloudflare DNS — tidak perlu buka dashboard manual.

---

## Update config.yml

Pastikan `config.yml` sudah mencantumkan hostname yang baru didaftarkan:

```bash
cat ~/.cloudflared/config.yml
```

Isi yang diharapkan:

```yaml
tunnel: <TUNNEL_ID>
credentials-file: /root/.cloudflared/<TUNNEL_ID>.json

loglevel: info

ingress:
  - hostname: api.namaserver.com      # ganti dengan domain kamu
    service: http://localhost:80
  - hostname: files.namaserver.com    # ganti dengan domain kamu
    service: http://localhost:8080
  - service: http_status:404
```

Restart tunnel agar config baru terbaca:

```bash
pm2 restart cloudflared
```

---

## Verifikasi Domain

```bash
# Tunggu 1–5 menit setelah DNS dibuat, lalu cek:
curl -I https://api.namaserver.com
# Harus: HTTP/2 200

# Cek SSL
curl -v https://api.namaserver.com 2>&1 | grep "SSL connection"
# Harus: SSL connection using TLSv1.3
```

Atau buka dari browser menggunakan data seluler (bukan WiFi yang sama) untuk memastikan akses dari luar jaringan lokal.

---

## Tips Tambahan

- **SSL/TLS otomatis** — Cloudflare menyediakan HTTPS tanpa perlu setup Let's Encrypt manual
- **Domain apex** — Jika ingin `namaserver.com` tanpa subdomain, tambahkan di `config.yml` dengan hostname `namaserver.com` dan jalankan:
  ```bash
  cloudflared tunnel route dns android-server namaserver.com
  ```
- **Proteksi login** — Untuk proteksi akses ke subdomain tertentu, aktifkan **Cloudflare Access** (lihat [Tips & Best Practices](./tips-dan-best-practices.md#keamanan))

---

## 🔒 Security Tips

### Aktifkan SSL/TLS Mode Full (Strict)

Cloudflare default menggunakan mode "Flexible" yang hanya enkripsi koneksi browser → Cloudflare, tapi tidak ke server. Ganti ke **Full (Strict)** untuk enkripsi end-to-end:

Di [Cloudflare Dashboard](https://dash.cloudflare.com):
1. Pilih domain → **SSL/TLS** → **Overview**
2. Ganti mode dari **Flexible** ke **Full** atau **Full (Strict)**

> Untuk Full (Strict), tunnel cloudflared sudah menangani sertifikat dari sisi server secara otomatis — kamu tidak perlu setup Let's Encrypt manual.

### Aktifkan HSTS

HSTS (HTTP Strict Transport Security) memaksa browser selalu pakai HTTPS:

1. Cloudflare Dashboard → **SSL/TLS** → **Edge Certificates**
2. **HTTP Strict Transport Security (HSTS)** → Enable
3. Max Age: `6 months` untuk mulai, naikkan ke `1 year` setelah yakin HTTPS stabil
4. Centang **Include subdomains** jika semua subdomain pakai HTTPS

### Aktifkan Bot Fight Mode

Blokir traffic dari bot scraper dan scanner otomatis secara gratis:

1. Cloudflare Dashboard → **Security** → **Bots**
2. **Bot Fight Mode** → On

### Nonaktifkan Subdomain yang Tidak Dipakai

Setiap CNAME aktif di DNS adalah attack surface potensial. Hapus DNS record yang tidak lagi dipakai:

1. Cloudflare Dashboard → **DNS** → **Records**
2. Hapus CNAME yang sudah tidak ada service-nya

### Aktifkan Always Use HTTPS

Pastikan semua request HTTP di-redirect otomatis ke HTTPS:

1. Cloudflare Dashboard → **SSL/TLS** → **Edge Certificates**
2. **Always Use HTTPS** → On

### Minimum TLS Version

Nonaktifkan TLS lama (TLS 1.0 dan 1.1) yang sudah tidak aman:

1. Cloudflare Dashboard → **SSL/TLS** → **Edge Certificates**
2. **Minimum TLS Version** → **TLS 1.2**

---

## ✅ Checklist Phase 4

```
[ ] Domain terdaftar di Cloudflare, status "Active"
[ ] Nameserver registrar sudah diganti ke Cloudflare
[ ] cloudflared tunnel route dns berhasil untuk setiap subdomain
[ ] config.yml sudah berisi hostname yang benar
[ ] pm2 restart cloudflared berhasil
[ ] https://api.namaserver.com bisa diakses dari data seluler
[ ] HTTPS (TLS) berjalan tanpa error sertifikat
```

---

[← Phase 3: Expose ke Internet](./fase-3-expose-internet.md) | [Kembali ke README](../README.md) | [Phase 5: Remote SSH →](./fase-5-remote-ssh.md)
