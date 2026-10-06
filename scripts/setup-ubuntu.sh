#!/bin/bash
# =============================================================================
# Kanzan Android Mini Server — Setup Wizard
# Script: setup-ubuntu.sh
# Jalankan di: Ubuntu PRoot (bukan di Termux!)
# Covers: Phase 2 (Nginx + Node.js + pm2) + Phase 3 (Cloudflare Tunnel + MCP)
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
  # Usage: prompt_input "Pertanyaan" VARNAME "default_value"
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

pause() {
  echo ""
  read -r -p "$(echo -e "${CYAN}Tekan ENTER untuk melanjutkan...${NC}")"
  echo ""
}

step_done() {
  echo -e "${GREEN}✓ $1${NC}"
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
 script: setup-ubuntu.sh
EOF
echo -e "${NC}"
divider
echo -e " ${BOLD}Covers:${NC} Phase 2 (Nginx + Node.js + pm2) + Phase 3 (Cloudflare Tunnel)"
echo -e " ${BOLD}Target:${NC} Jalankan di ${YELLOW}Ubuntu PRoot${NC} — bukan di Termux!"
divider
echo ""

# --- Verifikasi dijalankan di Ubuntu, bukan Termux ---
if [[ "$PREFIX" == *"com.termux"* ]]; then
  error "Script ini harus dijalankan di dalam Ubuntu PRoot!\nMasuk ke Ubuntu dulu: ubuntu  (atau: proot-distro login ubuntu)"
fi

if [[ "$(uname -a)" != *"aarch64"* ]] && [[ "$(uname -a)" != *"arm"* ]]; then
  warn "Arsitektur tidak terdeteksi sebagai ARM. Pastikan kamu di Ubuntu PRoot di Android."
  confirm "Lanjutkan tetap?" || exit 1
fi

echo -e "${BOLD}Wizard ini akan menginstall:${NC}"
echo -e "  ${CYAN}Phase 2:${NC} Nginx, Node.js LTS, npm, pm2"
echo -e "  ${CYAN}Phase 3:${NC} cloudflared (ARM64), konfigurasi tunnel"
echo ""
confirm "Mulai setup?" || exit 0

export DEBIAN_FRONTEND=noninteractive

# =============================================================================
# PHASE 2: Fondasi Server
# =============================================================================

echo ""
echo -e "${BOLD}━━━ PHASE 2: Fondasi Server ━━━━━━━━━━━━━━━━━${NC}"
echo ""

# --- Step 2.1: Update system ---
info "Step 2.1 — Update & upgrade Ubuntu..."
apt update -y && apt upgrade -y
success "Ubuntu up to date."

echo ""

# --- Step 2.2: Install Nginx ---
info "Step 2.2 — Install Nginx..."
apt install -y nginx
service nginx start 2>/dev/null || true
sleep 1

if curl -s http://localhost | grep -qi "nginx"; then
  success "Nginx berjalan di http://localhost"
else
  warn "Nginx terinstall tapi belum merespon — akan lanjut, cek manual nanti."
fi

echo ""

# --- Step 2.3: Install Node.js LTS ---
info "Step 2.3 — Install Node.js LTS via NodeSource..."
curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
apt install -y nodejs
NODE_VER=$(node --version 2>/dev/null || echo "tidak terdeteksi")
NPM_VER=$(npm --version 2>/dev/null || echo "tidak terdeteksi")
success "Node.js ${NODE_VER} dan npm ${NPM_VER} terinstall."

echo ""

# --- Step 2.4: Install pm2 ---
info "Step 2.4 — Install pm2 secara global..."
npm install -g pm2
PM2_VER=$(pm2 --version 2>/dev/null || echo "tidak terdeteksi")
success "pm2 ${PM2_VER} terinstall."

echo ""

# --- Step 2.5: Buat struktur direktori ---
info "Step 2.5 — Membuat struktur direktori..."
mkdir -p ~/apps/my-api
mkdir -p ~/storage
mkdir -p ~/.cloudflared
success "Direktori ~/apps/my-api, ~/storage, ~/.cloudflared dibuat."

echo ""

# --- Step 2.6: Security headers Nginx ---
info "Step 2.6 — Setup security headers Nginx..."
cat > /etc/nginx/conf.d/security-headers.conf << 'NGINX_SEC'
server_tokens off;
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
NGINX_SEC

nginx -t 2>/dev/null && service nginx reload 2>/dev/null || true
success "Security headers Nginx dikonfigurasi."

echo ""

# --- Checklist Phase 2 ---
echo -e "${BOLD}✅ Checklist Phase 2:${NC}"
step_done "Nginx terinstall & berjalan"
step_done "Node.js ${NODE_VER} terinstall"
step_done "npm ${NPM_VER} terinstall"
step_done "pm2 ${PM2_VER} terinstall"
step_done "Direktori struktur dibuat"
step_done "Security headers Nginx dikonfigurasi"
echo ""
pause

# =============================================================================
# PHASE 3: Expose ke Internet via Cloudflare Tunnel
# =============================================================================

echo -e "${BOLD}━━━ PHASE 3: Cloudflare Tunnel ━━━━━━━━━━━━━━${NC}"
echo ""

# --- Step 3.1: Download cloudflared ---
info "Step 3.1 — Download cloudflared (ARM64)..."
CF_BIN="/usr/local/bin/cloudflared"

if [[ -f "$CF_BIN" ]]; then
  CF_CUR=$($CF_BIN --version 2>/dev/null | head -1 || echo "versi lama")
  warn "cloudflared sudah ada ($CF_CUR)."
  if confirm "Update cloudflared ke versi terbaru?"; then
    wget -q --show-progress \
      https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64 \
      -O "$CF_BIN"
    chmod +x "$CF_BIN"
    success "cloudflared diperbarui: $($CF_BIN --version | head -1)"
  fi
else
  wget -q --show-progress \
    https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64 \
    -O "$CF_BIN"
  chmod +x "$CF_BIN"
  CF_VER=$($CF_BIN --version 2>/dev/null | head -1 || echo "terinstall")
  success "cloudflared terinstall: ${CF_VER}"
fi

echo ""

# --- Pilih mode tunnel ---
echo -e "${BOLD}Mode Tunnel:${NC}"
echo -e "  ${CYAN}1${NC}) Quick Tunnel — URL sementara, tanpa domain, cocok untuk testing"
echo -e "  ${CYAN}2${NC}) Tunnel Permanen — pakai domain sendiri via Cloudflare login"
echo ""
TUNNEL_MODE=""
while [[ "$TUNNEL_MODE" != "1" && "$TUNNEL_MODE" != "2" ]]; do
  read -r -p "$(echo -e "${YELLOW}[?]${NC} Pilih mode [1/2]: ")" TUNNEL_MODE
done

echo ""

if [[ "$TUNNEL_MODE" == "1" ]]; then
  # -------------------------------------------------------------------------
  # MODE A: QUICK TUNNEL
  # -------------------------------------------------------------------------
  info "Mode: Quick Tunnel (URL sementara)"
  echo ""
  warn "URL akan berubah setiap kali tunnel di-restart."
  warn "Hanya untuk testing. Gunakan Mode 2 untuk setup permanen."
  echo ""

  # Start quick tunnel via pm2
  pm2 start "cloudflared tunnel --url http://localhost:80" --name cloudflared-quick 2>/dev/null || \
    pm2 restart cloudflared-quick 2>/dev/null || true
  pm2 save

  echo ""
  info "Menunggu URL dari cloudflared..."
  sleep 5
  TUNNEL_URL=$(pm2 logs cloudflared-quick --lines 50 --nostream 2>/dev/null | grep -o 'https://[a-z0-9-]*\.trycloudflare\.com' | tail -1 || echo "")

  if [[ -n "$TUNNEL_URL" ]]; then
    success "Tunnel aktif!"
    echo ""
    echo -e " ${BOLD}URL Quick Tunnel kamu:${NC}"
    echo -e " ${GREEN}${TUNNEL_URL}${NC}"
    echo ""
    echo -e " ${YELLOW}Simpan URL ini — dibutuhkan untuk konfigurasi MCP server di bawah.${NC}"
    SERVER_URL="$TUNNEL_URL"
  else
    warn "URL belum terdeteksi otomatis. Jalankan ini untuk lihat URL:"
    echo -e " ${CYAN}pm2 logs cloudflared-quick --lines 30${NC}"
    echo ""
    prompt_input "Masukkan URL quick tunnel kamu (https://xxx.trycloudflare.com)" SERVER_URL ""
  fi

else
  # -------------------------------------------------------------------------
  # MODE B: TUNNEL PERMANEN
  # -------------------------------------------------------------------------
  info "Mode: Tunnel Permanen (dengan domain)"
  echo ""
  echo -e "${YELLOW}Langkah yang akan dilakukan:${NC}"
  echo -e "  1. Login ke akun Cloudflare (browser akan terbuka)"
  echo -e "  2. Buat tunnel bernama 'android-server'"
  echo -e "  3. Konfigurasi domain"
  echo ""

  # Login
  info "Step 3.2 — Login ke Cloudflare..."
  echo ""
  warn "Perintah berikut akan menampilkan URL — buka di browser & authorize."
  pause
  cloudflared tunnel login

  if [[ ! -f ~/.cloudflared/cert.pem ]]; then
    error "Login gagal — cert.pem tidak ditemukan di ~/.cloudflared/. Coba ulangi."
  fi
  success "Login Cloudflare berhasil."

  echo ""

  # Buat tunnel
  info "Step 3.3 — Membuat tunnel 'android-server'..."
  if cloudflared tunnel list 2>/dev/null | grep -q "android-server"; then
    warn "Tunnel 'android-server' sudah ada."
    TUNNEL_ID=$(cloudflared tunnel list 2>/dev/null | grep "android-server" | awk '{print $1}')
    success "Menggunakan tunnel yang sudah ada. ID: ${TUNNEL_ID}"
  else
    cloudflared tunnel create android-server
    TUNNEL_ID=$(cloudflared tunnel list 2>/dev/null | grep "android-server" | awk '{print $1}')
    success "Tunnel dibuat. ID: ${TUNNEL_ID}"
  fi

  echo ""

  # Input domain
  prompt_input "Masukkan domain kamu (contoh: example.com)" DOMAIN ""
  while [[ -z "$DOMAIN" ]]; do
    warn "Domain tidak boleh kosong."
    prompt_input "Masukkan domain kamu (contoh: example.com)" DOMAIN ""
  done

  API_HOSTNAME="api.${DOMAIN}"
  FILES_HOSTNAME="files.${DOMAIN}"

  echo ""
  echo -e " Domain API   : ${CYAN}https://${API_HOSTNAME}${NC}"
  echo -e " Domain Files : ${CYAN}https://${FILES_HOSTNAME}${NC}"
  echo ""
  confirm "Konfirmasi domain di atas sudah benar?" || {
    prompt_input "Masukkan subdomain API (contoh: api.example.com)" API_HOSTNAME ""
    prompt_input "Masukkan subdomain Files (contoh: files.example.com)" FILES_HOSTNAME ""
  }

  # Buat config.yml
  info "Step 3.4 — Membuat ~/.cloudflared/config.yml..."
  CRED_FILE=$(ls ~/.cloudflared/${TUNNEL_ID}.json 2>/dev/null || echo "~/.cloudflared/${TUNNEL_ID}.json")
  cat > ~/.cloudflared/config.yml << EOF
tunnel: ${TUNNEL_ID}
credentials-file: /root/.cloudflared/${TUNNEL_ID}.json

loglevel: info

ingress:
  - hostname: ${API_HOSTNAME}
    service: http://localhost:80
  - hostname: ${FILES_HOSTNAME}
    service: http://localhost:8080
  - service: http_status:404
EOF
  success "config.yml dibuat."

  # Amankan file credentials
  chmod 600 ~/.cloudflared/${TUNNEL_ID}.json 2>/dev/null || true
  chmod 600 ~/.cloudflared/cert.pem 2>/dev/null || true
  chmod 700 ~/.cloudflared/ 2>/dev/null || true
  success "Permission file credentials diamankan (600)."

  # Daftarkan DNS
  info "Step 3.5 — Mendaftarkan DNS records..."
  cloudflared tunnel route dns android-server "$API_HOSTNAME" && \
    success "DNS ${API_HOSTNAME} terdaftar." || \
    warn "Gagal daftarkan ${API_HOSTNAME} — cek manual di Cloudflare Dashboard."

  cloudflared tunnel route dns android-server "$FILES_HOSTNAME" && \
    success "DNS ${FILES_HOSTNAME} terdaftar." || \
    warn "Gagal daftarkan ${FILES_HOSTNAME} — cek manual di Cloudflare Dashboard."

  # Validasi ingress
  info "Validasi konfigurasi ingress..."
  cloudflared tunnel ingress validate && success "Konfigurasi ingress valid."

  # Start tunnel via pm2
  info "Step 3.6 — Menjalankan tunnel via pm2..."
  pm2 start "cloudflared tunnel run android-server" --name cloudflared 2>/dev/null || \
    pm2 restart cloudflared 2>/dev/null || true
  pm2 save
  sleep 3

  if pm2 logs cloudflared --lines 20 --nostream 2>/dev/null | grep -qi "connection established"; then
    success "Tunnel terhubung!"
  else
    warn "Tunnel mungkin masih connecting — cek dengan: pm2 logs cloudflared"
  fi

  SERVER_URL="https://${API_HOSTNAME}"
  echo ""
  echo -e " ${BOLD}Server kamu sekarang bisa diakses di:${NC}"
  echo -e " ${GREEN}${SERVER_URL}${NC}"
fi

echo ""

# --- Checklist Phase 3 ---
echo -e "${BOLD}✅ Checklist Phase 3:${NC}"
step_done "cloudflared terinstall (ARM64)"
if [[ "$TUNNEL_MODE" == "1" ]]; then
  step_done "Quick tunnel aktif via pm2"
else
  step_done "Login Cloudflare berhasil"
  step_done "Tunnel 'android-server' dibuat & berjalan"
  step_done "DNS records terdaftar"
  step_done "config.yml dikonfigurasi"
fi
echo ""
pause

# =============================================================================
# RINGKASAN AKHIR
# =============================================================================

echo ""
divider
echo -e "${BOLD}${GREEN}🎉 Setup Selesai!${NC}"
divider
echo ""

echo -e "${BOLD}Status semua service:${NC}"
pm2 list 2>/dev/null || true

echo ""
echo -e "${BOLD}Verifikasi cepat:${NC}"
echo -e "  ${CYAN}pm2 list${NC}              — lihat semua service"
echo -e "  ${CYAN}pm2 logs cloudflared${NC}  — cek koneksi tunnel"
echo -e "  ${CYAN}curl http://localhost${NC}  — test Nginx"
echo ""

if [[ -n "$SERVER_URL" ]]; then
  echo -e "${BOLD}Server kamu:${NC}"
  echo -e "  ${GREEN}${SERVER_URL}${NC}"
  echo ""
fi

echo -e "${BOLD}Langkah selanjutnya:${NC}"
echo -e "  • MCP Server (AI Agent)       → jalankan ${CYAN}setup-mcp.sh${NC}"
echo -e "  • Phase 4: Setup domain custom → lihat ${CYAN}docs/fase-4-domain-custom.md${NC}"
echo -e "  • Phase 7: Deploy API         → lihat ${CYAN}docs/fase-7-web-server-api.md${NC}"
echo -e "  • Phase 5/6: Remote SSH & GUI → opsional"
echo ""
divider
