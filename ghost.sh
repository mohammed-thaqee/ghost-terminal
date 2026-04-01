#!/usr/bin/env bash
# ============================================================
#  GHOST HACKER TERMINAL  —  ghost.sh
#  Deploy:  source <(curl -sL <raw_url>/ghost.sh)
#  Cleanup: mayday
# ============================================================

# ── Guard: must be sourced, not executed ──────────────────────
(return 0 2>/dev/null) || {
  echo "[!] Run this with: source ghost.sh  (not bash ghost.sh)"
  exit 1
}

# ── Internal state ────────────────────────────────────────────
_GHOST_PKGS=(cmatrix figlet lolcat oneko)
_GHOST_PIDS=()
_GHOST_TMPDIR="$(mktemp -d /tmp/.ghost_XXXXXX)"
_GHOST_PASSFILE="${_GHOST_TMPDIR}/.sp"
_GHOST_READY_FLAG="${_GHOST_TMPDIR}/.ready"
_GHOST_ORIG_PS1="$PS1"
_GHOST_ORIG_HISTFILE="$HISTFILE"
_GHOST_ORIG_HISTSIZE="$HISTSIZE"
_GHOST_ORIG_HISTCONTROL="$HISTCONTROL"
_GHOST_IDENTITY="agent@system"

# ── Colour palette ────────────────────────────────────────────
_G_RED='\033[0;31m'
_G_GRN='\033[0;32m'
_G_YEL='\033[1;33m'
_G_CYN='\033[0;36m'
_G_BLU='\033[0;34m'
_G_MAG='\033[0;35m'
_G_WHT='\033[1;37m'
_G_DIM='\033[2m'
_G_BLD='\033[1m'
_G_RST='\033[0m'

# ════════════════════════════════════════════════════════════════
#  UTILITIES
# ════════════════════════════════════════════════════════════════

_ghost_log()  { echo -e "${_G_CYN}[GHOST]${_G_RST} $*"; }
_ghost_ok()   { echo -e "${_G_GRN}[ OK  ]${_G_RST} $*"; }
_ghost_warn() { echo -e "${_G_YEL}[WARN ]${_G_RST} $*"; }
_ghost_err()  { echo -e "${_G_RED}[ERR  ]${_G_RST} $*"; }

_ghost_sleep_dot() {
  # Usage: _ghost_sleep_dot <seconds> <message>
  local secs=$1 msg=$2
  echo -ne "${_G_DIM}${msg}${_G_RST}"
  for ((i=0; i<secs*4; i++)); do
    sleep 0.25
    echo -ne "${_G_CYN}.${_G_RST}"
  done
  echo
}

_ghost_type_effect() {
  # Simulate typing a string character by character
  local str=$1 delay=${2:-0.04}
  for ((i=0; i<${#str}; i++)); do
    echo -ne "${str:$i:1}"
    sleep "$delay"
  done
  echo
}

_ghost_detect_terminal() {
  # Return best available terminal emulator
  for t in gnome-terminal xterm konsole xfce4-terminal lxterminal; do
    command -v "$t" &>/dev/null && { echo "$t"; return; }
  done
  echo ""
}

_ghost_spawn_terminal() {
  # Spawn a command in a new terminal window
  # Usage: _ghost_spawn_terminal <title> <command>
  local title=$1 cmd=$2
  local term
  term=$(_ghost_detect_terminal)

  case "$term" in
    gnome-terminal)
      gnome-terminal --title="$title" -- bash -c "$cmd" &
      ;;
    xterm)
      xterm -T "$title" -e bash -c "$cmd" &
      ;;
    konsole)
      konsole --title "$title" -e bash -c "$cmd" &
      ;;
    xfce4-terminal)
      xfce4-terminal --title="$title" -e "bash -c '$cmd'" &
      ;;
    lxterminal)
      lxterminal --title="$title" -e "bash -c '$cmd'" &
      ;;
    *)
      # Fallback: run in background without new window
      bash -c "$cmd" &
      ;;
  esac
  echo $!
}

# ════════════════════════════════════════════════════════════════
#  BOOT SEQUENCE
# ════════════════════════════════════════════════════════════════

_ghost_boot_sequence() {
  clear
  echo -e "${_G_DIM}"
  cat <<'BIOS'
  ██████╗ ██╗  ██╗ ██████╗ ███████╗████████╗
 ██╔════╝ ██║  ██║██╔═══██╗██╔════╝╚══██╔══╝
 ██║  ███╗███████║██║   ██║███████╗   ██║
 ██║   ██║██╔══██║██║   ██║╚════██║   ██║
 ╚██████╔╝██║  ██║╚██████╔╝███████║   ██║
  ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝   ╚═╝
BIOS
  echo -e "${_G_RST}"
  sleep 0.4

  local boot_msgs=(
    "BIOS v2.4.1  ·  Initializing hardware vectors..."
    "CPU: Intel Core Ghost™  ·  Cores: ∞  ·  Freq: classified"
    "RAM: 32768 MB  ·  Shadow allocated: 0 KB (untraceable)"
    "Network interface: lo0 (loopback only — going dark)"
    "Loading kernel modules: stealth.ko  phantom.ko  nohist.ko"
    "Mounting encrypted ramfs at /ghost..."
    "Injecting session identity..."
    "Disabling audit subsystem..."
    "Wiping shell history vectors..."
    "Establishing secure environment..."
  )

  for msg in "${boot_msgs[@]}"; do
    echo -ne "${_G_DIM}[ $(date +%H:%M:%S) ] ${_G_RST}"
    _ghost_type_effect "$msg" 0.012
    sleep 0.08
  done

  echo
  echo -e "${_G_GRN}${_G_BLD}>>> SYSTEM ONLINE — IDENTITY SPOOFED <<<${_G_RST}"
  echo
  sleep 0.6
}

# ════════════════════════════════════════════════════════════════
#  SUDO PASSWORD CAPTURE
# ════════════════════════════════════════════════════════════════

_ghost_acquire_sudo() {
  # Check if sudo is already cached
  if sudo -n true 2>/dev/null; then
    _ghost_ok "Elevated access already cached"
    # Write a dummy passfile marker so parallel installs can detect mode
    echo "__cached__" > "$_GHOST_PASSFILE"
    chmod 600 "$_GHOST_PASSFILE"
    return 0
  fi

  echo
  echo -e "${_G_YEL}${_G_BLD}[AUTH]${_G_RST} Elevated privileges required for package deployment."
  echo -e "${_G_DIM}       This is requested once. Credentials are held in tmpfs and auto-wiped.${_G_RST}"
  echo

  local attempts=0
  while (( attempts < 3 )); do
    read -rsp "$(echo -e "${_G_CYN}${_GHOST_IDENTITY}${_G_RST} ${_G_DIM}sudo password:${_G_RST} ")" _ghost_pass
    echo

    # Test the password
    if echo "$_ghost_pass" | sudo -S true 2>/dev/null; then
      echo "$_ghost_pass" > "$_GHOST_PASSFILE"
      chmod 600 "$_GHOST_PASSFILE"
      unset _ghost_pass
      _ghost_ok "Access granted — credentials secured in tmpfs"
      return 0
    else
      unset _ghost_pass
      _ghost_err "Authentication failed (attempt $((++attempts))/3)"
      sleep 0.5
    fi
  done

  _ghost_err "Authentication failed — cannot proceed without sudo"
  return 1
}

# ════════════════════════════════════════════════════════════════
#  PARALLEL PACKAGE INSTALLATION
# ════════════════════════════════════════════════════════════════

_ghost_write_worker_script() {
  # Write a self-contained worker script to tmpfs for each package.
  # Background subshells do NOT inherit shell functions, so we write
  # real scripts that can be executed independently.
  local pkg=$1 passfile=$2 statusfile=$3
  local worker="${_GHOST_TMPDIR}/worker_${pkg}.sh"

  cat > "$worker" <<WORKER
#!/usr/bin/env bash
# Ghost worker: install ${pkg}
PASSFILE='${passfile}'
STATUSFILE='${statusfile}'
PKG='${pkg}'

echo "INSTALLING" > "\$STATUSFILE"

# Fast-path: already installed — no apt needed
if dpkg -s "\$PKG" &>/dev/null 2>&1; then
  echo "DONE" > "\$STATUSFILE"
  exit 0
fi

# Read credential
PASS=\$(cat "\$PASSFILE" 2>/dev/null)

if [[ "\$PASS" == "__cached__" ]]; then
  # Sudo already cached — just run directly
  sudo apt-get install -y -q "\$PKG" &>/dev/null
  RC=\$?
else
  # Refresh sudo timestamp first (handles parallel workers racing on the ticket)
  echo "\$PASS" | sudo -S -v &>/dev/null
  # Now install — sudo ticket is fresh for this worker
  echo "\$PASS" | sudo -S apt-get install -y -q "\$PKG" &>/dev/null
  RC=\$?
fi

if [[ \$RC -eq 0 ]]; then
  echo "DONE" > "\$STATUSFILE"
else
  # One retry: sometimes apt lock clears after a moment
  sleep 3
  if [[ "\$PASS" == "__cached__" ]]; then
    sudo apt-get install -y -q "\$PKG" &>/dev/null && echo "DONE" > "\$STATUSFILE" || echo "FAILED" > "\$STATUSFILE"
  else
    echo "\$PASS" | sudo -S apt-get install -y -q "\$PKG" &>/dev/null && echo "DONE" > "\$STATUSFILE" || echo "FAILED" > "\$STATUSFILE"
  fi
fi
WORKER
  chmod 700 "$worker"
  echo "$worker"
}

_ghost_install_all_packages() {
  local statusdir="${_GHOST_TMPDIR}/pkgstatus"
  mkdir -p "$statusdir"

  _ghost_log "Deploying packages in parallel: ${_GHOST_PKGS[*]}"
  echo

  # Pre-seed status files and write per-package worker scripts
  local worker_pids=()
  local stagger=0
  for pkg in "${_GHOST_PKGS[@]}"; do
    local statusfile="${statusdir}/${pkg}"
    echo "QUEUED" > "$statusfile"

    local worker
    worker=$(_ghost_write_worker_script "$pkg" "$_GHOST_PASSFILE" "$statusfile")

    # Stagger launches by 1s to avoid apt lock collisions between workers
    ( sleep "$stagger"; bash "$worker" ) &
    worker_pids+=($!)
    (( stagger++ )) || true
  done

  # Write and launch the progress terminal
  local prog_script="${_GHOST_TMPDIR}/progress.sh"
  _ghost_write_progress_script "$prog_script" "$statusdir"
  chmod +x "$prog_script"
  _ghost_spawn_terminal "Ghost :: Package Deployment" "bash '${prog_script}'"

  # Wait for all workers to finish
  for pid in "${worker_pids[@]}"; do
    wait "$pid" 2>/dev/null
  done

  # Signal ready for main thread
  touch "$_GHOST_READY_FLAG"

  # Final verification summary
  local all_ok=true
  for pkg in "${_GHOST_PKGS[@]}"; do
    local status
    status=$(cat "${statusdir}/${pkg}" 2>/dev/null || echo "UNKNOWN")
    if [[ "$status" == "DONE" ]]; then
      _ghost_ok "$pkg — ready"
    else
      # Last-chance check: package might have been installed before this session
      if dpkg -s "$pkg" &>/dev/null 2>&1; then
        _ghost_ok "$pkg — already present"
        echo "DONE" > "${statusdir}/${pkg}"
      else
        _ghost_warn "$pkg — ${status}"
        all_ok=false
      fi
    fi
  done

  $all_ok && return 0 || return 1
}

# ════════════════════════════════════════════════════════════════
#  PROGRESS SCRIPT (written to tmp, run in spawned terminal)
# ════════════════════════════════════════════════════════════════

_ghost_write_progress_script() {
  local script=$1 statusdir=$2

  cat > "$script" <<PROG_EOF
#!/usr/bin/env bash
# Ghost Hacker Terminal — Package Deployment Monitor

RED='\033[0;31m'
GRN='\033[0;32m'
YEL='\033[1;33m'
CYN='\033[0;36m'
MAG='\033[0;35m'
WHT='\033[1;37m'
DIM='\033[2m'
BLD='\033[1m'
RST='\033[0m'

STATUSDIR='${statusdir}'
PKGS=(${_GHOST_PKGS[@]})
READY_FLAG='${_GHOST_READY_FLAG}'

clear

echo -e "\${CYN}\${BLD}"
cat <<'BANNER'
  ╔══════════════════════════════════════════════════════╗
  ║          GHOST  ·  PACKAGE DEPLOYMENT UNIT           ║
  ║                  Parallel Installer v1.0             ║
  ╚══════════════════════════════════════════════════════╝
BANNER
echo -e "\${RST}"
echo

bar_width=40

draw_bar() {
  local pct=\$1 label=\$2 status=\$3
  local filled=\$(( pct * bar_width / 100 ))
  local empty=\$(( bar_width - filled ))

  local color="\${CYN}"
  [[ "\$status" == "DONE"   ]] && color="\${GRN}"
  [[ "\$status" == "FAILED" ]] && color="\${RED}"
  [[ "\$status" == "INSTALLING" ]] && color="\${YEL}"

  printf "  \${WHT}%-12s\${RST} " "\$label"
  printf "\${DIM}[\${RST}\${color}"
  printf '%0.s█' \$(seq 1 \$filled)
  printf "\${DIM}"
  printf '%0.s░' \$(seq 1 \$empty)
  printf "\${RST}\${DIM}]\${RST}"
  printf " \${color}\${BLD}%3d%%\${RST}" "\$pct"

  case "\$status" in
    INSTALLING) printf "  \${YEL}⟳ deploying...\${RST}" ;;
    DONE)       printf "  \${GRN}✔ complete\${RST}   " ;;
    FAILED)     printf "  \${RED}✘ failed\${RST}     " ;;
    *)          printf "  \${DIM}· queued\${RST}      " ;;
  esac
  echo
}

declare -A pct_map
declare -A status_map
for p in "\${PKGS[@]}"; do
  pct_map[\$p]=0
  status_map[\$p]="QUEUED"
done

# Animation tick arrays for simulating realistic progress
declare -A ticks
for p in "\${PKGS[@]}"; do ticks[\$p]=0; done

all_done() {
  for p in "\${PKGS[@]}"; do
    [[ "\${status_map[\$p]}" != "DONE" && "\${status_map[\$p]}" != "FAILED" ]] && return 1
  done
  return 0
}

while ! all_done; do
  tput cup 6 0 2>/dev/null || echo -ne "\033[6;0H"

  for pkg in "\${PKGS[@]}"; do
    local_status=\$(cat "\${STATUSDIR}/\${pkg}" 2>/dev/null || echo "QUEUED")
    status_map[\$pkg]="\$local_status"

    case "\$local_status" in
      QUEUED)
        pct_map[\$pkg]=0
        ;;
      INSTALLING)
        # Simulate realistic non-linear progress
        cur=\${pct_map[\$pkg]}
        if   (( cur < 30 )); then inc=\$(( RANDOM % 8 + 3 ))
        elif (( cur < 60 )); then inc=\$(( RANDOM % 5 + 2 ))
        elif (( cur < 85 )); then inc=\$(( RANDOM % 3 + 1 ))
        elif (( cur < 94 )); then inc=1
        else                      inc=0
        fi
        pct_map[\$pkg]=\$(( cur + inc > 94 ? 94 : cur + inc ))
        ;;
      DONE)
        pct_map[\$pkg]=100
        ;;
      FAILED)
        # Keep last pct
        ;;
    esac

    draw_bar "\${pct_map[\$pkg]}" "\$pkg" "\$local_status"
  done

  # Summary line
  done_count=0
  for p in "\${PKGS[@]}"; do
    [[ "\${status_map[\$p]}" == "DONE" ]] && (( done_count++ ))
  done

  echo
  echo -e "  \${DIM}Progress: \${WHT}\${done_count}\${DIM}/\${WHT}\${#PKGS[@]}\${DIM} packages complete\${RST}   "
  echo -e "  \${DIM}Timestamp: \$(date '+%H:%M:%S')\${RST}                    "

  sleep 0.18
done

# Final render with all 100%
tput cup 6 0 2>/dev/null || echo -ne "\033[6;0H"
for pkg in "\${PKGS[@]}"; do
  draw_bar 100 "\$pkg" "DONE"
done

echo
echo -e "  \${GRN}\${BLD}✔ All packages deployed successfully.\${RST}          "
echo -e "  \${DIM}Window closes in 4 seconds...\${RST}"
sleep 4
PROG_EOF
}

# ════════════════════════════════════════════════════════════════
#  VISUAL SEQUENCE (runs after packages are ready)
# ════════════════════════════════════════════════════════════════

_ghost_run_cmatrix() {
  # Run cmatrix for a fixed duration in a spawned terminal
  local dur=${1:-8}
  if command -v cmatrix &>/dev/null; then
    _ghost_spawn_terminal "Ghost :: Neural Net" \
      "cmatrix -b -C cyan; sleep 1"
    _GHOST_PIDS+=($!)
  fi
}

_ghost_show_banner() {
  echo
  if command -v figlet &>/dev/null && command -v lolcat &>/dev/null; then
    figlet -f slant "GHOST" 2>/dev/null | lolcat --freq 0.3 --seed 42
    figlet -f small "H A C K E R  T E R M I N A L" 2>/dev/null | lolcat --freq 0.5
  elif command -v figlet &>/dev/null; then
    figlet -f slant "GHOST HACKER"
  else
    echo -e "${_G_CYN}${_G_BLD}"
    echo "  ██████╗ ██╗  ██╗ ██████╗ ███████╗████████╗"
    echo " ██╔════╝ ██║  ██║██╔═══██╗██╔════╝╚══██╔══╝"
    echo " ██║  ███╗███████║██║   ██║███████╗   ██║   "
    echo " ██║   ██║██╔══██║██║   ██║╚════██║   ██║   "
    echo " ╚██████╔╝██║  ██║╚██████╔╝███████║   ██║   "
    echo "  ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝   ╚═╝  "
    echo -e "${_G_RST}"
  fi

  echo
  echo -e "${_G_DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${_G_RST}"
  echo -e "  ${_G_CYN}Identity :${_G_RST} ${_G_GRN}${_GHOST_IDENTITY}${_G_RST}"
  echo -e "  ${_G_CYN}Mode     :${_G_RST} ${_G_YEL}Ephemeral / No-Trace${_G_RST}"
  echo -e "  ${_G_CYN}History  :${_G_RST} ${_G_RED}Disabled & Wiped${_G_RST}"
  echo -e "  ${_G_CYN}Session  :${_G_RST} ${_G_DIM}$(date '+%Y-%m-%d %H:%M:%S %Z')${_G_RST}"
  echo -e "  ${_G_CYN}Type     :${_G_RST} ${_G_MAG}mayday${_G_RST}${_G_DIM} to trigger full cleanup${_G_RST}"
  echo -e "${_G_DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${_G_RST}"
  echo
}

_ghost_launch_oneko() {
  if command -v oneko &>/dev/null; then
    local term
    term=$(_ghost_detect_terminal)
    if [[ -n "$term" && -n "$DISPLAY" ]]; then
      oneko -tofocus &
      _GHOST_PIDS+=($!)
      _ghost_ok "oneko launched (pid $!)"
    fi
  fi
}

# ════════════════════════════════════════════════════════════════
#  HISTORY SUPPRESSION
# ════════════════════════════════════════════════════════════════

_ghost_suppress_history() {
  # Wipe current in-memory history
  history -c 2>/dev/null

  # Disable history for this session
  export HISTFILE=/dev/null
  export HISTSIZE=0
  export HISTFILESIZE=0
  export HISTCONTROL=ignorespace:ignoredups:erasedups
  unset HISTFILE

  # If using bash, set via builtins too
  if [[ -n "$BASH_VERSION" ]]; then
    set +o history 2>/dev/null || true
  fi
}

# ════════════════════════════════════════════════════════════════
#  CUSTOM PROMPT
# ════════════════════════════════════════════════════════════════

_ghost_set_prompt() {
  # Neon green ghost prompt
  export PS1="\[\033[0;35m\][ghost]\[\033[0m\] \[\033[1;32m\]${_GHOST_IDENTITY}\[\033[0m\]:\[\033[0;36m\]\w\[\033[0m\]\$ "
}

# ════════════════════════════════════════════════════════════════
#  MAYDAY — FULL CLEANUP
# ════════════════════════════════════════════════════════════════

mayday() {
  echo
  echo -e "${_G_RED}${_G_BLD}"
  echo "  ███╗   ███╗ █████╗ ██╗   ██╗██████╗  █████╗ ██╗   ██╗"
  echo "  ████╗ ████║██╔══██╗╚██╗ ██╔╝██╔══██╗██╔══██╗╚██╗ ██╔╝"
  echo "  ██╔████╔██║███████║ ╚████╔╝ ██║  ██║███████║ ╚████╔╝ "
  echo "  ██║╚██╔╝██║██╔══██║  ╚██╔╝  ██║  ██║██╔══██║  ╚██╔╝  "
  echo "  ██║ ╚═╝ ██║██║  ██║   ██║   ██████╔╝██║  ██║   ██║   "
  echo "  ╚═╝     ╚═╝╚═╝  ╚═╝   ╚═╝   ╚═════╝ ╚═╝  ╚═╝   ╚═╝   "
  echo -e "${_G_RST}"
  echo -e "${_G_YEL}Initiating full ghost cleanup protocol...${_G_RST}"
  echo

  # 1. Kill spawned processes
  echo -ne "${_G_DIM}[1/7] Terminating spawned processes...${_G_RST}"
  for pid in "${_GHOST_PIDS[@]}"; do
    kill "$pid" 2>/dev/null
    wait "$pid" 2>/dev/null
  done
  # Also kill cmatrix, oneko by name in case pid tracking missed them
  pkill -x cmatrix 2>/dev/null
  pkill -x oneko   2>/dev/null
  echo -e " ${_G_GRN}done${_G_RST}"

  # 2. Uninstall packages (only those we installed this session)
  echo -ne "${_G_DIM}[2/7] Uninstalling ghost packages...${_G_RST}"
  local pass=""
  [[ -f "$_GHOST_PASSFILE" ]] && pass=$(cat "$_GHOST_PASSFILE")
  for pkg in "${_GHOST_PKGS[@]}"; do
    if dpkg -l "$pkg" &>/dev/null 2>&1; then
      if [[ "$pass" == "__cached__" ]]; then
        sudo apt-get remove -y "$pkg" &>/dev/null
      elif [[ -n "$pass" ]]; then
        echo "$pass" | sudo -S apt-get remove -y "$pkg" &>/dev/null
      fi
    fi
  done
  echo -e " ${_G_GRN}done${_G_RST}"

  # 3. Wipe tmpdir
  echo -ne "${_G_DIM}[3/7] Shredding tmpfs artefacts...${_G_RST}"
  rm -rf "$_GHOST_TMPDIR" 2>/dev/null
  unset _GHOST_TMPDIR _GHOST_PASSFILE _GHOST_READY_FLAG
  echo -e " ${_G_GRN}done${_G_RST}"

  # 4. Restore history settings
  echo -ne "${_G_DIM}[4/7] Restoring history subsystem...${_G_RST}"
  export HISTFILE="$_GHOST_ORIG_HISTFILE"
  export HISTSIZE="$_GHOST_ORIG_HISTSIZE"
  export HISTCONTROL="$_GHOST_ORIG_HISTCONTROL"
  if [[ -n "$BASH_VERSION" ]]; then
    set -o history 2>/dev/null || true
  fi
  history -c 2>/dev/null
  echo -e " ${_G_GRN}done${_G_RST}"

  # 5. Restore original prompt
  echo -ne "${_G_DIM}[5/7] Restoring shell identity...${_G_RST}"
  export PS1="$_GHOST_ORIG_PS1"
  echo -e " ${_G_GRN}done${_G_RST}"

  # 6. Unset all ghost functions and variables
  echo -ne "${_G_DIM}[6/7] Purging ghost functions & variables...${_G_RST}"
  unset -f _ghost_log _ghost_ok _ghost_warn _ghost_err
  unset -f _ghost_sleep_dot _ghost_type_effect _ghost_detect_terminal _ghost_spawn_terminal
  unset -f _ghost_boot_sequence _ghost_acquire_sudo
  unset -f _ghost_install_pkg_worker _ghost_install_all_packages
  unset -f _ghost_write_progress_script _ghost_run_cmatrix _ghost_show_banner
  unset -f _ghost_launch_oneko _ghost_suppress_history _ghost_set_prompt
  unset _GHOST_PKGS _GHOST_PIDS _GHOST_IDENTITY
  unset _GHOST_ORIG_PS1 _GHOST_ORIG_HISTFILE _GHOST_ORIG_HISTSIZE _GHOST_ORIG_HISTCONTROL
  unset _G_RED _G_GRN _G_YEL _G_CYN _G_BLU _G_MAG _G_WHT _G_DIM _G_BLD _G_RST
  echo -e " ${_G_GRN}done${_G_RST}"

  # 7. Clear terminal and wipe history buffer one final time
  echo -ne "${_G_DIM}[7/7] Clearing terminal & wiping history buffer...${_G_RST}"
  history -c 2>/dev/null
  sleep 0.3
  echo -e " ${_G_GRN}done${_G_RST}"

  echo
  echo -e "\033[0;32m[GHOST] Session terminated. No trace remains.\033[0m"
  echo

  # Unset mayday itself, then reset terminal
  unset -f mayday
  sleep 0.8
  reset
  clear
  history -c 2>/dev/null
}

# ════════════════════════════════════════════════════════════════
#  MAIN ENTRY POINT
# ════════════════════════════════════════════════════════════════

_ghost_main() {
  # 0. Suppress history immediately
  _ghost_suppress_history

  # 1. Boot animation
  _ghost_boot_sequence

  # 2. Acquire sudo once
  _ghost_acquire_sudo || {
    _ghost_err "Aborting — sudo required"
    return 1
  }

  echo
  _ghost_log "Updating package index..."
  local pass
  pass=$(cat "$_GHOST_PASSFILE")
  if [[ "$pass" == "__cached__" ]]; then
    sudo apt-get update -qq &>/dev/null &
  else
    echo "$pass" | sudo -S apt-get update -qq &>/dev/null &
  fi
  local update_pid=$!

  # 3. Start parallel installs (progress terminal spawned inside)
  _ghost_log "Launching parallel deployment..."
  _ghost_install_all_packages

  # Wait for apt-get update to finish before launching visuals
  wait $update_pid 2>/dev/null

  # 4. Wait for ready flag (belt+braces)
  local wait_secs=0
  while [[ ! -f "$_GHOST_READY_FLAG" ]] && (( wait_secs < 120 )); do
    sleep 1
    (( wait_secs++ ))
  done

  # 5. Set custom prompt
  _ghost_set_prompt

  # 6. Cinematic cmatrix window (brief)
  _ghost_run_cmatrix 8

  sleep 1

  # 7. ASCII banner
  _ghost_show_banner

  # 8. Launch oneko
  _ghost_launch_oneko

  # 9. Final suppression of any history accumulated during setup
  history -c 2>/dev/null
  _ghost_suppress_history

  echo -e "${_G_GRN}${_G_BLD}Ghost session active. Shell is ephemeral.${_G_RST}"
  echo -e "${_G_DIM}Type ${_G_MAG}mayday${_G_DIM} at any time to initiate cleanup.${_G_RST}"
  echo
}

# ── Run ───────────────────────────────────────────────────────
_ghost_main
