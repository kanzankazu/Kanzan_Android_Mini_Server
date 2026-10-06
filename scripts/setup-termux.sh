#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# Kanzan Android Mini Server — Setup Wizard
# Script: setup-termux.sh
# Jalankan di: Termux (bukan di Ubuntu!)
# Covers: Phase 0 (setup Termux) + Phase 1 (install Ubuntu PRoot)
# =============================================================================

set -e

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# --- Helpers ---
info()    { echo -e "${CYAN}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC}   $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
divider() { echo -e "${CYAN}────────────────────────────────────────────${NC}"; }
ask()     { echo -e "${YELLOW}[?]${NC}   $1"; }

confirm() {
  local prompt="$1"
  local answer
  read -r -p "$(echo -e "${YELLOW}[?]${NC} ${prompt} [y/N]: ")" answer
  [[ "$answer" =~ ^[Yy]$ ]]
}

pause() {
  echo ""
  read -r -p "$(echo -e "${CYAN}Tekan ENTER untuk melanjutkan...${NC}")"
  echo ""
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
 script: setup-termux.sh
EOF
echo -e "${NC}"
divider
echo -e " ${BOLD}Covers:${NC} Phase 0 (Termux) + Phase 1 (Ubuntu PRoot)"
echo -e " ${BOLD}Target:${NC} Jalankan di ${YELLOW}Termux${NC} — bukan di Ubuntu!"
divider
echo ""

# --- Verifikasi dijalankan di Termux ---
if [[ "$PREFIX" != *"com.termux"* ]]; then
  error "Script ini harus dijalankan di Termux, bukan di Ubuntu PRoot!\nKeluar dari Ubuntu dulu dengan perintah: exit"
fi

# =============================================================================
# PHASE 0: Persiapan Termux
# =============================================================================

echo -e "${BOLD}━━━ PHASE 0: Persiapan Termux ━━━━━━━━━━━━━━━${NC}"
echo ""

# --- Step 0.1: Update & upgrade ---
info "Step 0.1 — Update & upgrade package Termux..."
echo ""
warn "Proses ini bisa memakan waktu 5–15 menit tergantung koneksi."
warn "Jika muncul pertanyaan 'Keep local version?' → ketik N dan ENTER."
echo ""
if confirm "Lanjutkan update & upgrade Termux?"; then
  pkg update -y && pkg upgrade -y
  success "Termux berhasil di-update."
else
  warn "Skip update — pastikan pkg update sudah dijalankan sebelumnya."
fi

echo ""

# --- Step 0.2: Install paket dasar ---
info "Step 0.2 — Install paket dasar (wget, curl, openssh, nano, git)..."
pkg install wget curl openssh nano git -y
success "Paket dasar terinstall."

echo ""

# --- Step 0.3: Storage permission ---
info "Step 0.3 — Setup izin akses storage Android..."
echo ""
warn "Akan muncul dialog izin storage di HP — pilih ALLOW/IZINKAN."
pause
termux-setup-storage
success "Storage permission di-setup."

echo ""

# --- Step 0.4: SSH key untuk keamanan (opsional) ---
if confirm "Setup SSH key untuk keamanan awal? (Direkomendasikan)"; then
  mkdir -p ~/.ssh
  chmod 700 ~/.ssh
  touch ~/.ssh/authorized_keys
  chmod 600 ~/.ssh/authorized_keys
  success "Direktori SSH disiapkan."
fi

echo ""

# --- Checklist Phase 0 ---
echo -e "${BOLD}✅ Checklist Phase 0:${NC}"
echo -e "  ${GREEN}✓${NC} pkg update & upgrade"
echo -e "  ${GREEN}✓${NC} wget, curl, openssh, nano, git terinstall"
echo -e "  ${GREEN}✓${NC} termux-setup-storage"
echo ""
echo -e "${YELLOW}Manual (tidak bisa diotomasi):${NC}"
echo -e "  ⬜ Aktifkan Wakelock: geser notifikasi Termux → 'Acquire wakelock'"
echo -e "  ⬜ Nonaktifkan battery optimization: Settings → Apps → Termux → Battery → Unrestricted"
echo ""
pause

# =============================================================================
# PHASE 1: Install Ubuntu PRoot
# =============================================================================

echo -e "${BOLD}━━━ PHASE 1: Setup Ubuntu PRoot ━━━━━━━━━━━━━${NC}"
echo ""

# --- Step 1.1: Install proot-distro ---
info "Step 1.1 — Install proot-distro..."
pkg install proot-distro -y
success "proot-distro terinstall."

echo ""

# --- Step 1.2: Install Ubuntu ---
# Cek apakah Ubuntu sudah terinstall
if proot-distro list 2>/dev/null | grep -q "ubuntu.*installed"; then
  warn "Ubuntu sudah terinstall sebelumnya."
  if confirm "Reinstall Ubuntu? (Semua data di dalam Ubuntu akan hilang!)"; then
    proot-distro remove ubuntu
    info "Menginstall Ubuntu (~200–400 MB, tergantung koneksi)..."
    proot-distro install ubuntu
    success "Ubuntu berhasil diinstall."
  else
    success "Menggunakan instalasi Ubuntu yang sudah ada."
  fi
else
  info "Step 1.2 — Menginstall Ubuntu (~200–400 MB)..."
  warn "Proses ini bisa memakan waktu 5–20 menit tergantung koneksi."
  proot-distro install ubuntu
  success "Ubuntu berhasil diinstall."
fi

echo ""

# --- Step 1.3: Buat alias shortcut ---
info "Step 1.3 — Buat alias shortcut 'ubuntu'..."
BASHRC="$HOME/.bashrc"
if ! grep -q "alias ubuntu=" "$BASHRC" 2>/dev/null; then
  echo "alias ubuntu='proot-distro login ubuntu'" >> "$BASHRC"
  success "Alias 'ubuntu' ditambahkan ke ~/.bashrc"
else
  warn "Alias 'ubuntu' sudah ada di ~/.bashrc — skip."
fi

echo ""

# --- Step 1.4: Setup awal Ubuntu via inline script ---
info "Step 1.4 — Setup awal Ubuntu (update + install tools dasar)..."
echo ""
warn "Akan masuk ke Ubuntu dan menjalankan update otomatis."
warn "Jika muncul pertanyaan interaktif → tekan ENTER untuk default."
echo ""
pause

proot-distro login ubuntu -- bash -c "
  set -e
  export DEBIAN_FRONTEND=noninteractive
  apt update && apt upgrade -y
  apt install -y curl wget nano git unzip zip htop
  echo 'Setup awal Ubuntu selesai.'
  uname -a
"

echo ""
success "Ubuntu setup awal berhasil."

echo ""

# --- Checklist Phase 1 ---
echo -e "${BOLD}✅ Checklist Phase 1:${NC}"
echo -e "  ${GREEN}✓${NC} proot-distro terinstall"
echo -e "  ${GREEN}✓${NC} Ubuntu berhasil diinstall"
echo -e "  ${GREEN}✓${NC} apt update & upgrade di Ubuntu"
echo -e "  ${GREEN}✓${NC} curl, wget, nano, git, htop terinstall di Ubuntu"
echo -e "  ${GREEN}✓${NC} Alias 'ubuntu' tersedia di Termux"
echo ""

# =============================================================================
# SELESAI
# =============================================================================

divider
echo -e "${BOLD}${GREEN}🎉 Phase 0 & 1 Selesai!${NC}"
divider
echo ""
echo -e " Langkah selanjutnya:"
echo -e ""
echo -e "  ${CYAN}1.${NC} Aktifkan wakelock ${YELLOW}(manual)${NC}:"
echo -e "     Geser notifikasi Termux → ketuk 'Acquire wakelock'"
echo ""
echo -e "  ${CYAN}2.${NC} Nonaktifkan battery optimization ${YELLOW}(manual)${NC}:"
echo -e "     Settings → Apps → Termux → Battery → Unrestricted"
echo ""
echo -e "  ${CYAN}3.${NC} Masuk ke Ubuntu:"
echo -e "     ${BOLD}source ~/.bashrc && ubuntu${NC}"
echo ""
echo -e "  ${CYAN}4.${NC} Jalankan script Phase 2+3 di dalam Ubuntu:"
echo -e "     ${BOLD}bash <(curl -fsSL https://raw.githubusercontent.com/USERNAME/REPO/main/scripts/setup-ubuntu.sh)${NC}"
echo -e "     ${YELLOW}(atau copy file setup-ubuntu.sh ke HP dan jalankan manual)${NC}"
echo ""
divider
echo ""
echo -e " ${BOLD}Source ~/.bashrc dulu agar alias 'ubuntu' aktif:${NC}"
echo -e " ${CYAN}source ~/.bashrc${NC}"
echo ""
