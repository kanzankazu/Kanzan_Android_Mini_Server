#!/bin/bash
# =============================================================================
# Kanzan Android Mini Server — Setup Wizard
# Script: setup-mcp.sh
# Jalankan di: Ubuntu PRoot (bukan di Termux!)
# Covers: MCP Server untuk AI Agent (Kiro, Claude, Cursor)
#
# Prasyarat: setup-ubuntu.sh sudah selesai dijalankan
# (Nginx, Node.js, pm2, dan Cloudflare Tunnel harus sudah aktif)
# =============================================================================

set -e

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# --- Helpers ---
info()    { echo -e "${CYAN}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC}   $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
divider() { echo -e "${CYAN}────────────────────────────────────────────${NC}"; }

confirm() {
  local prompt="$1"
  local answer
  read -r -p "$(echo -e "${YELLOW}[?]${NC} ${prompt} [y/N]: ")" answer
  [[ "$answer" =~ ^[Yy]$ ]]
}

prompt_input() {
  local question="$1"
  local varname="$2"
  local default="$3"
  local answer
  if [[ -n "$default" ]]; then
    read -r -p "$(echo -e "${YELLOW}[?]${NC} ${question} [${CYAN}${default}${NC}]: ")" answer
    answer="${answer:-$default}"
  else
    read -r -p "$(echo -e "${YELLOW}[?]${NC} ${question}: ")" answer
  fi
  eval "$varname=\"$answer\""
}

# --- Banner ---
clear
echo -e "${BOLD}${CYAN}"
cat << 'EOF'
  _  __                            
 | |/ /__ _ _ _  ______ _ _ _     
 | ' </ _` | ' \|_ / _` | ' \    
 |_|\_\__,_|_||_/__\__,_|_||_|   
                                   
 Android Mini Server — Setup Wizard
 script: setup-mcp.sh
EOF
echo -e "${NC}"
divider
echo -e " ${BOLD}Covers:${NC} MCP Server — AI Agent Access (Kiro, Claude, Cursor)"
echo -e " ${BOLD}Target:${NC} Jalankan di ${YELLOW}Ubuntu PRoot${NC} — bukan di Termux!"
divider
echo ""

# --- Verifikasi dijalankan di Ubuntu ---
if [[ "$PREFIX" == *"com.termux"* ]]; then
  error "Script ini harus dijalankan di dalam Ubuntu PRoot!\nMasuk ke Ubuntu dulu: ubuntu"
fi

# --- Verifikasi prasyarat ---
info "Memeriksa prasyarat..."

command -v node >/dev/null 2>&1 || error "Node.js tidak ditemukan. Jalankan setup-ubuntu.sh terlebih dahulu."
command -v npm >/dev/null 2>&1  || error "npm tidak ditemukan. Jalankan setup-ubuntu.sh terlebih dahulu."
command -v pm2 >/dev/null 2>&1  || error "pm2 tidak ditemukan. Jalankan setup-ubuntu.sh terlebih dahulu."
command -v nginx >/dev/null 2>&1 || error "Nginx tidak ditemukan. Jalankan setup-ubuntu.sh terlebih dahulu."

success "Semua prasyarat terpenuhi."
echo ""

# --- Cek apakah ada tunnel aktif ---
echo -e "${BOLD}URL Server:${NC}"
echo -e " MCP server membutuhkan URL publik dari Cloudflare Tunnel yang sudah aktif."
echo -e " Jalankan ${CYAN}pm2 logs cloudflared --lines 30${NC} untuk lihat URL kamu."
echo ""

prompt_input "Masukkan URL server kamu (contoh: https://api.domain.com atau https://xxx.trycloudflare.com)" SERVER_URL ""
while [[ -z "$SERVER_URL" ]]; do
  warn "URL tidak boleh kosong."
  prompt_input "Masukkan URL server kamu" SERVER_URL ""
done

echo ""
echo -e " Server URL : ${CYAN}${SERVER_URL}${NC}"
echo ""
confirm "URL sudah benar, lanjutkan?" || exit 0

echo ""

# =============================================================================
# INSTALL MCP SERVER
# =============================================================================

echo -e "${BOLD}━━━ MCP Server untuk AI Agent ━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e " MCP Server memungkinkan AI agent (Kiro, Claude, Cursor) untuk:"
echo -e "  • Menjalankan shell command di server ini"
echo -e "  • Membaca & menulis file"
echo -e "  • Memonitor CPU/RAM/disk/pm2"
echo -e "  • Deploy kode langsung dari chat"
echo ""

# --- Buat direktori MCP ---
info "Membuat direktori ~/mcp-server..."
mkdir -p ~/mcp-server && cd ~/mcp-server

# --- Init npm project ---
info "Inisialisasi project Node.js..."
npm init -y > /dev/null
npm pkg set type=module > /dev/null
npm pkg set main=index.js > /dev/null

# --- Install dependencies ---
info "Install dependencies MCP SDK..."
npm install @modelcontextprotocol/sdk zod express 2>/dev/null || \
  npm install @modelcontextprotocol/sdk zod express --legacy-peer-deps

# --- Generate API key ---
MCP_API_KEY=$(head -c 32 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | head -c 32)
echo "MCP_API_KEY=${MCP_API_KEY}" > ~/mcp-server/.env
chmod 600 ~/mcp-server/.env
success "API key di-generate dan disimpan ke ~/mcp-server/.env"

# --- Buat MCP server (index.js) ---
info "Membuat ~/mcp-server/index.js..."
cat > ~/mcp-server/index.js << 'MCP_SERVER'
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
      const { stdout: pm2 } = await execAsync("pm2 jlist").catch(() => ({ stdout: "[]" }));
      const { stdout: disk } = await execAsync("df -h /");
      const { stdout: mem } = await execAsync("free -h");
      const { stdout: uptime } = await execAsync("uptime");
      const result = `=== PM2 Services ===\n${pm2}\n\n=== Disk ===\n${disk}\n\n=== Memory ===\n${mem}\n\n=== Uptime ===\n${uptime}`;
      return { content: [{ type: "text", text: result }] };
    } catch (err) {
      return { content: [{ type: "text", text: `Error: ${err.message}` }], isError: true };
    }
  }
);

const transport = new StdioServerTransport();
await server.connect(transport);
MCP_SERVER

success "~/mcp-server/index.js dibuat."

# --- Buat HTTP bridge ---
info "Membuat ~/mcp-server/http-bridge.js..."
cat > ~/mcp-server/http-bridge.js << 'HTTP_BRIDGE'
import { spawn } from "child_process";
import express from "express";
import { readFileSync } from "fs";
import { resolve } from "path";

// Load .env
const envPath = new URL(".env", import.meta.url).pathname;
try {
  const envContent = readFileSync(envPath, "utf-8");
  envContent.split("\n").forEach((line) => {
    const [k, v] = line.split("=");
    if (k && v) process.env[k.trim()] = v.trim();
  });
} catch (_) {}

const app = express();
app.use(express.json({ limit: "10mb" }));

const API_KEY = process.env.MCP_API_KEY || "change-me-please";
const PORT = process.env.MCP_PORT || 3001;

// Health check (tanpa auth)
app.get("/health", (_req, res) => {
  res.json({ status: "ok", service: "android-mcp-server", timestamp: new Date().toISOString() });
});

// Middleware API key untuk semua route /mcp
app.use("/mcp", (req, res, next) => {
  const key = req.headers["x-api-key"];
  if (!key || key !== API_KEY) {
    return res.status(401).json({ error: "Unauthorized — provide X-Api-Key header" });
  }
  next();
});

// HTTP-to-stdio MCP bridge
app.post("/mcp", (req, res) => {
  const proc = spawn("node", [resolve("./index.js")], {
    stdio: ["pipe", "pipe", "pipe"],
    cwd: resolve("./"),
  });

  let output = "";
  let errOutput = "";

  proc.stdout.on("data", (d) => (output += d.toString()));
  proc.stderr.on("data", (d) => (errOutput += d.toString()));

  proc.stdin.write(JSON.stringify(req.body) + "\n");
  proc.stdin.end();

  proc.on("close", (code) => {
    if (code !== 0 && !output) {
      console.error("MCP process error:", errOutput);
      return res.status(500).json({ error: "MCP process failed", detail: errOutput });
    }
    try {
      res.json(JSON.parse(output.trim()));
    } catch {
      res.status(500).json({ error: "Invalid MCP response", raw: output });
    }
  });

  // Timeout 35 detik
  setTimeout(() => {
    if (!res.headersSent) {
      proc.kill();
      res.status(504).json({ error: "MCP request timeout" });
    }
  }, 35000);
});

app.listen(PORT, "127.0.0.1", () => {
  console.log(`MCP HTTP bridge running on http://127.0.0.1:${PORT}`);
  console.log(`Health check: http://127.0.0.1:${PORT}/health`);
  console.log(`MCP endpoint: http://127.0.0.1:${PORT}/mcp`);
});
HTTP_BRIDGE

success "~/mcp-server/http-bridge.js dibuat."

# --- Tambahkan route Nginx untuk /mcp ---
info "Menambahkan route /mcp di Nginx..."
cat > /etc/nginx/conf.d/mcp-route.conf << 'NGINX_MCP'
# MCP Server route untuk AI Agent
location /mcp {
    proxy_pass http://127.0.0.1:3001/mcp;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Api-Key $http_x_api_key;
    proxy_read_timeout 40s;
}

location /mcp-health {
    proxy_pass http://127.0.0.1:3001/health;
}
NGINX_MCP

# Tambahkan ke default nginx site jika belum ada
if ! grep -q "include /etc/nginx/conf.d/mcp-route.conf" /etc/nginx/sites-enabled/default 2>/dev/null; then
  sed -i '/server_name _;/a\\n\t# MCP Server routes\n\tinclude /etc/nginx/conf.d/mcp-route.conf;' \
    /etc/nginx/sites-enabled/default 2>/dev/null || true
fi

nginx -t 2>/dev/null && service nginx reload 2>/dev/null || true
success "Nginx dikonfigurasi untuk route /mcp."

# --- Jalankan MCP server via pm2 ---
info "Menjalankan MCP server via pm2..."
cd ~/mcp-server
pm2 start http-bridge.js --name mcp-server 2>/dev/null || \
  pm2 restart mcp-server 2>/dev/null || true
pm2 save
sleep 2

# --- Verifikasi ---
MCP_HEALTH=$(curl -s http://localhost:3001/health 2>/dev/null || echo "")
if echo "$MCP_HEALTH" | grep -q "ok"; then
  success "MCP server berjalan! Health check OK."
else
  warn "MCP server belum merespon — cek dengan: pm2 logs mcp-server"
fi

# =============================================================================
# OUTPUT KONFIGURASI
# =============================================================================

MCP_URL="${SERVER_URL}/mcp"

echo ""
echo -e "${BOLD}━━━ Konfigurasi AI Agent (Kiro) ━━━━━━━━━━━━━${NC}"
echo ""
echo -e " Tambahkan ke ${CYAN}.kiro/settings/mcp.json${NC} di project kamu:"
echo ""
cat << KIRO_CONFIG
{
  "mcpServers": {
    "android-server": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-fetch"],
      "env": {
        "MCP_SERVER_URL": "${MCP_URL}",
        "MCP_API_KEY": "${MCP_API_KEY}"
      }
    }
  }
}
KIRO_CONFIG

echo ""
echo -e " ${YELLOW}Simpan konfigurasi di atas ke file mcp.json kamu.${NC}"
echo ""

# Simpan ringkasan ke file
cat > ~/mcp-server/SETUP_INFO.txt << EOF
=== MCP Server Setup Info ===
Generated: $(date)

Server URL   : ${SERVER_URL}
MCP Endpoint : ${MCP_URL}
API Key      : ${MCP_API_KEY}

Health Check : curl ${SERVER_URL}/mcp-health
Test MCP     : curl -X POST ${MCP_URL} \\
                 -H "Content-Type: application/json" \\
                 -H "X-Api-Key: ${MCP_API_KEY}" \\
                 -d '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}'

Kiro mcp.json config:
{
  "mcpServers": {
    "android-server": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-fetch"],
      "env": {
        "MCP_SERVER_URL": "${MCP_URL}",
        "MCP_API_KEY": "${MCP_API_KEY}"
      }
    }
  }
}
EOF
chmod 600 ~/mcp-server/SETUP_INFO.txt
success "Info setup disimpan ke ~/mcp-server/SETUP_INFO.txt"

# =============================================================================
# RINGKASAN AKHIR
# =============================================================================

echo ""
divider
echo -e "${BOLD}${GREEN}🎉 MCP Server Berhasil Diinstall!${NC}"
divider
echo ""

echo -e "${BOLD}Status service:${NC}"
pm2 list 2>/dev/null || true

echo ""
echo -e "${BOLD}Verifikasi cepat:${NC}"
echo -e "  ${CYAN}pm2 logs mcp-server${NC}           — lihat log MCP server"
echo -e "  ${CYAN}curl ${SERVER_URL}/mcp-health${NC}  — health check dari luar"
echo ""
echo -e "${BOLD}Lihat info lengkap (URL, API key, config):${NC}"
echo -e "  ${CYAN}cat ~/mcp-server/SETUP_INFO.txt${NC}"
echo ""
divider
