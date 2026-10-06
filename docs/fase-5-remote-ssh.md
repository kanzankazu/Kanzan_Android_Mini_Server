# Phase 7 — Remote Access via SSH

Akses Termux dari komputer atau perangkat lain tanpa harus menyentuh HP. Dengan SSH, kamu bisa mengelola server sepenuhnya dari jarak jauh — baik di jaringan lokal maupun dari internet.

**Estimasi waktu:** 20–30 menit

---

## Prasyarat

- Phase 0–2 sudah selesai (Termux + Ubuntu PRoot + server berjalan)
- Phase 5 sudah selesai jika ingin akses dari internet (Cloudflare Tunnel aktif)
- HP terhubung ke WiFi yang sama dengan komputer (untuk akses lokal)

---

## Opsi Remote SSH

| Opsi | Jangkauan | Kesulitan |
|------|-----------|-----------|
| [A] SSH Lokal | LAN / WiFi sama | ⭐ Mudah |
| [B] SSH via Cloudflare Tunnel | Dari mana saja | ⭐⭐ Sedang |
| [C] Auto-start saat Boot | Otomatisasi | ⭐ Mudah |

---

## Opsi A — SSH di Jaringan Lokal

Cocok untuk akses dari komputer yang terhubung ke WiFi yang sama dengan HP.

### 1. Install OpenSSH di Termux

Buka Termux di HP, lalu jalankan:

```bash
pkg update && pkg upgrade -y
pkg install openssh -y
```

### 2. Set Password Termux

SSH membutuhkan password untuk autentikasi:

```bash
passwd
# Masukkan password baru (minimal 6 karakter)
# Konfirmasi password
```

### 3. Jalankan SSH Server

```bash
sshd
```

SSH server berjalan di **port 8022** (bukan 22, karena port di bawah 1024 butuh root).

### 4. Cari IP Address HP

```bash
ip addr show | grep 'inet ' | grep -v '127.0.0.1'
# Contoh output: inet 192.168.1.105/24
```

Atau lihat di **Pengaturan WiFi HP** → detail jaringan → IP address.

### 5. Koneksi dari Komputer

```bash
# Dari terminal komputer (Linux/macOS)
ssh <username>@<IP-HP> -p 8022

# Contoh:
ssh u0_a123@192.168.1.105 -p 8022
```

> **Catatan:** Username di Termux biasanya `u0_a<angka>`. Cek dengan perintah `whoami` di Termux.

### 6. Verifikasi Koneksi

Setelah berhasil login, coba:

```bash
whoami
ls ~
# Kamu sekarang mengontrol Termux dari komputer
```

---

## Opsi B — SSH dari Internet via Cloudflare Tunnel

Akses HP dari mana saja di dunia tanpa IP publik atau port forwarding. Metode ini menggunakan Cloudflare Tunnel yang sudah dipasang di Phase 5.

### 1. Pastikan OpenSSH Terinstall

Lakukan langkah 1–3 dari Opsi A terlebih dahulu (install openssh, set password, jalankan sshd).

### 2. Tambah SSH Tunnel di Cloudflare

Edit file konfigurasi Cloudflare Tunnel. Masuk ke Ubuntu PRoot dulu:

```bash
# Di Termux
proot-distro login ubuntu

# Cari file config cloudflared
cat ~/.cloudflared/config.yml
```

Tambahkan entry SSH di bawah entry yang sudah ada:

```yaml
tunnel: <tunnel-id-kamu>
credentials-file: /root/.cloudflared/<tunnel-id>.json

ingress:
  # Entry yang sudah ada (contoh):
  - hostname: api.kamu.com
    service: http://localhost:80

  # Tambahkan ini:
  - hostname: ssh.kamu.com
    service: ssh://localhost:8022

  - service: http_status:404
```

### 3. Tambah DNS Record di Cloudflare

Di [Cloudflare Dashboard](https://dash.cloudflare.com):
1. Pilih domain kamu → **DNS** → **Add record**
2. Type: `CNAME`
3. Name: `ssh`
4. Target: `<tunnel-id>.cfargotunnel.com`
5. Proxy status: **Proxied** (awan oranye)

### 4. Restart Cloudflare Tunnel

```bash
# Di Ubuntu PRoot
pm2 restart cloudflared
# atau
pm2 stop cloudflared && pm2 start cloudflared
```

### 5. Install cloudflared di Komputer Client

Komputer yang akan digunakan untuk SSH harus punya `cloudflared`:

**macOS:**
```bash
brew install cloudflare/cloudflare/cloudflared
```

**Linux (Debian/Ubuntu):**
```bash
curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb -o cloudflared.deb
sudo dpkg -i cloudflared.deb
```

**Windows:**
```powershell
winget install Cloudflare.cloudflared
```

### 6. Koneksi SSH via Tunnel

```bash
ssh -o ProxyCommand="cloudflared access ssh --hostname ssh.kamu.com" u0_a123@ssh.kamu.com
```

Agar tidak perlu mengetik panjang setiap saat, tambahkan ke `~/.ssh/config` di komputer:

```
Host android-server
    HostName ssh.kamu.com
    User u0_a123
    Port 22
    ProxyCommand cloudflared access ssh --hostname %h
```

Sekarang cukup ketik:

```bash
ssh android-server
```

---

## Opsi C — Auto-start SSH saat HP Boot

Tanpa ini, SSH server mati setiap kali HP restart. Dengan Termux:Boot, sshd nyala otomatis.

### 1. Install Termux:Boot

Download dari [F-Droid](https://f-droid.org/en/packages/com.termux.boot/) — **jangan dari Play Store** (versi lama).

Setelah install, **buka sekali** aplikasi Termux:Boot agar permission ter-register, lalu tutup.

### 2. Buat Script Boot

```bash
# Di Termux
mkdir -p ~/.termux/boot
nano ~/.termux/boot/start-ssh.sh
```

Isi file `start-ssh.sh`:

```bash
#!/data/data/com.termux/files/usr/bin/bash

# Acquire wakelock agar Termux tidak dimatikan sistem
termux-wake-lock

# Tunggu sebentar hingga sistem siap
sleep 5

# Jalankan SSH server
sshd

# Masuk ke Ubuntu PRoot dan jalankan semua services
proot-distro login ubuntu -- bash -c "
  service nginx start
  pm2 resurrect
"
```

### 3. Beri Permission Eksekusi

```bash
chmod +x ~/.termux/boot/start-ssh.sh
```

### 4. Test Script

```bash
bash ~/.termux/boot/start-ssh.sh
```

Pastikan tidak ada error. Sekarang setiap kali HP restart, SSH dan semua service akan nyala otomatis dalam beberapa detik.

---

## Menggunakan SSH Key (Opsional tapi Direkomendasikan)

Password bisa ditebak. SSH key jauh lebih aman.

### 1. Generate SSH Key di Komputer

```bash
ssh-keygen -t ed25519 -C "android-server"
# Simpan di lokasi default (~/.ssh/id_ed25519)
# Passphrase boleh dikosongkan untuk kemudahan
```

### 2. Copy Public Key ke Termux

```bash
# Dari komputer, jika masih di jaringan lokal:
ssh-copy-id -p 8022 u0_a123@192.168.1.105

# Atau manual — tampilkan public key:
cat ~/.ssh/id_ed25519.pub
```

Jika manual, paste isinya ke Termux:

```bash
# Di Termux
mkdir -p ~/.ssh
nano ~/.ssh/authorized_keys
# Paste public key di sini, save
chmod 600 ~/.ssh/authorized_keys
chmod 700 ~/.ssh
```

### 3. Test Login dengan Key

```bash
ssh u0_a123@192.168.1.105 -p 8022
# Seharusnya langsung masuk tanpa password
```

---

## Troubleshooting

**`Connection refused` saat SSH:**
```bash
# Pastikan sshd berjalan di Termux
pgrep sshd || sshd
```

**Lupa username:**
```bash
# Di Termux
whoami
```

**`Host key verification failed`:**
```bash
# Hapus entry lama di komputer
ssh-keygen -R "[IP-HP]:8022"
```

**SSH via tunnel timeout:**
- Pastikan entry `ssh.kamu.com` sudah ada di config cloudflared
- Cek `pm2 status cloudflared` di Ubuntu PRoot
- Verifikasi DNS record di Cloudflare Dashboard

---

## 🔒 Security Tips

### Nonaktifkan Password Auth — Wajib Setelah Setup SSH Key

Setelah SSH key berfungsi (Opsi dari seksi sebelumnya), matikan login via password agar brute force tidak mungkin dilakukan:

```bash
# Di Termux, edit konfigurasi sshd
nano $PREFIX/etc/ssh/sshd_config
```

Cari dan ubah baris berikut (atau tambahkan jika belum ada):

```
PasswordAuthentication no
ChallengeResponseAuthentication no
PermitEmptyPasswords no
```

Restart sshd:

```bash
pkill sshd && sshd
```

Verifikasi — login dari komputer lain tanpa key harus ditolak:

```bash
ssh -o PubkeyAuthentication=no u0_a123@192.168.1.105 -p 8022
# Harus: Permission denied (publickey)
```

> ⚠️ Jangan matikan password auth sebelum memastikan SSH key benar-benar berfungsi. Kalau terkunci, buka Termux langsung di HP untuk mengembalikan konfigurasi.

### Ganti Port SSH dari Default (Opsional)

Port 8022 sudah non-standard, tapi bisa diganti lebih jauh untuk mengurangi noise dari scanner otomatis:

```bash
nano $PREFIX/etc/ssh/sshd_config
# Ganti: Port 8022
# Menjadi: Port 2222 (atau angka lain 1024–65535)
```

Update `~/.ssh/config` di komputer client sesuai port baru.

### Batasi Waktu Idle SSH

Otomatis putus koneksi SSH yang tidak aktif untuk mencegah sesi terbengkalai:

```bash
nano $PREFIX/etc/ssh/sshd_config
```

Tambahkan:

```
ClientAliveInterval 300
ClientAliveCountMax 2
```

Ini akan disconnect sesi yang idle lebih dari 10 menit (300 detik × 2).

### Aktifkan Firewall di Ubuntu PRoot (UFW)

Install dan konfigurasi UFW untuk membatasi koneksi yang masuk:

```bash
# Di Ubuntu PRoot
apt install ufw -y

# Default: tolak semua masuk, izinkan semua keluar
ufw default deny incoming
ufw default allow outgoing

# Izinkan hanya port yang dipakai
ufw allow 80/tcp    # Nginx
ufw allow 8022/tcp  # SSH Termux (dari jaringan lokal)

# Aktifkan (di PRoot, gunakan ufw enable --force)
ufw enable
ufw status verbose
```

> Di PRoot Android, UFW berfungsi sebagai filter tambahan meski tidak sekuat iptables di kernel penuh.

---

## Langkah Selanjutnya

- **[Phase 6](./fase-6-remote-gui.md)** — Akses server via GUI berbasis browser (mirip cPanel)
- **[Tips & Best Practices](./tips-dan-best-practices.md)** — Hardening SSH, firewall, dan keamanan server

---

[← Phase 4: Domain Custom](./fase-4-domain-custom.md) | [Kembali ke README](../README.md) | [Phase 6: Remote GUI →](./fase-6-remote-gui.md)
