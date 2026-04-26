#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════════╗
# ║  ghost.sh  —  Ghost Terminal Entry Point  v4                        ║
# ║                                                                      ║
# ║  Deploy (USB):    source /media/usb/ghost.sh                        ║
# ║  Deploy (remote): source <(curl -sL <GHOST_BASE>/ghost.sh)          ║
# ║                                                                      ║
# ║  Phase 1 (bash):  sets up tmpdir, fetches binaries, copies          ║
# ║                   configs to ZDOTDIR, installs cosmetics             ║
# ║  Phase 2 (zsh):   .zshrc reads from ZDOTDIR, loads modules,         ║
# ║                   shows banner, sets prompt                         ║
# ╚══════════════════════════════════════════════════════════════════════╝

# ════════════════════════════════════════════════════════════════════════
#  GUARD: must be sourced
# ════════════════════════════════════════════════════════════════════════
(return 0 2>/dev/null) || {
  printf '\033[0;31m[GHOST] ERROR:\033[0m Source this script, do not execute it.\n'
  printf '  Correct usage: \033[0;36msource ghost.sh\033[0m\n'
  exit 1
}

# ════════════════════════════════════════════════════════════════════════
#  RECONNECT DETECTION
#  If GHOST_TMPDIR already exists, we are re-sourcing inside an
#  existing ghost session (e.g. opening a new tmux pane).
#  In that case: just reload modules and return — no full bootstrap.
# ════════════════════════════════════════════════════════════════════════
if [[ -n "${GHOST_TMPDIR:-}" && -d "${GHOST_TMPDIR}" ]]; then
  # Re-export PATH in case this pane missed it
  case ":${PATH}:" in
    *":${GHOST_TMPDIR}/bin:"*) ;;
    *) export PATH="${GHOST_TMPDIR}/bin:${PATH}" ;;
  esac
  printf '\033[0;35m[ghost]\033[0m Reconnected to existing session (%s)\n' \
    "$GHOST_TMPDIR"
  return 0
fi

# ════════════════════════════════════════════════════════════════════════
#  PHASE 1 — BASH BOOTSTRAP
# ════════════════════════════════════════════════════════════════════════

# ── Base URL and local dir ────────────────────────────────────────────
GHOST_BASE="${GHOST_BASE:-https://raw.githubusercontent.com/mohammed-thaqee/ghost-terminal/master}"
export GHOST_BASE

# Resolve GHOST_DIR (repo root) for local file resolution
if [[ -z "${GHOST_DIR:-}" ]]; then
  if [[ -n "${BASH_SOURCE[0]:-}" && "${BASH_SOURCE[0]}" != "bash" \
        && "${BASH_SOURCE[0]}" != "zsh" ]]; then
    GHOST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
  else
    GHOST_DIR=""   # sourced via process substitution — no local dir
  fi
fi
export GHOST_DIR

# ── Colour helpers ────────────────────────────────────────────────────
export GH_RED='\033[0;31m'  GH_GRN='\033[0;32m'  GH_YEL='\033[1;33m'
export GH_CYN='\033[0;36m'  GH_MAG='\033[0;35m'  GH_WHT='\033[1;37m'
export GH_DIM='\033[2m'     GH_BLD='\033[1m'      GH_RST='\033[0m'

gh_info() { printf "${GH_CYN}[GHOST]${GH_RST} %s\n" "$*"; }
gh_ok()   { printf "${GH_GRN}[ OK  ]${GH_RST} %s\n" "$*"; }
gh_warn() { printf "${GH_YEL}[WARN ]${GH_RST} %s\n" "$*"; }
gh_err()  { printf "${GH_RED}[ERR  ]${GH_RST} %s\n" "$*" >&2; }
export -f gh_info gh_ok gh_warn gh_err

# ── Session tmpdir ────────────────────────────────────────────────────
export GHOST_TMPDIR
GHOST_TMPDIR="$(mktemp -d /tmp/.ghost_XXXXXX)"
chmod 700 "$GHOST_TMPDIR"

# Exported vars needed by modules and zsh phase
export GHOST_PIDS=()
export GHOST_IDENTITY="${GHOST_IDENTITY:-agent@system}"

# ── Module loader ─────────────────────────────────────────────────────
ghost_load_module() {
  local mod="$1" label="${2:-$1}"

  # Local file first
  if [[ -n "$GHOST_DIR" && -f "${GHOST_DIR}/${mod}.sh" ]]; then
    # shellcheck source=/dev/null
    source "${GHOST_DIR}/${mod}.sh" && return 0
  fi

  # Remote fetch → cache in tmpdir
  local url="${GHOST_BASE}/${mod}.sh"
  local tmp="${GHOST_TMPDIR}/mod_$(printf '%s' "$mod" | tr '/' '_').sh"
  if curl -fsSL "$url" -o "$tmp" 2>/dev/null; then
    chmod 600 "$tmp"
    # shellcheck source=/dev/null
    source "$tmp" && return 0
  fi

  gh_err "Failed to load module: $label"
  return 1
}

# ── Suppress bash history immediately ────────────────────────────────
_ghost_suppress_bash_history() {
  history -c 2>/dev/null || true
  export HISTFILE=/dev/null
  export HISTSIZE=0
  export HISTFILESIZE=0
  unset HISTFILE
  set +o history 2>/dev/null || true
}

# ════════════════════════════════════════════════════════════════════════
#  GHOST MAIN  —  Bash phase sequence
# ════════════════════════════════════════════════════════════════════════
ghost_main() {

  # 0. History off immediately
  _ghost_suppress_bash_history

  # 1. Load boot module (animation, banner, prompt helpers)
  ghost_load_module "core/boot" "boot" || return 1

  # 2. Boot animation
  ghost_boot_sequence

  # 3. Load remaining core modules
  ghost_load_module "core/sudo"      "sudo"      || return 1
  ghost_load_module "core/binaries"  "binaries"  || return 1
  ghost_load_module "core/installer" "installer" || return 1
  ghost_load_module "core/mayday"    "mayday"    || return 1
  ghost_load_module "core/dashboard" "dashboard" || true

  # 4. Acquire sudo (needed for cosmetic apt installs only)
  ghost_acquire_sudo || gh_warn "Continuing without sudo"

  # 5. Resolve portable binaries (lsd bat fzf btop)
  #    Runs before exec zsh so binaries are in PATH from the start
  ghost_setup_binaries

  # 6. Install cosmetic packages in background
  #    (cmatrix figlet lolcat oneko — mayday purges these)
  ghost_install_all &
  local _install_pid=$!

  # 7. Deploy configs to ZDOTDIR (the tmpdir)
  #    This is the key: nothing goes to ~/.  Everything goes to tmpdir.
  _ghost_deploy_configs

  # 8. Wait for cosmetic installs before launching visuals
  wait "$_install_pid" 2>/dev/null

  # 9. Visual fx (cmatrix window, oneko — display required)
  ghost_run_cmatrix
  sleep 0.5

  # 10. Hand off to zsh
  #     export ZDOTDIR so zsh reads configs from tmpdir, not ~/
  #     exec replaces this bash process — nothing after this line runs
  export ZDOTDIR="$GHOST_TMPDIR"

  gh_info "Handing off to zsh (ZDOTDIR=${GHOST_TMPDIR})"
  sleep 0.3

  exec zsh
}

# ── Config deployment ─────────────────────────────────────────────────
_ghost_deploy_configs() {
  gh_info "Deploying configs to session namespace..."

  local cfg_src=""

  # Find config source: local repo → USB → fetch from remote
  if [[ -n "$GHOST_DIR" && -d "${GHOST_DIR}/env" ]]; then
    cfg_src="${GHOST_DIR}/env"
  fi

  # zshrc
  if [[ -n "$cfg_src" && -f "${cfg_src}/zshrc" ]]; then
    cp "${cfg_src}/zshrc"   "${GHOST_TMPDIR}/.zshrc"
  else
    curl -fsSL "${GHOST_BASE}/env/zshrc" \
      -o "${GHOST_TMPDIR}/.zshrc" 2>/dev/null || true
  fi

  # p10k
  if [[ -n "$cfg_src" && -f "${cfg_src}/p10k.zsh" ]]; then
    cp "${cfg_src}/p10k.zsh" "${GHOST_TMPDIR}/.p10k.zsh"
  else
    curl -fsSL "${GHOST_BASE}/env/p10k.zsh" \
      -o "${GHOST_TMPDIR}/.p10k.zsh" 2>/dev/null || true
  fi

  # tmux.conf — copied so dashboard.sh can use: tmux -f $GHOST_TMPDIR/tmux.conf
  if [[ -n "$cfg_src" && -f "${cfg_src}/tmux.conf" ]]; then
    cp "${cfg_src}/tmux.conf" "${GHOST_TMPDIR}/tmux.conf"
  else
    curl -fsSL "${GHOST_BASE}/env/tmux.conf" \
      -o "${GHOST_TMPDIR}/tmux.conf" 2>/dev/null || true
  fi

  # Oh My Zsh: USB carry → clone → system install (handled in .zshrc)
  _ghost_setup_omz

  gh_ok "Configs deployed to ${GHOST_TMPDIR}"
}

# ── Oh My Zsh resolution ──────────────────────────────────────────────
_ghost_setup_omz() {
  # Priority 1: carried on USB
  if [[ -n "$GHOST_DIR" && -d "${GHOST_DIR}/oh-my-zsh" ]]; then
    cp -r "${GHOST_DIR}/oh-my-zsh" "${GHOST_TMPDIR}/oh-my-zsh"
    gh_ok "oh-my-zsh ← USB"
    return 0
  fi

  # Priority 2: clone (requires git + internet)
  if command -v git &>/dev/null; then
    gh_info "Cloning oh-my-zsh..."
    git clone --depth=1 --quiet \
      https://github.com/ohmyzsh/ohmyzsh.git \
      "${GHOST_TMPDIR}/oh-my-zsh" 2>/dev/null && {
        # Clone plugins into custom dir
        local custom="${GHOST_TMPDIR}/oh-my-zsh/custom"
        git clone --depth=1 --quiet \
          https://github.com/romkatv/powerlevel10k.git \
          "${custom}/themes/powerlevel10k" 2>/dev/null &
        git clone --depth=1 --quiet \
          https://github.com/zsh-users/zsh-autosuggestions \
          "${custom}/plugins/zsh-autosuggestions" 2>/dev/null &
        git clone --depth=1 --quiet \
          https://github.com/zsh-users/zsh-syntax-highlighting \
          "${custom}/plugins/zsh-syntax-highlighting" 2>/dev/null &
        wait
        gh_ok "oh-my-zsh cloned to tmpdir"
        return 0
      }
  fi

  # Priority 3: system install (already exists on machine)
  if [[ -d "${HOME}/.oh-my-zsh" ]]; then
    gh_ok "oh-my-zsh ← system install (read-only, no copy)"
    # .zshrc will find it at $HOME/.oh-my-zsh
    return 0
  fi

  gh_warn "oh-my-zsh unavailable — plain zsh prompt will be used"
  return 0
}

# ── Run ───────────────────────────────────────────────────────────────
ghost_main
