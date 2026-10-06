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

## 🤖 Bonus: Hubungkan AI Agent (Kiro/Claude/Cursor) ke Server

Setelah tunnel aktif, kamu bisa memberikan AI agent akses penuh ke server HP Android-mu via **MCP (Model Context Protocol)**. Dengan ini, AI agent bisa membaca file, menjalankan command, deploy kode, dan memonitor server — semuanya langsung dari chat.

### Apa itu MCP?

MCP adalah protokol standar yang memungkinkan AI agent (seperti Kiro, Claude Desktop, Cursor) terhubung ke tool eksternal. Kamu deploy MCP server di HP Android, lalu AI agent connect ke sana via tunnel yang sudah aktif.

### Install Node.js MCP Server di HP Android

```bash
# Pastikan sudah di dalam Ubuntu PRoot
# Buat folder project MCP server
mkdir -p ~/mcp-server && cd ~/mcp-server

# Init project
npm init -y

# Install dependencies
npm install @modelcontextprotocol/sdk express
```

Buat file server utama:

```bash
nano ~/mcp-server/index.js
```

```javascript
#!/usr/bin/env node
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { exec } from "child_process";
import { promisify } from "util";
import fs from "fs/promises";
import path from "path";

const execAsync = promisify(exec);
const server = new McpServer({ name: "android-server", version: "1.0.0" });

// Tool: jalankan shell command
server.tool(
  "run_command",
  "Jalankan shell command di server Android",
  { command: z.string().describe("Shell command yang akan dijalankan") },
  async ({ command }) => {
    try {
      const { stdout, stderr } = await execAsync(command, { timeout: 30000 });
      return { content: [{ type: "text", text: stdout || stderr || "(no output)" }] };
    } catch (err) {
      return { content: [{ type: "text", text: `Error: ${err.message}` }], isError: true };
    }
  }
);

// Tool: baca file
server.tool(
  "read_file",
  "Baca isi file di server Android",
  { file_path: z.string().describe("Path file yang ingin dibaca") },
  async ({ file_path }) => {
    try {
      const content = await fs.readFile(file_path, "utf-8");
      return { content: [{ type: "text", text: content }] };
    } catch (err) {
      return { content: [{ type: "text", text: `Error: ${err.message}` }], isError: true };
    }
  }
);

// Tool: tulis file
server.tool(
  "write_file",
  "Tulis atau buat file di server Android",
  {
    file_path: z.string().describe("Path file tujuan"),
    content: z.string().describe("Konten yang akan ditulis"),
  },
  async ({ file_path, content }) => {
    try {
      await fs.mkdir(path.dirname(file_path), { recursive: true });
      await fs.writeFile(file_path, content, "utf-8");
      return { content: [{ type: "text", text: `File berhasil ditulis: ${file_path}` }] };
    } catch (err) {
      return { content: [{ type: "text", text: `Error: ${err.message}` }], isError: true };
    }
  }
);

// Tool: list direktori
server.tool(
  "list_directory",
  "Lihat isi direktori di server Android",
  { dir_path: z.string().describe("Path direktori").default("/root") },
  async ({ dir_path }) => {
    try {
      const { stdout } = await execAsync(`ls -la "${dir_path}"`);
      return { content: [{ type: "text", text: stdout }] };
    } catch (err) {
      return { content: [{ type: "text", text: `Error: ${err.message}` }], isError: true };
    }
  }
);

// Tool: cek status server
server.tool(
  "server_status",
  "Cek status CPU, RAM, disk, dan semua service yang berjalan",
  {},
  async () => {
    try {
      const { stdout: pm2 } = await execAsync("pm2 jlist");
      const { stdout: disk } = await execAsync("df -h /");
      const { stdout: mem } = await execAsync("free -h");
      const { stdout: cpu } = await execAsync("top -bn1 | head -5");
      const result = `=== PM2 Services ===\n${pm2}\n\n=== Disk ===\n${disk}\n\n=== Memory ===\n${mem}\n\n=== CPU ===\n${cpu}`;
      return { content: [{ type: "text", text: result }] };
    } catch (err) {
      return { content: [{ type: "text", text: `Error: ${err.message}` }], isError: true };
    }
  }
);

const transport = new StdioServerTransport();
await server.connect(transport);
```

Update `package.json` agar support ES modules:

```bash
# Edit package.json, tambahkan "type": "module"
npm pkg set type=module
npm pkg set main=index.js

# Install zod (validation)
npm install zod
```

Jalankan MCP server via HTTP menggunakan wrapper agar bisa diakses via tunnel:

```bash
nano ~/mcp-server/http-bridge.js
```

```javascript
import { spawn } from "child_process";
import express from "express";

const app = express();
app.use(express.json());

// Simple HTTP-to-stdio bridge untuk MCP
app.post("/mcp", (req, res) => {
  const proc = spawn("node", ["/root/mcp-server/index.js"], {
    stdio: ["pipe", "pipe", "pipe"],
  });

  proc.stdin.write(JSON.stringify(req.body) + "\n");
  proc.stdin.end();

  let output = "";
  proc.stdout.on("data", (d) => (output += d.toString()));
  proc.stderr.on("data", (d) => console.error(d.toString()));

  proc.on("close", () => {
    try {
      res.json(JSON.parse(output));
    } catch {
      res.status(500).json({ error: "Invalid MCP response" });
    }
  });
});

app.listen(3001, () => console.log("MCP HTTP bridge running on :3001"));
```

Jalankan dengan pm2:

```bash
pm2 start ~/mcp-server/http-bridge.js --name mcp-server
pm2 save
```

### Tambahkan Route di Nginx

```bash
nano /etc/nginx/sites-available/default
```

Tambahkan di dalam block `server`:

```nginx
# MCP Server untuk AI Agent
location /mcp {
    proxy_pass http://localhost:3001/mcp;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
}
```

Reload Nginx:

```bash
nginx -t && nginx -s reload
```

### Tambahkan ke Cloudflare Tunnel Config

MCP server akan otomatis tersedia di `https://api.domain.com/mcp` karena routing sudah lewat Nginx. Tidak perlu konfigurasi tunnel baru.

Untuk quick tunnel, endpoint MCP ada di URL yang didapat + `/mcp`:
```
https://random-name-abc123.trycloudflare.com/mcp
```

### Hubungkan ke Kiro (AI Agent)

Buat atau edit file `.kiro/settings/mcp.json` di project kamu:

```json
{
  "mcpServers": {
    "android-server": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-fetch"
      ],
      "env": {
        "MCP_SERVER_URL": "https://api.domain.com/mcp"
      }
    }
  }
}
```

> Ganti `https://api.domain.com/mcp` dengan URL tunnel kamu.

Setelah disimpan, Kiro otomatis reconnect dan tools `run_command`, `read_file`, `write_file`, `list_directory`, `server_status` langsung tersedia.

### Verifikasi Koneksi

Test endpoint MCP via curl dari komputer:

```bash
curl -X POST https://api.domain.com/mcp \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}'
```

Jika berhasil, response akan menampilkan daftar tools yang tersedia.

### 🔒 Keamanan MCP Server

MCP server memberi akses **sangat luas** ke server kamu. Wajib tambahkan autentikasi:

```bash
nano ~/mcp-server/http-bridge.js
```

Tambahkan middleware API key sebelum route `/mcp`:

```javascript
// Tambahkan di bagian atas, setelah app.use(express.json())
const API_KEY = process.env.MCP_API_KEY || "ganti-dengan-key-rahasia";

app.use("/mcp", (req, res, next) => {
  const key = req.headers["x-api-key"];
  if (key !== API_KEY) {
    return res.status(401).json({ error: "Unauthorized" });
  }
  next();
});
```

Set API key via environment variable:

```bash
# Simpan ke file .env
echo "MCP_API_KEY=isi-dengan-random-string-panjang" > ~/mcp-server/.env

# Restart dengan env
pm2 delete mcp-server
pm2 start ~/mcp-server/http-bridge.js --name mcp-server \
  --env-from ~/mcp-server/.env
pm2 save
```

Update konfigurasi MCP di Kiro dengan header API key:

```json
{
  "mcpServers": {
    "android-server": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-fetch"],
      "env": {
        "MCP_SERVER_URL": "https://api.domain.com/mcp",
        "MCP_API_KEY": "isi-dengan-key-yang-sama"
      }
    }
  }
}
```

> ⚠️ Jangan commit file `.env` atau `mcp.json` yang berisi API key ke Git publik.

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

[ ] (Opsional) MCP server berjalan: pm2 list menampilkan 'mcp-server' online
[ ] (Opsional) curl ke /mcp mengembalikan daftar tools
[ ] (Opsional) API key sudah di-set dan .env tidak di-commit ke Git
[ ] (Opsional) .kiro/settings/mcp.json sudah dikonfigurasi di project Kiro
```

---

[← Phase 2: Fondasi Server](./fase-2-fondasi-server.md) | [Kembali ke README](../README.md) | [Phase 4: Domain Custom →](./fase-4-domain-custom.md)
