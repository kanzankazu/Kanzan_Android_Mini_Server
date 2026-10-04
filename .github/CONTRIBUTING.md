# Contributing to Kanzan Android Mini Server

Terima kasih sudah tertarik untuk berkontribusi! Panduan ini menjelaskan cara melaporkan bug, mengusulkan fitur, dan submit pull request.

---

## 📋 Daftar Isi

- [Melaporkan Bug](#melaporkan-bug)
- [Mengusulkan Fitur](#mengusulkan-fitur)
- [Setup Development](#setup-development)
- [Alur Pull Request](#alur-pull-request)
- [Checklist PR](#checklist-pr)

---

## Melaporkan Bug

Buka [Issues](../../issues) dan gunakan template **Bug Report**. Sertakan:

- Langkah untuk reproduksi bug
- Output error yang muncul (screenshot atau copy-paste teks)
- Informasi device: model HP, versi Android, versi Termux
- Versi tools yang dipakai: `node --version`, `nginx -v`, `cloudflared --version`

---

## Mengusulkan Fitur

Buka [Issues](../../issues) dengan label **enhancement**. Jelaskan:

- Use case yang ingin diselesaikan
- Pendekatan yang kamu usulkan
- Apakah ada alternatif yang sudah kamu pertimbangkan

---

## Setup Development

Repo ini berisi panduan (dokumentasi), bukan kode executable. Untuk berkontribusi pada konten:

```bash
# Clone repo
git clone https://github.com/kanzankazu/Kanzan_Android_Mini_Server.git
cd Kanzan_Android_Mini_Server

# Edit file markdown yang relevan
# README.md — panduan utama
# Folder dokumentasi lain jika ada
```

Untuk menguji perubahan secara lokal, kamu bisa preview markdown menggunakan:
- VS Code dengan ekstensi Markdown Preview
- `grip` (pip install grip) untuk preview di browser

---

## Alur Pull Request

1. Fork repo ini
2. Buat branch baru dari `main`:
   ```bash
   git checkout -b fix/typo-phase-2
   # atau
   git checkout -b feat/tambah-use-case-database
   ```
3. Buat perubahan
4. Commit dengan pesan yang jelas:
   ```bash
   git commit -m "fix: typo pada konfigurasi Nginx Phase 3"
   # atau
   git commit -m "docs: tambah troubleshooting untuk Xiaomi MIUI"
   ```
5. Push dan buka Pull Request ke branch `main`

---

## Checklist PR

Sebelum submit, pastikan:

- [ ] Perubahan sudah ditest (panduan bisa diikuti dari awal sampai akhir tanpa error)
- [ ] Markdown valid — tidak ada broken link atau formatting rusak
- [ ] Perintah shell sudah diverifikasi berjalan di Termux/Ubuntu PRoot (ARM64)
- [ ] Tidak ada informasi sensitif yang ter-commit (credential, token, dsb)
- [ ] Judul PR jelas menggambarkan apa yang berubah

---

## Konvensi Penulisan

- Bahasa: **Bahasa Indonesia** untuk teks penjelasan, **Inggris** untuk kode dan command
- Gunakan code block ` ```bash ` untuk semua perintah terminal
- Sertakan komentar pada setiap blok kode yang tidak self-explanatory
- Checklist di akhir setiap phase harus tetap ter-update jika ada perubahan langkah

---

Pertanyaan? Buka [Discussion](../../discussions) atau hubungi [kanzankazu46@gmail.com](mailto:kanzankazu46@gmail.com).
