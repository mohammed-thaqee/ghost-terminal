#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════════╗
# ║  core/mayday.sh  —  Full self-destruct protocol                     ║
# ║                                                                      ║
# ║  Steps:                                                              ║
# ║    1. TTE blackout animation (ANSI fallback if TTE absent)          ║
# ║    2. Send SHUTDOWN to daemon (if running)                          ║
# ║    3. Kill all spawned PIDs                                         ║
# ║    4. apt-get purge cosmetic packages                               ║
# ║    5. Wipe shell history (memory + disk)                            ║
# ║    6. rm -rf $GHOST_TMPDIR                                          ║
# ║    7. Restore original shell state                                  ║
# ║    8. Purge all ghost symbols from shell                            ║
# ║    9. reset + clear                                                 ║
# ╚══════════════════════════════════════════════════════════════════════╝

# ── Animation ─────────────────────────────────────────────────────────

_mayday_animate() {
  if python3 -c "import terminaltexteffects" 2>/dev/null; then
    local msg="MAYDAY PROTOCOL INITIATED — PURGING SESSION"
    printf '%s' "$msg" \
      | python3 -m terminaltexteffects blackout \
          --final-gradient-stops 8A008A 00D1FF FFFFFF \
          --final-gradient-steps 12 2>/dev/null \
      && return 0
    printf '%s' "$msg" \
      | python3 -m terminaltexteffects dissolve 2>/dev/null \
      && return 0
  fi

  # ANSI flicker fallback
  local lines=(
    "▓▓▓  MAYDAY  ▓▓▓  PURGE INITIATED  ▓▓▓  "
    "░░░  ERASING  ░░░  NO TRACE  ░░░  GONE  ░"
    "████████████████████████████████████████  "
    "                                          "
  )
  local cols=('\033[0;31m' '\033[1;31m' '\033[0;33m' '\033[1;33m' '\033[2m')
  local i
  for (( i=0; i<3; i++ )); do
    local line col
    for line in "${lines[@]}"; do
      col="${cols[$((RANDOM % ${#cols[@]}))]}"
      printf "\r%b%s\033[0m" "$col" "$line"
      sleep 0.06
    done
  done
  printf '\n'
}

# ── Step printer ──────────────────────────────────────────────────────

_md_step() {
  printf '%b[%d/%d]%b %s' "${GH_DIM}" "$1" "$2" "${GH_RST}" "$3"
}
_md_done() { printf ' %b✔%b\n' "${GH_GRN}" "${GH_RST}"; }

# ════════════════════════════════════════════════════════════════════════
#  MAYDAY
# ════════════════════════════════════════════════════════════════════════

mayday() {
  local TOTAL=9

  printf '\n%b%b' "${GH_RED}" "${GH_BLD}"
  cat <<'SKULL'
  ███╗   ███╗ █████╗ ██╗   ██╗██████╗  █████╗ ██╗   ██╗
  ████╗ ████║██╔══██╗╚██╗ ██╔╝██╔══██╗██╔══██╗╚██╗ ██╔╝
  ██╔████╔██║███████║ ╚████╔╝ ██║  ██║███████║ ╚████╔╝
  ██║╚██╔╝██║██╔══██║  ╚██╔╝  ██║  ██║██╔══██║  ╚██╔╝
  ██║ ╚═╝ ██║██║  ██║   ██║   ██████╔╝██║  ██║   ██║
  ╚═╝     ╚═╝╚═╝  ╚═╝   ╚═╝   ╚═════╝ ╚═╝  ╚═╝   ╚═╝
SKULL
  printf '%b\n' "${GH_RST}"
  printf '%bInitiating full cleanup protocol...%b\n\n' "${GH_YEL}" "${GH_RST}"
  sleep 0.5

  # ── 1. Animation ─────────────────────────────────────────────────────
  _md_step 1 $TOTAL "Running blackout animation..."; printf '\n'
  _mayday_animate
  _md_done

  # ── 2. Daemon shutdown ────────────────────────────────────────────────
  _md_step 2 $TOTAL "Signalling daemon..."
  local sock="${GHOST_TMPDIR:-/tmp}/.ghost_sock"
  # Try the real socket location
  if [[ -S "${GHOST_TMPDIR:-}/ghost.sock" ]]; then
    sock="${GHOST_TMPDIR}/ghost.sock"
  fi
  if command -v socat &>/dev/null && [[ -S "$sock" ]]; then
    printf 'SHUTDOWN\n' | socat -t2 UNIX-CONNECT:"$sock" - 2>/dev/null || true
    sleep 0.5
  elif command -v nc &>/dev/null && [[ -S "$sock" ]]; then
    printf 'SHUTDOWN\n' | nc -U "$sock" 2>/dev/null || true
    sleep 0.5
  fi
  _md_done

  # ── 3. Kill spawned PIDs ──────────────────────────────────────────────
  _md_step 3 $TOTAL "Terminating spawned processes..."
  local pid
  for pid in "${GHOST_PIDS[@]:-}"; do
    kill "$pid" 2>/dev/null; wait "$pid" 2>/dev/null
  done
  local procs=(cmatrix oneko btop gping cbonsai)
  for p in "${procs[@]}"; do pkill -x "$p" 2>/dev/null || true; done
  tmux kill-session -t ghost 2>/dev/null || true
  _md_done

  # ── 4. Purge cosmetic packages ────────────────────────────────────────
  _md_step 4 $TOTAL "Purging cosmetic packages..."
  local pass=""
  [[ -f "${GHOST_PASSFILE:-}" ]] && pass="$(cat "$GHOST_PASSFILE" 2>/dev/null)"
  local pkg
  for pkg in "${GHOST_PKGS[@]:-cmatrix figlet lolcat oneko}"; do
    if dpkg -s "$pkg" >/dev/null 2>&1; then
      if [[ "$pass" == "__cached__" ]]; then
        sudo apt-get purge -y -q "$pkg" >/dev/null 2>&1 || true
      elif [[ -n "$pass" ]]; then
        printf '%s\n' "$pass" \
          | sudo -S apt-get purge -y -q "$pkg" >/dev/null 2>&1 || true
      fi
    fi
  done
  if [[ "$pass" == "__cached__" ]]; then
    sudo apt-get autoremove -y -q >/dev/null 2>&1 || true
  elif [[ -n "$pass" ]]; then
    printf '%s\n' "$pass" \
      | sudo -S apt-get autoremove -y -q >/dev/null 2>&1 || true
  fi
  _md_done

  # ── 5. Wipe history ───────────────────────────────────────────────────
  _md_step 5 $TOTAL "Wiping shell history..."
  history -c 2>/dev/null || true
  [[ -f "${HOME}/.zsh_history"  ]] && > "${HOME}/.zsh_history"
  [[ -f "${HOME}/.bash_history" ]] && > "${HOME}/.bash_history"
  [[ -n "${HISTFILE:-}" && -f "${HISTFILE}" ]] && > "$HISTFILE"
  _md_done

  # ── 6. Shred tmpdir ───────────────────────────────────────────────────
  _md_step 6 $TOTAL "Shredding session namespace..."
  [[ -d "${GHOST_TMPDIR:-}" ]] && rm -rf "$GHOST_TMPDIR"
  # Belt-and-braces: clean any leftover ghost tmpdirs
  rm -rf /tmp/.ghost_* 2>/dev/null || true
  _md_done

  # ── 7. Restore shell state ────────────────────────────────────────────
  _md_step 7 $TOTAL "Restoring shell identity..."
  export PS1="${GHOST_ORIG_PS1:-\$ }"
  export HISTFILE="${GHOST_ORIG_HISTFILE:-${HOME}/.bash_history}"
  export HISTSIZE="${GHOST_ORIG_HISTSIZE:-1000}"
  export HISTCONTROL="${GHOST_ORIG_HISTCONTROL:-ignoredups}"
  export ZDOTDIR=""
  unset ZDOTDIR
  [[ -n "${BASH_VERSION:-}" ]] && set -o history 2>/dev/null || true
  _md_done

  # ── 8. Purge ghost symbols ────────────────────────────────────────────
  _md_step 8 $TOTAL "Purging ghost functions and variables..."
  # Functions — core/boot
  unset -f ghost_type_effect ghost_detect_terminal ghost_spawn_terminal \
           ghost_boot_sequence ghost_show_banner ghost_set_prompt \
           ghost_suppress_history ghost_run_cmatrix ghost_launch_oneko \
           2>/dev/null
  # Functions — core/sudo
  unset -f ghost_acquire_sudo 2>/dev/null
  # Functions — core/binaries
  unset -f ghost_setup_binaries _bin_install_one _bin_fetch_latest_url \
           2>/dev/null
  # Functions — core/installer
  unset -f ghost_install_all _ghost_write_worker _ghost_get_progress_script \
           2>/dev/null
  # Functions — core/dashboard
  unset -f ghost_launch_dashboard _ghost_build_panes \
           _ghost_build_panes_in_session 2>/dev/null
  # Functions — modules
  unset -f ghost_hacking_menu ghost_coding_menu ghost_recon \
           ghost_portscan ghost_c_run ghost_py_run ghost_java_run \
           ghost_scratch ghost_timer 2>/dev/null
  # Functions — ghost.sh
  unset -f ghost_load_module ghost_main gh_info gh_ok gh_warn gh_err \
           2>/dev/null
  # Functions — mayday internals (last)
  unset -f _mayday_animate _md_step _md_done 2>/dev/null
  # Variables
  unset GHOST_TMPDIR GHOST_PASSFILE GHOST_READY_FLAG GHOST_STATUSDIR \
        GHOST_PKGS GHOST_PIDS GHOST_IDENTITY GHOST_BASE GHOST_DIR \
        GHOST_ORIG_PS1 GHOST_ORIG_HISTFILE GHOST_ORIG_HISTSIZE \
        GHOST_ORIG_HISTCONTROL GHOST_ORIG_SHELL GHOST_ZSHRC_INIT \
        GH_RED GH_GRN GH_YEL GH_CYN GH_MAG GH_WHT GH_DIM GH_BLD GH_RST \
        2>/dev/null
  printf ' %b✔%b\n' "${GH_GRN}" "${GH_RST}" 2>/dev/null || printf ' ✔\n'

  # ── 9. Reset terminal ─────────────────────────────────────────────────
  printf '\033[2m[9/%d] Resetting terminal...\033[0m' "$TOTAL"
  history -c 2>/dev/null || true
  sleep 0.3
  printf ' \033[0;32m✔\033[0m\n\n'
  printf '\033[0;32mMayday complete. No trace remains.\033[0m\n\n'

  unset -f mayday 2>/dev/null
  sleep 0.6
  reset
  clear
  history -c 2>/dev/null || true
}
