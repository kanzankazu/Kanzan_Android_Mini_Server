# Setup Wizard Scripts

Dua script interaktif untuk setup otomatis dari HP Android kosong ke server yang bisa diakses dari internet, termasuk MCP server untuk AI agent.

---

## Struktur

```
scripts/
├── setup-termux.sh   ← Jalankan di Termux   (Phase 0 + 1)
└── setup-ubuntu.sh   ← Jalankan di Ubuntu   (Phase 2 + 3 + MCP)
```

> ⚠️ **Urutan penting** — `setup-termux.sh` harus selesai dulu sebelum `setup-ubuntu.sh`.

---

## Cara Pakai

### 1. `setup-termux.sh` — Di Termux

**Apa yang dilakukan:**
- Phase 0: Update Termux, install paket dasar, setup storage permission, prep SSH
- Phase 1: Install proot-distro, install Ubuntu, update apt, buat alias `ubuntu`

**Jalankan:**
```bash
# Download & jalankan langsung
curl -fsSL https://raw.githubusercontent.com/username/Kanzan_Android_Mini_Server/main/scripts/setup-termux.sh | bash

# Atau download dulu, review, baru jalankan (lebih aman)
wget https://raw.githubusercontent.com/username/Kanzan_Android_Mini_Server/main/scripts/setup-termux.sh
cat setup-termux.sh   # review isinya
bash setup-termux.sh
```

**Estimasi waktu:** 30–60 menit (tergantung koneksi)

**Setelah selesai:**
```bash
source ~/.bashrc   # aktifkan alias
ubuntu             # masuk ke Ubuntu
```

---

### 2. `setup-ubuntu.sh` — Di Ubuntu PRoot

**Apa yang dilakukan:**
- Phase 2: Install Nginx, Node.js LTS, npm, pm2, security headers
- Phase 3: Download cloudflared (ARM64), setup Cloudflare Tunnel (quick atau permanen)
- Bonus: Install MCP server agar AI agent (Kiro/Claude/Cursor) bisa akses server

**Jalankan (di dalam Ubuntu):**
```bash
# Pastikan sudah di dalam Ubuntu dulu!
curl -fsSL https://raw.githubusercontent.com/username/Kanzan_Android_Mini_Server/main/scripts/setup-ubuntu.sh | bash
```

**Estimasi waktu:** 20–45 menit

**Pilihan mode tunnel yang akan ditawarkan:**

| Mode | Cocok untuk | URL |
|------|-------------|-----|
| Quick Tunnel | Testing, belum punya domain | `https://xxx.trycloudflare.com` (berubah tiap restart) |
| Tunnel Permanen | Produksi, sudah punya domain | `https://api.domain.com` (stabil) |

**Output yang dihasilkan:**
- Semua service berjalan via `pm2`
- File `~/mcp-server/SETUP_INFO.txt` berisi URL, API key, dan config siap pakai untuk Kiro

---

## Setelah Setup Selesai

### Cek status semua service

```bash
pm2 list
```

Output yang diharapkan:
```
┌──────────────────┬────────┬──────────┐
│ Name             │ Status │ Restarts │
├──────────────────┼────────┼──────────┤
│ cloudflared      │ online │ 0        │
│ mcp-server       │ online │ 0        │
└──────────────────┴────────┴──────────┘
```

### Lihat info MCP server

```bash
cat ~/mcp-server/SETUP_INFO.txt
```

File ini berisi URL endpoint, API key, dan konfigurasi JSON siap copy-paste ke Kiro.

### Hubungkan ke Kiro (AI Agent)

Copy isi `SETUP_INFO.txt` bagian "Kiro mcp.json config" ke file `.kiro/settings/mcp.json` di project kamu.

Setelah itu Kiro bisa:
- Jalankan shell command di HP kamu
- Baca & tulis file
- Monitor CPU/RAM/disk/pm2
- Deploy kode langsung dari chat

---

## Troubleshooting

**Script berhenti karena error?**

Sebagian besar error bisa di-fix dengan jalankan ulang — script dirancang idempotent (aman dijalankan berkali-kali).

**cloudflared gagal download?**

```bash
# Download manual
wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64 \
  -O /usr/local/bin/cloudflared
chmod +x /usr/local/bin/cloudflared
```

**MCP server tidak merespon?**

```bash
pm2 logs mcp-server --lines 50
# Restart jika perlu
pm2 restart mcp-server
```

**Tunnel tidak connect?**

```bash
pm2 logs cloudflared --lines 30
# Cek apakah ada "Connection established"
```

Untuk error lain, lihat [docs/troubleshooting.md](../docs/troubleshooting.md).

---

[← Kembali ke README](../README.md)
