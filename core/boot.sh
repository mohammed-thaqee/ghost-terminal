#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════════╗
# ║  core/boot.sh  —  Boot animation, banner, prompt, history           ║
# ╚══════════════════════════════════════════════════════════════════════╝

# ── Identity ──────────────────────────────────────────────────────────
GHOST_IDENTITY="${GHOST_IDENTITY:-agent@system}"
export GHOST_IDENTITY

# ── Save original shell state (bash phase) ────────────────────────────
# These are captured before anything is changed so mayday can restore them
GHOST_ORIG_PS1="${PS1:-}"
GHOST_ORIG_HISTFILE="${HISTFILE:-${HOME}/.bash_history}"
GHOST_ORIG_HISTSIZE="${HISTSIZE:-1000}"
GHOST_ORIG_HISTCONTROL="${HISTCONTROL:-ignoredups}"
GHOST_ORIG_SHELL="${SHELL:-/bin/bash}"
export GHOST_ORIG_PS1 GHOST_ORIG_HISTFILE GHOST_ORIG_HISTSIZE \
       GHOST_ORIG_HISTCONTROL GHOST_ORIG_SHELL

# ════════════════════════════════════════════════════════════════════════
#  HISTORY SUPPRESSION
# ════════════════════════════════════════════════════════════════════════

ghost_suppress_history() {
  history -c 2>/dev/null || true
  export HISTFILE=/dev/null
  export HISTSIZE=0
  export HISTFILESIZE=0
  export HISTCONTROL="ignorespace:ignoredups:erasedups"
  unset HISTFILE
  # bash
  [[ -n "${BASH_VERSION:-}" ]] && set +o history 2>/dev/null || true
  # zsh
  [[ -n "${ZSH_VERSION:-}" ]] && setopt NO_HIST_SAVE 2>/dev/null || true
}

# ════════════════════════════════════════════════════════════════════════
#  TERMINAL UTILITIES
# ════════════════════════════════════════════════════════════════════════

ghost_type_effect() {
  local str="$1" delay="${2:-0.030}"
  local i
  for (( i=0; i<${#str}; i++ )); do
    printf '%s' "${str:$i:1}"
    sleep "$delay"
  done
  printf '\n'
}

ghost_detect_terminal() {
  # Return first available graphical terminal emulator
  local t
  for t in gnome-terminal xterm xfce4-terminal konsole \
            lxterminal mate-terminal alacritty kitty; do
    command -v "$t" &>/dev/null && { printf '%s' "$t"; return 0; }
  done
  printf ''
}
export -f ghost_detect_terminal

ghost_spawn_terminal() {
  # Usage: ghost_spawn_terminal <title> <command>
  # Returns PID of spawned process
  local title="$1" cmd="$2"
  local term
  term="$(ghost_detect_terminal)"

  # Headless / no display — run in background, no window
  if [[ -z "${DISPLAY:-}${WAYLAND_DISPLAY:-}" || -z "$term" ]]; then
    bash -c "$cmd" &
    printf '%d' $!
    return
  fi

  case "$term" in
    gnome-terminal) gnome-terminal --title="$title" -- bash -c "$cmd" & ;;
    xterm)          xterm -T "$title" -fa 'Monospace' -fs 11 \
                         -bg black -fg green -e bash -c "$cmd" & ;;
    xfce4-terminal) xfce4-terminal --title="$title" \
                         -e "bash -c '$cmd'" & ;;
    konsole)        konsole --title "$title" -e bash -c "$cmd" & ;;
    lxterminal)     lxterminal --title="$title" -e "bash -c '$cmd'" & ;;
    mate-terminal)  mate-terminal --title="$title" \
                         -e "bash -c '$cmd'" & ;;
    alacritty)      alacritty --title "$title" -e bash -c "$cmd" & ;;
    kitty)          kitty --title "$title" bash -c "$cmd" & ;;
    *)              bash -c "$cmd" & ;;
  esac
  printf '%d' $!
}
export -f ghost_spawn_terminal

# ════════════════════════════════════════════════════════════════════════
#  BIOS BOOT SEQUENCE
# ════════════════════════════════════════════════════════════════════════

ghost_boot_sequence() {
  clear
  printf '%b' "${GH_DIM}"
  cat <<'ASCII'

  ██████╗ ██╗  ██╗ ██████╗ ███████╗████████╗
 ██╔════╝ ██║  ██║██╔═══██╗██╔════╝╚══██╔══╝
 ██║  ███╗███████║██║   ██║███████╗   ██║
 ██║   ██║██╔══██║██║   ██║╚════██║   ██║
 ╚██████╔╝██║  ██║╚██████╔╝███████║   ██║
  ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝   ╚═╝

ASCII
  printf '%b\n' "${GH_RST}"

  local msgs=(
    "BIOS v2.4.1  ·  Initialising hardware vectors"
    "CPU: Ghost Core™  ·  Mode: untracked"
    "RAM: detected  ·  Shadow heap: $(df -h /tmp 2>/dev/null | awk 'NR==2{print $4}' || echo '?') available in tmpfs"
    "Mounting session namespace  →  ${GHOST_TMPDIR}"
    "Loading kernel modules: stealth.ko  phantom.ko  nohist.ko"
    "Injecting identity: ${GHOST_IDENTITY}"
    "Disabling audit subsystem"
    "History vectors: WIPED"
    "Portable binary resolution: PENDING"
    "Establishing secure environment"
  )

  local msg
  for msg in "${msgs[@]}"; do
    printf '%b[ %s ] %b' "${GH_DIM}" "$(date +%H:%M:%S)" "${GH_RST}"
    ghost_type_effect "$(eval printf '%s' "\"$msg\"")" 0.011
    sleep 0.05
  done

  printf '\n%b%b>>> SYSTEM ONLINE — IDENTITY SPOOFED <<<%b\n\n' \
    "${GH_GRN}" "${GH_BLD}" "${GH_RST}"
  sleep 0.4
}

# ════════════════════════════════════════════════════════════════════════
#  ASCII BANNER  (shown after zsh starts, from .zshrc)
# ════════════════════════════════════════════════════════════════════════

ghost_show_banner() {
  printf '\n'
  if command -v figlet &>/dev/null && command -v lolcat &>/dev/null; then
    figlet -f slant "GHOST" 2>/dev/null       | lolcat --freq 0.3 --seed 42
    figlet -f small "HACKER  TERMINAL" 2>/dev/null | lolcat --freq 0.5 --seed 7
  elif command -v figlet &>/dev/null; then
    figlet -f slant "GHOST HACKER"
  else
    printf '%b' "${GH_CYN}${GH_BLD}"
    cat <<'FALLBACK'
  ██████╗ ██╗  ██╗ ██████╗ ███████╗████████╗
 ██╔════╝ ██║  ██║██╔═══██╗██╔════╝╚══██╔══╝
 ██║  ███╗███████║██║   ██║███████╗   ██║
 ██║   ██║██╔══██║██║   ██║╚════██║   ██║
 ╚██████╔╝██║  ██║╚██████╔╝███████║   ██║
  ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝   ╚═╝
FALLBACK
    printf '%b' "${GH_RST}"
  fi

  printf '%b\n' \
    "${GH_DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${GH_RST}"
  printf "  ${GH_CYN}%-12s${GH_RST} %s\n" \
    "Identity"  "${GH_GRN}${GHOST_IDENTITY}${GH_RST}"
  printf "  ${GH_CYN}%-12s${GH_RST} %s\n" \
    "Mode"      "${GH_YEL}Ephemeral / No-Trace${GH_RST}"
  printf "  ${GH_CYN}%-12s${GH_RST} %s\n" \
    "History"   "${GH_RED}Disabled & Wiped${GH_RST}"
  printf "  ${GH_CYN}%-12s${GH_RST} %s\n" \
    "Session"   "${GH_DIM}$(date '+%Y-%m-%d %H:%M:%S %Z')${GH_RST}"
  printf "  ${GH_CYN}%-12s${GH_RST} %s\n" \
    "Namespace" "${GH_DIM}${GHOST_TMPDIR}${GH_RST}"
  printf "  ${GH_CYN}%-12s${GH_RST} ${GH_MAG}mayday${GH_RST}%s\n" \
    "Cleanup"   "${GH_DIM}  ← wipes everything${GH_RST}"
  printf '%b\n\n' \
    "${GH_DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${GH_RST}"
}

# ════════════════════════════════════════════════════════════════════════
#  PROMPT  (set from .zshrc in zsh phase)
# ════════════════════════════════════════════════════════════════════════

ghost_set_prompt() {
  if [[ -n "${ZSH_VERSION:-}" ]]; then
    # p10k handles the prompt — this is a fallback if p10k is absent
    if ! command -v p10k &>/dev/null; then
      PROMPT="%F{magenta}[ghost]%f %F{green}%B${GHOST_IDENTITY}%b%f:%F{cyan}%~%f%# "
      export PROMPT
    fi
  else
    # bash fallback
    export PS1="\[\033[0;35m\][ghost]\[\033[0m\] \[\033[1;32m\]${GHOST_IDENTITY}\[\033[0m\]:\[\033[0;36m\]\w\[\033[0m\]\$ "
  fi
}

# ════════════════════════════════════════════════════════════════════════
#  VISUAL FX  (optional, require display)
# ════════════════════════════════════════════════════════════════════════

ghost_run_cmatrix() {
  command -v cmatrix &>/dev/null || return 0
  [[ -z "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]] && return 0
  local pid
  pid=$(ghost_spawn_terminal "Ghost :: Neural Net" \
    "cmatrix -b -C cyan; sleep 1")
  GHOST_PIDS+=("$pid")
}

ghost_launch_oneko() {
  command -v oneko &>/dev/null || return 0
  [[ -z "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]] && return 0
  oneko -tofocus &
  GHOST_PIDS+=($!)
  gh_ok "oneko launched (pid $!)"
}
