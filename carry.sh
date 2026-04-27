#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════════╗
# ║  carry.sh  —  USB Population Script                                 ║
# ║                                                                      ║
# ║  Run this ONCE on your own machine to pre-populate your USB         ║
# ║  stick with all binaries including a portable zsh. After this,      ║
# ║  offline from the USB — no network needed at the lab.               ║
# ║                                                                      ║
# ║  Usage:  bash carry.sh /media/your-usb                              ║
# ║          bash carry.sh  (defaults to ./carry-output/)               ║
# ╚══════════════════════════════════════════════════════════════════════╝

set -euo pipefail

RED='\033[0;31m'; GRN='\033[0;32m'; YEL='\033[1;33m'
CYN='\033[0;36m'; DIM='\033[2m';    RST='\033[0m'
BLD='\033[1m'

info()   { printf "${CYN}[carry]${RST} %s\n" "$*"; }
ok()     { printf "${GRN}[ ok  ]${RST} %s\n" "$*"; }
warn()   { printf "${YEL}[warn ]${RST} %s\n" "$*"; }
banner() { printf "\n${DIM}── %s ──${RST}\n" "$*"; }

TARGET="${1:-./carry-output}"
mkdir -p "${TARGET}/bin"

info "Populating: ${TARGET}"
info "This may take a few minutes — downloading latest releases."
printf '\n'

# ── Helper: download latest GitHub release asset ──────────────────────

fetch_latest() {
  local repo="$1" pattern="$2" dest="$3" inner="$4"
  local tmpdir
  tmpdir="$(mktemp -d)"

  local url
  url=$(curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" \
    | grep '"browser_download_url"' \
    | awk -F'"' '{print $4}' \
    | grep -E "$pattern" \
    | head -1)

  if [[ -z "$url" ]]; then
    warn "Could not resolve download URL for ${repo}"
    rm -rf "$tmpdir"
    return 1
  fi

  local archive="${tmpdir}/archive"
  info "Downloading ${repo}..."
  curl -fsSL --progress-bar "$url" -o "$archive"

  tar -xf "$archive" -C "$tmpdir" 2>/dev/null || true

  local binary
  binary=$(find "$tmpdir" -name "$(basename "$inner")" -type f \
           ! -name "*.md" ! -name "*.txt" 2>/dev/null | head -1)

  if [[ -f "$binary" ]]; then
    cp "$binary" "$dest"
    chmod 755 "$dest"
    ok "$(basename "$dest") → $(du -sh "$dest" | cut -f1)"
  else
    warn "Binary not found in archive for ${repo}"
    rm -rf "$tmpdir"
    return 1
  fi

  rm -rf "$tmpdir"
}

# ════════════════════════════════════════════════════════════════════════
banner "Static binaries  (fzf · bat · lsd · btop · zsh)"
# ════════════════════════════════════════════════════════════════════════

fetch_latest \
  "junegunn/fzf" \
  "linux_amd64\.tar\.gz$" \
  "${TARGET}/bin/fzf" \
  "fzf"

fetch_latest \
  "sharkdp/bat" \
  "x86_64-unknown-linux-musl\.tar\.gz$" \
  "${TARGET}/bin/bat" \
  "bat"

fetch_latest \
  "lsd-rs/lsd" \
  "x86_64-unknown-linux-musl\.tar\.gz$" \
  "${TARGET}/bin/lsd" \
  "lsd"

fetch_latest \
  "aristocratsoftech/btop" \
  "x86_64-linux-musl\.tbz$" \
  "${TARGET}/bin/btop" \
  "btop"

# ════════════════════════════════════════════════════════════════════════
banner "Oh My Zsh + plugins"
# ════════════════════════════════════════════════════════════════════════

OMZ_DIR="${TARGET}/oh-my-zsh"
if [[ -d "$OMZ_DIR" ]]; then
  warn "oh-my-zsh already present in target — skipping clone"
else
  info "Cloning oh-my-zsh..."
  git clone --depth=1 --quiet \
    https://github.com/ohmyzsh/ohmyzsh.git "$OMZ_DIR"
  ok "oh-my-zsh cloned"

  info "Cloning powerlevel10k..."
  git clone --depth=1 --quiet \
    https://github.com/romkatv/powerlevel10k.git \
    "${OMZ_DIR}/custom/themes/powerlevel10k"
  ok "powerlevel10k cloned"

  info "Cloning zsh-autosuggestions..."
  git clone --depth=1 --quiet \
    https://github.com/zsh-users/zsh-autosuggestions \
    "${OMZ_DIR}/custom/plugins/zsh-autosuggestions"
  ok "zsh-autosuggestions cloned"

  info "Cloning zsh-syntax-highlighting..."
  git clone --depth=1 --quiet \
    https://github.com/zsh-users/zsh-syntax-highlighting \
    "${OMZ_DIR}/custom/plugins/zsh-syntax-highlighting"
  ok "zsh-syntax-highlighting cloned"
fi

# ════════════════════════════════════════════════════════════════════════
banner "Ghost terminal scripts"
# ════════════════════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Copy all ghost scripts preserving structure
for f in ghost.sh carry.sh; do
  [[ -f "${SCRIPT_DIR}/${f}" ]] && {
    cp "${SCRIPT_DIR}/${f}" "${TARGET}/${f}"
    ok "${f}"
  }
done

for dir in core visuals modules env docs daemon; do
  [[ -d "${SCRIPT_DIR}/${dir}" ]] && {
    cp -r "${SCRIPT_DIR}/${dir}" "${TARGET}/${dir}"
    ok "${dir}/"
  }
done

# ════════════════════════════════════════════════════════════════════════
banner "Summary"
# ════════════════════════════════════════════════════════════════════════

printf '\n%b%bUSB contents:%b\n' "${GRN}" "${BLD}" "${RST}"
ls -lAh "${TARGET}/bin/"
printf '\n'
printf '%bTotal size:%b %s\n' "${CYN}" "${RST}" "$(du -sh "$TARGET" | cut -f1)"
printf '\n'
printf '%b%bDone.%b Plug in your USB and run:\n' "${GRN}" "${BLD}" "${RST}"
printf "  %bsource /media/your-usb/ghost.sh%b\n\n" "${CYN}" "${RST}"
