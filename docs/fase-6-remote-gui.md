# Phase 8 — Remote Access via GUI (Browser-Based)

Kelola server dari browser tanpa perlu terminal. Fase ini mencakup dua opsi GUI:

- **Webmin** — panel administrasi server mirip cPanel (manage services, files, database, user)
- **code-server** — VS Code di browser untuk development dan edit konfigurasi

Keduanya bisa diakses dari internet via Cloudflare Tunnel yang sudah ada.

**Estimasi waktu:** 30–45 menit

---

## Prasyarat

- Phase 0–2 sudah selesai (Termux + Ubuntu PRoot + Nginx berjalan)
- Phase 5 sudah selesai (Cloudflare Tunnel aktif)
- Phase 7 sudah selesai (opsional, tapi berguna untuk troubleshooting via terminal)

---

## Opsi yang Tersedia

| Opsi | Fungsi | Mirip | RAM |
|------|--------|-------|-----|
| [A] Webmin | Server management panel | cPanel / Plesk | ~150 MB |
| [B] code-server | IDE berbasis browser | VS Code | ~300 MB |

Pilih salah satu atau keduanya sesuai kebutuhan.

---

## Opsi A — Webmin (Panel Mirip cPanel)

Webmin adalah panel administrasi server berbasis web. Dari satu dashboard kamu bisa manage Nginx, database, file manager, cron jobs, user, dan banyak lagi.

### Fitur Utama Webmin

- ✅ File manager (upload, download, edit, hapus file)
- ✅ Manage Nginx virtual hosts
- ✅ Database manager (MySQL/MariaDB)
- ✅ Cron job scheduler
- ✅ User & group management
- ✅ System monitor (CPU, RAM, disk)
- ✅ Log viewer
- ✅ SSL certificate manager

### 1. Install Webmin di Ubuntu PRoot

Masuk ke Ubuntu PRoot terlebih dahulu:

```bash
# Di Termux
proot-distro login ubuntu
```

Tambahkan repository Webmin dan install:

```bash
# Tambah GPG key
curl -fsSL https://download.webmin.com/jcameron-key.asc | gpg --dearmor -o /usr/share/keyrings/webmin.gpg

# Tambah repository
echo "deb [signed-by=/usr/share/keyrings/webmin.gpg] https://download.webmin.com/download/repository sarge contrib" \
  > /etc/apt/sources.list.d/webmin.list

# Install
apt update
apt install webmin -y
```

### 2. Start Webmin

```bash
service webmin start
```

Verifikasi Webmin berjalan:

```bash
service webmin status
# atau
curl -sk https://localhost:10000 | head -5
```

### 3. Set Password Webmin

Webmin menggunakan user sistem Linux. Set password untuk user `root`:

```bash
/usr/share/webmin/changepass.pl /etc/webmin root passwordbaru
```

Ganti `passwordbaru` dengan password pilihan kamu.

### 4. Expose Webmin via Cloudflare Tunnel

Tambahkan entry baru di konfigurasi cloudflared:

```bash
nano ~/.cloudflared/config.yml
```

Tambahkan di bagian `ingress`:

```yaml
ingress:
  # Entry yang sudah ada:
  - hostname: api.kamu.com
    service: http://localhost:80

  # Tambahkan Webmin:
  - hostname: panel.kamu.com
    service: https://localhost:10000
    originRequest:
      noTLSVerify: true   # Webmin pakai self-signed cert, ini wajib

  - service: http_status:404
```

> `noTLSVerify: true` diperlukan karena Webmin menggunakan sertifikat SSL self-signed secara default. Koneksi dari Cloudflare ke Webmin tetap terenkripsi, hanya verifikasi certificate yang dilewati.

### 5. Tambah DNS Record

Di [Cloudflare Dashboard](https://dash.cloudflare.com):
1. Pilih domain → **DNS** → **Add record**
2. Type: `CNAME`
3. Name: `panel`
4. Target: `<tunnel-id>.cfargotunnel.com`
5. Proxy status: **Proxied**

### 6. Restart Tunnel & Test Akses

```bash
pm2 restart cloudflared
```

Buka browser, akses `https://panel.kamu.com` → login dengan user `root` dan password yang sudah diset.

### 7. Auto-start Webmin saat Boot

Tambahkan Webmin ke script boot Termux:

```bash
# Di Termux, edit script boot
nano ~/.termux/boot/start-ssh.sh
```

Tambahkan baris `service webmin start` di bagian Ubuntu PRoot:

```bash
proot-distro login ubuntu -- bash -c "
  service nginx start
  service webmin start
  pm2 resurrect
"
```

---

## Opsi B — code-server (VS Code di Browser)

code-server menjalankan VS Code sebagai aplikasi web. Cocok untuk development, edit file konfigurasi, dan mengelola project langsung dari browser.

### Fitur Utama code-server

- ✅ VS Code penuh di browser (syntax highlighting, autocomplete, extensions)
- ✅ Terminal terintegrasi
- ✅ File explorer & editor
- ✅ Git integration
- ✅ Install extensions VS Code
- ✅ Akses dari device apapun (laptop, tablet, bahkan HP lain)

### 1. Install code-server di Ubuntu PRoot

Masuk ke Ubuntu PRoot:

```bash
# Di Termux
proot-distro login ubuntu
```

Install code-server:

```bash
curl -fsSL https://code-server.dev/install.sh | sh
```

Proses instalasi memakan waktu 5–10 menit tergantung koneksi.

### 2. Konfigurasi code-server

Edit file konfigurasi:

```bash
mkdir -p ~/.config/code-server
nano ~/.config/code-server/config.yaml
```

Isi konfigurasi:

```yaml
bind-addr: 127.0.0.1:8888
auth: password
password: passwordkamu
cert: false
```

> Gunakan `127.0.0.1` (bukan `0.0.0.0`) agar code-server hanya bisa diakses lewat Cloudflare Tunnel, tidak langsung dari jaringan lokal.

Ganti `passwordkamu` dengan password pilihan kamu.

### 3. Jalankan code-server via pm2

Agar code-server berjalan terus di background:

```bash
pm2 start code-server --name code-server -- --config ~/.config/code-server/config.yaml
pm2 save
```

Verifikasi berjalan:

```bash
pm2 status
curl http://localhost:8888
```

### 4. Expose code-server via Cloudflare Tunnel

Tambahkan entry di konfigurasi cloudflared:

```bash
nano ~/.cloudflared/config.yml
```

```yaml
ingress:
  # Entry yang sudah ada:
  - hostname: api.kamu.com
    service: http://localhost:80

  # Tambahkan code-server:
  - hostname: code.kamu.com
    service: http://localhost:8888

  - service: http_status:404
```

### 5. Tambah DNS Record

Di [Cloudflare Dashboard](https://dash.cloudflare.com):
1. Pilih domain → **DNS** → **Add record**
2. Type: `CNAME`
3. Name: `code`
4. Target: `<tunnel-id>.cfargotunnel.com`
5. Proxy status: **Proxied**

### 6. Restart Tunnel & Test Akses

```bash
pm2 restart cloudflared
```

Buka browser, akses `https://code.kamu.com` → masukkan password yang sudah diset → VS Code terbuka di browser.

### 7. Auto-start code-server saat Boot

code-server sudah dikelola oleh pm2 (`pm2 save` sudah dilakukan), jadi akan nyala otomatis selama pm2 di-resurrect di script boot:

```bash
# Cek isi script boot
cat ~/.termux/boot/start-ssh.sh
# Pastikan ada baris: pm2 resurrect
```

---

## 🔒 Security Tips

### Generate Password Kuat untuk Setiap Panel

Jangan gunakan password yang sama untuk Webmin dan code-server. Generate unik untuk masing-masing:

```bash
# Generate password acak 32 karakter
openssl rand -base64 32

# Jalankan dua kali — satu untuk Webmin, satu untuk code-server
openssl rand -base64 32
```

Simpan di password manager (Bitwarden, KeePass, dll) — jangan tulis di file plain text di server.

### Hardening Webmin

Setelah Webmin berjalan, lakukan konfigurasi keamanan berikut:

**Batasi akses IP (jika akses dari IP tetap):**
1. Webmin → **Webmin Configuration** → **IP Access Control**
2. Tambahkan IP yang diizinkan
3. Atau biarkan kosong dan andalkan Cloudflare Zero Trust (lebih fleksibel)

**Aktifkan Two-Factor Authentication di Webmin:**
1. Webmin → **Webmin Configuration** → **Two-Factor Authentication**
2. Pilih **Google Authenticator**
3. Scan QR code dengan app authenticator di HP lain

**Nonaktifkan modul Webmin yang tidak dipakai:**
1. Webmin → **Webmin Configuration** → **Webmin Modules**
2. Nonaktifkan modul yang tidak relevan (contoh: modul untuk service yang tidak diinstall)

### Proteksi code-server

Pastikan code-server hanya bisa diakses via tunnel, tidak dari jaringan lokal langsung:

```bash
# Verifikasi bind address hanya 127.0.0.1
grep "bind-addr" ~/.config/code-server/config.yaml
# Harus: bind-addr: 127.0.0.1:8888
```

Aktifkan juga autentikasi password yang kuat:

```bash
# Ganti password code-server
nano ~/.config/code-server/config.yaml
# Update baris: password: <password-baru-yang-kuat>

pm2 restart code-server
```

### Wajib: Cloudflare Zero Trust Access untuk Semua Panel

Ini lapisan proteksi paling penting — tanpanya, siapapun yang tahu URL panel bisa mencoba login.

Pasang Cloudflare Zero Trust Access untuk **setiap** panel yang diekspos:

```
Cloudflare Zero Trust Dashboard (one.dash.cloudflare.com)
  → Access → Applications → Add an application
  → Self-hosted
  → Application domain: panel.kamu.com
  → Policy name: "Only Me"
  → Include: Emails → kamu@gmail.com
```

Ulangi untuk `code.kamu.com` dan subdomain panel lainnya. Sekarang setiap akses ke panel akan meminta verifikasi email OTP dari Cloudflare dulu, bahkan sebelum halaman login panel muncul.

### Monitor Log Akses Panel

Cek siapa saja yang mengakses panel dari Cloudflare Zero Trust:

1. Cloudflare Zero Trust Dashboard → **Access** → **Logs**
2. Filter per application untuk melihat riwayat login

---

## Setup Keduanya Sekaligus

Jika ingin pasang Webmin dan code-server bersamaan, konfigurasi lengkap cloudflared-nya:

```yaml
tunnel: <tunnel-id-kamu>
credentials-file: /root/.cloudflared/<tunnel-id>.json

ingress:
  - hostname: api.kamu.com
    service: http://localhost:80

  - hostname: files.kamu.com
    service: http://localhost:8080

  - hostname: panel.kamu.com
    service: https://localhost:10000
    originRequest:
      noTLSVerify: true

  - hostname: code.kamu.com
    service: http://localhost:8888

  - hostname: ssh.kamu.com
    service: ssh://localhost:8022

  - service: http_status:404
```

Dan script boot lengkap di Termux (`~/.termux/boot/start-ssh.sh`):

```bash
#!/data/data/com.termux/files/usr/bin/bash

termux-wake-lock
sleep 5

# Start SSH server di Termux
sshd

# Start semua services di Ubuntu PRoot
proot-distro login ubuntu -- bash -c "
  service nginx start
  service webmin start
  pm2 resurrect
"
```

---

## Ringkasan Akses

Setelah setup selesai, kamu punya akses penuh ke server dari browser:

| URL | Fungsi |
|-----|--------|
| `https://api.kamu.com` | API / Web server utama |
| `https://files.kamu.com` | File manager (Filebrowser) |
| `https://panel.kamu.com` | Server management panel (Webmin) |
| `https://code.kamu.com` | VS Code di browser (code-server) |
| `ssh.kamu.com` | SSH terminal (via cloudflared client) |

---

## Keamanan

> ⚠️ Panel seperti Webmin dan code-server adalah pintu masuk ke seluruh server. Jangan skip langkah keamanan ini.

### Proteksi Tambahan via Cloudflare Access

Cloudflare Zero Trust Access bisa menambahkan layer login (email OTP, Google, GitHub) di depan semua panel sebelum user bisa mengaksesnya.

1. Buka [Cloudflare Zero Trust Dashboard](https://one.dash.cloudflare.com)
2. **Access** → **Applications** → **Add an application**
3. Pilih **Self-hosted**
4. Set hostname: `panel.kamu.com` (atau `code.kamu.com`)
5. Tambahkan policy: hanya email kamu yang boleh akses

Dengan ini, bahkan jika seseorang tahu URL panel kamu, mereka tetap harus login via Cloudflare dulu.

### Password yang Kuat

```bash
# Generate password acak yang kuat
openssl rand -base64 24
```

---

## Troubleshooting

**Webmin tidak bisa diakses via tunnel:**
```bash
# Cek Webmin berjalan
service webmin status

# Cek port
ss -tlnp | grep 10000
```

**code-server error saat start:**
```bash
# Lihat log
pm2 logs code-server

# Restart
pm2 restart code-server
```

**Tunnel tidak routing ke panel:**
```bash
# Validasi config cloudflared
cloudflared tunnel ingress validate

# Lihat log tunnel
pm2 logs cloudflared
```

---

## Langkah Selanjutnya

- **[Tips & Best Practices](./tips-dan-best-practices.md)** — Keamanan, performa, backup, dan kapan saatnya pindah ke VPS
- **[Troubleshooting](./troubleshooting.md)** — Solusi error umum

---

[← Phase 5: Remote SSH](./fase-5-remote-ssh.md) | [Kembali ke README](../README.md) | [Phase 7: Web Server & API →](./fase-7-web-server-api.md)
