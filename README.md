# Kanzan Android Mini Server

Mengubah HP Android bekas menjadi server sungguhan — bisa diakses dari internet, menjalankan API, bahkan jadi cloud storage pribadi pengganti Google Drive. Semua ini tanpa root, tanpa biaya VPS, dan tanpa port forwarding di router.

Panduan ini membawa kamu dari HP kosong sampai server yang bisa diakses via URL HTTPS dari mana saja di dunia.

---

## Cara Kerja & Arsitektur

```
Internet
    │
    ▼
[Cloudflare Edge Network]  ← enkripsi TLS, DDoS protection, routing domain
    │
    ▼
[cloudflared daemon]       ← koneksi outbound dari HP, tidak perlu buka port
    │
    ▼
[Ubuntu PRoot]             ← Linux environment lengkap di dalam Termux
    ├── Nginx :80           ← web server / reverse proxy
    │     ├── /             → Node.js API (port 3000)
    │     └── /files        → Filebrowser (port 8080)
    ├── Node.js + Express :3000  ← Use Case A: API / Web Server
    ├── Filebrowser :8080        ← Use Case B: Cloud Storage Pribadi
    └── pm2                      ← process manager, keep services alive
    │
[Termux]                   ← terminal emulator, host untuk Ubuntu PRoot
    │
[HP Android]               ← hardware, charging terus saat jadi server
```

**Alur request dari internet:**
1. User akses `https://api.kamu.com` dari mana saja
2. Request masuk ke Cloudflare Edge → diteruskan via tunnel ke `cloudflared` di HP
3. `cloudflared` forward ke Nginx di port 80
4. Nginx routing ke service yang tepat (Node.js atau Filebrowser)
5. Response balik ke user via jalur yang sama

**Kenapa tidak butuh root atau port forwarding?**
- `cloudflared` membuat koneksi *outbound* dari HP ke Cloudflare — bukan menunggu koneksi masuk
- PRoot mensimulasikan Linux environment tanpa privilege root Android
- Hasilnya: setup yang aman, tidak mengubah sistem Android, dan bisa diuninstall kapan saja

---

## Perbandingan: HP Android vs Raspberry Pi vs VPS

| Kriteria | HP Android Bekas | Raspberry Pi 4 | VPS (entry level) |
|----------|-----------------|----------------|-------------------|
| **Biaya hardware** | Rp 0 (pakai HP bekas) | Rp 500rb–900rb | Rp 0 (sewa) |
| **Biaya operasional** | Listrik ~5–10W | Listrik ~5–8W | Rp 50rb–200rb/bln |
| **Setup complexity** | Mudah (panduan ini) | Sedang | Mudah |
| **Performa** | Cukup (Snapdragon/Dimensity) | Cukup (ARM Cortex-A72) | Bergantung plan |
| **Uptime** | Butuh charging terus | Butuh power supply stabil | 99.9% (managed) |
| **Static IP** | Tidak (via Cloudflare Tunnel) | Tidak (via Cloudflare Tunnel) | Ya |
| **Root diperlukan** | ❌ Tidak | ❌ Tidak (headless) | ❌ Tidak |
| **Cocok untuk** | Belajar, hobby, side project | Hobby, IoT, home server | Produksi, traffic tinggi |

> **Kesimpulan:** HP Android bekas adalah pilihan terbaik untuk belajar server, side project, atau proof of concept tanpa keluar biaya bulanan.

---

## Hardware yang Direkomendasikan

| Komponen | Minimum | Direkomendasikan |
|----------|---------|-----------------|
| **RAM** | 4 GB | 6 GB+ |
| **Storage internal** | 32 GB | 64 GB+ |
| **Android version** | Android 7 | Android 10+ |
| **Prosesor** | Octa-core | Snapdragon 7xx / Dimensity 8xxx |
| **Charger** | Bawaan HP | Charger fast charging (HP menyala terus) |

> Tips: Gunakan HP yang sudah tidak dipakai aktif sebagai dedicated server. Lepas SIM card jika tidak dibutuhkan, dan tempatkan di lokasi berventilasi baik.

---

## Quick Start

Langkah-langkah dari HP kosong ke server yang bisa diakses dari internet:

1. **[Phase 0](./docs/fase-0-persiapan-termux.md)** — Install Termux via F-Droid, setup wakelock & battery optimization *(±15–30 menit)*
2. **[Phase 1](./docs/fase-1-setup-ubuntu.md)** — Install Ubuntu di dalam Termux via proot-distro *(±20–40 menit)*
3. **[Phase 2](./docs/fase-2-fondasi-server.md)** — Install Nginx, Node.js, dan pm2 sebagai fondasi server *(±20–30 menit)*
4. **[Phase 3](./docs/fase-3-expose-internet.md)** + **[Phase 4](./docs/fase-4-domain-custom.md)** — Expose ke internet via Cloudflare Tunnel + pasang domain custom *(±45–75 menit)*
5. **[Phase 5](./docs/fase-5-remote-ssh.md)** *(opsional)* — Remote Termux via SSH dari komputer atau internet *(±20–30 menit)*
6. **[Phase 6](./docs/fase-6-remote-gui.md)** *(opsional)* — Akses server via GUI browser: Webmin (mirip cPanel) atau VS Code *(±30–45 menit)*
7. **[Phase 7](./docs/fase-7-web-server-api.md)** atau **[Phase 8](./docs/fase-8-cloud-storage.md)** — Pilih use case: API server ([Express](./docs/api-express.md) / [Gin](./docs/api-gin.md) / [FastAPI](./docs/api-fastapi.md) / [Ktor](./docs/api-ktor.md)) atau cloud storage ([Filebrowser](./docs/storage-filebrowser.md) / [Cloudreve](./docs/storage-cloudreve.md)) *(±20–60 menit)*

---

## Dokumentasi Lengkap

### Setup Bertahap

| Fase | Topik | Estimasi |
|------|-------|----------|
| [Phase 0](./docs/fase-0-persiapan-termux.md) | Persiapan & Install Termux | 15–30 menit |
| [Phase 1](./docs/fase-1-setup-ubuntu.md) | Setup Ubuntu via PRoot | 20–40 menit |
| [Phase 2](./docs/fase-2-fondasi-server.md) | Fondasi Server — Nginx + Node.js | 20–30 menit |
| [Phase 3](./docs/fase-3-expose-internet.md) | Expose ke Internet via Cloudflare Tunnel | 30–45 menit |
| [Phase 4](./docs/fase-4-domain-custom.md) | Setup Domain Custom | 15–30 menit |
| [Phase 5](./docs/fase-5-remote-ssh.md) | Remote Access via SSH *(opsional)* | 20–30 menit |
| [Phase 6](./docs/fase-6-remote-gui.md) | Remote Access via GUI — Webmin & code-server *(opsional)* | 30–45 menit |
| [Phase 7](./docs/fase-7-web-server-api.md) | Use Case A — Web Server & API | 30–60 menit |
| ↳ [Node.js + Express](./docs/api-express.md) | API dengan Express (default) | — |
| ↳ [Go + Gin](./docs/api-gin.md) | API dengan Gin (performa terbaik) | — |
| ↳ [Python + FastAPI](./docs/api-fastapi.md) | API dengan FastAPI (termudah) | — |
| ↳ [Kotlin + Ktor](./docs/api-ktor.md) | API dengan Ktor (Android developer) | — |
| [Phase 8](./docs/fase-8-cloud-storage.md) | Use Case B — Cloud Storage Pribadi | 20–120 menit |
| ↳ [Filebrowser](./docs/storage-filebrowser.md) | Storage ringan (default) | — |
| ↳ [Cloudreve](./docs/storage-cloudreve.md) | Storage mirip Google Drive | — |
| ↳ [Nextcloud](./docs/storage-nextcloud.md) | Full Google Workspace replacement | — |

### Referensi

| Dokumen | Isi |
|---------|-----|
| [Troubleshooting](./docs/troubleshooting.md) | 11 kasus error umum + solusi |
| [Tips & Best Practices](./docs/tips-dan-best-practices.md) | Keamanan, performa, backup, limitasi, kapan pakai VPS |

---

## Referensi Eksternal

- [F-Droid](https://f-droid.org) — App store untuk Termux
- [Termux Wiki](https://wiki.termux.com) — Dokumentasi resmi
- [proot-distro GitHub](https://github.com/termux/proot-distro)
- [Nginx Documentation](https://nginx.org/en/docs/)
- [Node.js via NodeSource](https://github.com/nodesource/distributions)
- [pm2 Documentation](https://pm2.keymetrics.io/docs/)
- [Filebrowser GitHub Releases](https://github.com/filebrowser/filebrowser/releases)
- [cloudflared GitHub Releases](https://github.com/cloudflare/cloudflared/releases)
- [Cloudflare Tunnel Documentation](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/)
- [Cloudflare Zero Trust Access](https://developers.cloudflare.com/cloudflare-one/applications/)
- [Webmin Documentation](https://webmin.com/docs/)
- [code-server GitHub](https://github.com/coder/code-server)
- [Gin Web Framework](https://gin-gonic.com/docs/)
- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [Ktor Documentation](https://ktor.io/docs/)
- [Cloudreve Documentation](https://docs.cloudreve.org/)
- [Nextcloud Documentation](https://docs.nextcloud.com/)

---

## Credit

Panduan ini terinspirasi dari sharing session oleh [**@icksannugrahaa**](https://github.com/icksannugrahaa) — terima kasih sudah berbagi ilmu dan pengalaman setup Android sebagai server. 🙏

---

## License

MIT License — see [LICENSE](LICENSE) for details.

## Contributing

Lihat [CONTRIBUTING.md](.github/CONTRIBUTING.md) untuk panduan kontribusi.

---

*Last Updated: Oktober 2026*
